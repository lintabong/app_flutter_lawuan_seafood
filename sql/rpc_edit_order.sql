
-- ═══════════════════════════════════════════════════════════════════════════
-- edit_order
-- ───────────────────────────────────────────────────────────────────────────
-- Mengedit order yang MASIH berstatus 'pending' saja.
--
-- Kenapa aman tanpa reversal:
--   Order 'pending' belum pernah menyentuh stok, transaksi, maupun cash ledger
--   (lihat apply_order: efek finansial hanya jalan saat status paid/picked up/
--   delivered). Jadi mengedit item/harga/delivery/tanggal cukup:
--     1. validasi ulang item
--     2. recompute total_amount
--     3. update kolom orders
--     4. hapus order_items lama -> insert ulang
--   Tidak ada stok yang perlu dikembalikan, tidak ada kas yang perlu dibalik.
--
-- Guard:
--   Jika status order != 'pending' -> raise exception. Ini pengaman ke depan
--   supaya order yang sudah finansial tidak pernah bisa diedit lewat jalur ini.
--
-- Catatan: status, customer, cash, dan created_by TIDAK diubah di sini —
-- sesuai scope edit page (customer & status/cash dikunci).
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function edit_order(
    p_order_id       bigint,
    p_items          jsonb,
    p_delivery_price numeric     default 0,
    p_delivery_type  varchar     default 'pickup',
    p_order_date     timestamptz default now()
)
returns table(
    out_order_id     bigint,
    out_total_amount numeric
)
language plpgsql
as $$
declare
    v_status varchar;
    v_total  numeric := 0;
    v_item   record;
begin
    -- Validate empty order
    if jsonb_array_length(p_items) = 0 then
        raise exception 'Order must contain at least one item';
    end if;

    -- Lock the order row & fetch current status
    select status
    into v_status
    from orders
    where id = p_order_id
    for update;

    if not found then
        raise exception 'Order % not found', p_order_id;
    end if;

    -- GUARD: only pending orders may be edited
    if v_status <> 'pending' then
        raise exception
            'Only pending orders can be edited (current status: %)',
            v_status;
    end if;

    -- Calculate total + validate variants (mirror of apply_order)
    for v_item in
        select *
        from jsonb_to_recordset(p_items) as x(
            product_id bigint,
            variant_id bigint,
            qty        numeric,
            buy_price  numeric,
            sell_price numeric
        )
    loop
        if v_item.qty <= 0 then
            raise exception 'Quantity must be greater than zero';
        end if;

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

    -- Update order header
    update orders
    set total_amount   = v_total,
        delivery_price = p_delivery_price,
        delivery_type  = p_delivery_type,
        order_date     = p_order_date
    where id = p_order_id;

    -- Replace items: delete old, insert new
    -- Safe for pending orders (no is_prepared state that matters yet).
    delete from order_items where order_id = p_order_id;

    insert into order_items(
        order_id,
        product_id,
        product_variant_id,
        quantity,
        buy_price,
        sell_price
    )
    select
        p_order_id,
        product_id,
        variant_id,
        qty,
        buy_price,
        sell_price
    from jsonb_to_recordset(p_items) as x(
        product_id bigint,
        variant_id bigint,
        qty        numeric,
        buy_price  numeric,
        sell_price numeric
    );

    return query
    select p_order_id, v_total;
end;
$$;