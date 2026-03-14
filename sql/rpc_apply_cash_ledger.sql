create or replace function apply_cash_ledger(
    p_cash_id bigint,
    p_transaction_id bigint,
    p_direction varchar,
    p_amount numeric
)
returns table(
    ledger_id bigint,
    new_balance numeric
)
language plpgsql
as $$
declare
    v_balance numeric;
    v_new_balance numeric;
    v_ledger_id bigint;
begin

    -- lock cash row
    select balance
    into v_balance
    from cash
    where id = p_cash_id
    for update;

    if not found then
        raise exception 'Cash account not found';
    end if;

    if p_direction = 'in' then
        v_new_balance := v_balance + p_amount;
    else
        v_new_balance := v_balance - p_amount;
    end if;

    update cash
    set balance = v_new_balance
    where id = p_cash_id;

    insert into cash_ledgers(
        cash_id,
        transaction_id,
        direction,
        amount,
        balance_after
    )
    values(
        p_cash_id,
        p_transaction_id,
        p_direction,
        p_amount,
        v_new_balance
    )
    returning id into v_ledger_id;

    return query
    select v_ledger_id, v_new_balance;

end;
$$;