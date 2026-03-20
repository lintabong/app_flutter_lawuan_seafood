create or replace function expense_transaction(
    p_category_name text, -- Salaries, Utilities, etc
    p_amount numeric,
    p_cash_id bigint default 1,
    p_description text default '',
    p_status text default 'draft',
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
    v_category_id bigint;
    v_new_balance numeric := 0;
begin

    -- 1. Validate amount
    if p_amount <= 0 then
        raise exception 'Amount must be greater than zero';
    end if;

    -- 2. Get category
    select id into v_category_id
    from transaction_categories
    where name = p_category_name;

    if v_category_id is null then
        raise exception 'Transaction category "%" not found', p_category_name;
    end if;

    -- 3. Create transaction
    insert into transactions(
        type,
        category_id,
        reference_type,
        amount,
        description,
        status,
        created_by,
        transaction_date
    )
    values(
        'expense',
        v_category_id,
        'manual', -- no items
        p_amount,
        p_description,
        p_status,
        p_created_by,
        coalesce(p_transaction_date, now())
    )
    returning id into v_transaction_id;

    -- 4. Apply cash ledger if posted
    if p_status = 'posted' then
        select new_balance
        into v_new_balance
        from apply_cash_ledger(
            p_cash_id,
            v_transaction_id,
            'out',
            p_amount
        );
    end if;

    -- 5. Return result
    return query
    select
        v_transaction_id,
        p_amount,
        v_new_balance;

end;
$$;