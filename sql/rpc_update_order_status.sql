create or replace function update_order_status(
    p_order_id bigint,
    p_new_status varchar,
    p_cash_id bigint default 1,
    p_user uuid default null
)
returns table(
    order_id bigint,
    transaction_id bigint,
    cash_balance numeric
)
language plpgsql
as $$
declare
    v_old_status varchar;
    v_total numeric;
    v_transaction_id bigint;
    v_cash_balance numeric;
begin

    -- =========================
    -- LOCK ORDER
    -- =========================
    select status, total_amount
    into v_old_status, v_total
    from orders
    where id = p_order_id
    for update;

    if not found then
        raise exception 'Order % not found', p_order_id;
    end if;

    if v_old_status = p_new_status then
        return query select p_order_id, null::bigint, null::numeric;
        return;
    end if;

    -- =========================
    -- PREVENT INVALID REVERT
    -- =========================
    if v_old_status in ('paid','picked up','delivered')
    and p_new_status in ('pending','prepared') then
        raise exception 'Cannot revert paid order to non financial state';
    end if;

    ------------------------------------------------
    -- PAYMENT EVENT
    ------------------------------------------------
    if v_old_status in ('pending','prepared')
    and p_new_status in ('paid','picked up','delivered') then

        -- Prevent duplicate financial entry
        if exists(
            select 1
            from transactions
            where reference_type = 'order'
            and reference_id = p_order_id
            and status != 'voided'
        ) then
            raise exception 'Transaction already exists for order %', p_order_id;
        end if;

        -- reduce stock (set based)
        update product_variants pv
        set stock = pv.stock - oi.quantity
        from order_items oi
        where oi.order_id = p_order_id
        and pv.id = oi.product_variant_id;

        -- create transaction
        insert into transactions(
            type,
            category_id,
            reference_type,
            reference_id,
            amount,
            created_by
        )
        values(
            'sale',
            1,
            'order',
            p_order_id,
            v_total,
            p_user
        )
        returning id into v_transaction_id;

        -- apply cash ledger
        select new_balance
        into v_cash_balance
        from apply_cash_ledger(
            p_cash_id,
            v_transaction_id,
            'in',
            v_total
        );

    end if;

    ------------------------------------------------
    -- CANCEL PAID ORDER
    ------------------------------------------------
    if v_old_status in ('paid','picked up','delivered')
    and p_new_status = 'cancelled' then

        select id
        into v_transaction_id
        from transactions
        where reference_type = 'order'
        and reference_id = p_order_id
        and status != 'voided'
        limit 1;

        if v_transaction_id is null then
            raise exception 'No financial transaction found for order %', p_order_id;
        end if;

        -- restore stock
        update product_variants pv
        set stock = pv.stock + oi.quantity
        from order_items oi
        where oi.order_id = p_order_id
        and pv.id = oi.product_variant_id;

        -- reverse cash
        select new_balance
        into v_cash_balance
        from apply_cash_ledger(
            p_cash_id,
            v_transaction_id,
            'out',
            v_total
        );

        -- void transaction
        update transactions
        set status = 'voided'
        where id = v_transaction_id;

    end if;

    ------------------------------------------------
    -- UPDATE STATUS
    ------------------------------------------------
    update orders
    set status = p_new_status
    where id = p_order_id;

    return query
    select p_order_id, v_transaction_id, v_cash_balance;

end;
$$;
