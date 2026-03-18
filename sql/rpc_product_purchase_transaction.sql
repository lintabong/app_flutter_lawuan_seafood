create or replace function product_purchase_transaction(
    p_cash_id bigint,
    p_supplier_id bigint,
    p_items jsonb,
    p_category_name text default 'Product Purchases',
    p_status text default 'draft',
    p_description text default '',
    p_created_by uuid default null,
    p_transaction_date timestamptz default null
)
returns table(
    transaction_id bigint,
    total_amount numeric,
    new_cash_balance numeric
)
language plpgsql
as $$
declare
    v_transaction_id bigint;
    v_total numeric := 0;
    v_category_id bigint;
    v_item jsonb;
    v_product_id bigint;
    v_qty numeric;
    v_price numeric;
    v_subtotal numeric;
    v_new_balance numeric := 0;
begin

    -- Get category
    select id into v_category_id
    from transaction_categories
    where name = p_category_name;

    if v_category_id is null then
        raise exception 'Transaction category "%" not found', p_category_name;
    end if;

    -- 1. First loop: calculate total
    for v_item in select * from jsonb_array_elements(p_items)
    loop

        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'price')::numeric;

        if v_qty <= 0 then
            raise exception 'Quantity must be greater than zero';
        end if;

        if v_price < 0 then
            raise exception 'Price cannot be negative';
        end if;

        v_total := v_total + (v_qty * v_price);

    end loop;

    -- 2. Create transaction
    insert into transactions(
        type,
        category_id,
        reference_type,
        supplier_id,
        amount,
        description,
        status,
        created_by,
        transaction_date
    )
    values(
        'purchase',
        v_category_id,
        'transaction_items',
        p_supplier_id,
        v_total,
        p_description,
        p_status,
        p_created_by,
        coalesce(p_transaction_date, now())
    )
    returning id into v_transaction_id;

    -- 3. Second loop: insert items
    for v_item in select * from jsonb_array_elements(p_items)
    loop

        v_product_id := (v_item->>'product_id')::bigint;
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'price')::numeric;
        v_subtotal := v_qty * v_price;

        insert into transaction_items(
            transaction_id,
            item_type,
            product_id,
            quantity,
            price,
            subtotal
        )
        values(
            v_transaction_id,
            'product',
            v_product_id,
            v_qty,
            v_price,
            v_subtotal
        );

        -- Update stock
        update products
        set stock = stock + v_qty
        where id = v_product_id;

    end loop;

    -- 4. Apply cash ledger if posted
    if p_status = 'posted' then
        select new_balance
        into v_new_balance
        from apply_cash_ledger(
            p_cash_id,
            v_transaction_id,
            'out',
            v_total
        );
    end if;

    -- 5. Return result
    return query
    select
        v_transaction_id,
        v_total,
        v_new_balance;

end;
$$;