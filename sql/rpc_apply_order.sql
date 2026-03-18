create or replace function apply_order(
    p_customer_id bigint,
    p_items jsonb,
    p_created_by uuid default null,
    p_order_date timestamptz default now(),
    p_status varchar default 'pending',
    p_cash_id bigint default 1,
    p_delivery_price numeric default 0,
    p_delivery_type varchar default 'pickup'
)
returns table(
    order_id bigint,
    transaction_id bigint,
    cash_balance numeric
)
language plpgsql
as $$
declare
    v_order_id bigint;
    v_transaction_id bigint;
    v_total numeric := 0;
    v_cash_balance numeric := null;

    v_item record;
begin
    -- Validate empty order
    if jsonb_array_length(p_items) = 0 then
        raise exception 'Order must contain at least one item';
    end if;

    -- Calculate total + validate variants
    for v_item in
        select *
        from jsonb_to_recordset(p_items) as x(
            product_id bigint,
            variant_id bigint,
            qty numeric,
            buy_price numeric,
            sell_price numeric
        )
    loop

        if v_item.qty <= 0 then
            raise exception 'Quantity must be greater than zero';
        end if;

        -- validate variant belongs to product
        if not exists (
            select 1
            from product_variants
            where id = v_item.variant_id
            and product_id = v_item.product_id
        ) then
            raise exception
            'Variant % does not belong to product %',
            v_item.variant_id,
            v_item.product_id;
        end if;

        v_total := v_total + (coalesce(v_item.sell_price, 0) * v_item.qty);

    end loop;

    v_total := v_total + coalesce(p_delivery_price, 0);

    insert into orders(
        customer_id,
        created_by,
        status,
        total_amount,
        delivery_price,
        delivery_type,
        order_date
    )
    values(
        p_customer_id,
        p_created_by,
        p_status,
        v_total,
        p_delivery_price,
        p_delivery_type,
        p_order_date
    )
    returning id into v_order_id;

    -- =========================
    -- INSERT ORDER ITEMS
    -- =========================
    insert into order_items(
        order_id,
        product_id,
        product_variant_id,
        quantity,
        buy_price,
        sell_price
    )
    select
        v_order_id,
        product_id,
        variant_id,
        qty,
        buy_price,
        sell_price
    from jsonb_to_recordset(p_items) as x(
        product_id bigint,
        variant_id bigint,
        qty numeric,
        buy_price numeric,
        sell_price numeric
    );

    -- =========================
    -- IF PAID
    -- =========================
    if p_status in ('paid','picked up','delivered') then

        -- reduce stock
        update product_variants pv
        set stock = pv.stock - x.qty
        from jsonb_to_recordset(p_items) as x(
            product_id bigint,
            variant_id bigint,
            qty numeric,
            buy_price numeric,
            sell_price numeric
        )
        where pv.id = x.variant_id;

        -- create transaction
        insert into transactions(
            type,
            category_id,
            reference_type,
            reference_id,
            amount,
            created_by,
            transaction_date
        )
        values(
            'sale',
            1,
            'order',
            v_order_id,
            v_total,
            p_created_by,
            p_order_date
        )
        returning id into v_transaction_id;

        -- update cash ledger
        select new_balance
        into v_cash_balance
        from apply_cash_ledger(
            p_cash_id,
            v_transaction_id,
            'in',
            v_total
        );

    end if;

    return query
    select v_order_id, v_transaction_id, v_cash_balance;

end;
$$;