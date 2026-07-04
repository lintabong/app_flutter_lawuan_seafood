
-- ═══════════════════════════════════════════════════════════════════
-- product_purchase_transaction — v3 (Weighted Average Cost)
--
-- Input TIDAK berubah. Perubahan logic di loop kedua saja:
--   1. Lock SEMUA variant product (bukan cuma default) — karena
--      buy_price semuanya akan berubah
--   2. Hitung total aset & total setara-kg dari semua variant
--   3. Tambahkan barang masuk → harga rata-rata baru per kg (WAC)
--   4. Stock masuk ke variant default (seperti sebelumnya)
--   5. buy_price SEMUA variant di-set = avg × conversion_factor
--   6. products.buy_price & products.stock ikut disinkronkan
--      (mirror dari default, konsisten dengan RPC edit sinkron)
--
-- Contoh: default 2kg @21.000 + cup500gr 4pcs @11.000 (factor 0.5)
--   aset = 86.000, setara kg = 4 → avg lama 21.500/kg
--   kulakan 6kg @20.000 → aset 206.000, 10 kg → avg baru 20.600/kg
--   default → 20.600 | cup 500gr → 10.300 | cup 250gr → 5.150
-- ═══════════════════════════════════════════════════════════════════

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
    v_variant_id bigint;
    v_default_stock numeric;

    -- WAC
    v_asset_value numeric;   -- Σ stock × buy_price (rupiah)
    v_base_qty numeric;      -- Σ stock × conversion_factor (kg)
    v_avg_cost numeric;      -- harga rata-rata baru per kg
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
        type, category_id, reference_type, supplier_id,
        amount, description, status, created_by, transaction_date
    )
    values(
        'purchase', v_category_id, 'transaction_items', p_supplier_id,
        v_total, p_description, p_status, p_created_by,
        coalesce(p_transaction_date, now())
    )
    returning id into v_transaction_id;

    -- 3. Second loop: insert items + stock ke default + WAC repricing
    for v_item in select * from jsonb_array_elements(p_items)
    loop
        v_product_id := (v_item->>'product_id')::bigint;
        v_qty := (v_item->>'quantity')::numeric;
        v_price := (v_item->>'price')::numeric;
        v_subtotal := v_qty * v_price;

        insert into transaction_items(
            transaction_id, item_type, product_id,
            quantity, price, subtotal
        )
        values(
            v_transaction_id, 'product', v_product_id,
            v_qty, v_price, v_subtotal
        );

        -- 3a. Lock SEMUA variant product ini sekaligus.
        --     Wajib sebelum baca aset, karena buy_price semua
        --     variant akan diubah — mencegah race dengan konversi
        --     atau purchase lain yang berjalan bersamaan.
        perform 1
        from product_variants
        where product_id = v_product_id
        for update;

        -- 3b. Ambil id variant default (sudah ter-lock di atas)
        select id into v_variant_id
        from product_variants
        where product_id = v_product_id
          and name = 'default';

        if v_variant_id is null then
            raise exception
                'Product % does not have a "default" variant', v_product_id;
        end if;

        -- 3c. Hitung aset & setara-kg SEBELUM barang masuk.
        --     Semua variant dihitung (termasuk inactive) karena
        --     stock-nya tetap aset. Stock negatif ikut terhitung
        --     apa adanya — kalau hasilnya aneh, itu sinyal ada
        --     stock minus yang perlu dibereskan dulu.
        select
            coalesce(sum(stock * buy_price), 0),
            coalesce(sum(stock * conversion_factor), 0)
        into v_asset_value, v_base_qty
        from product_variants
        where product_id = v_product_id;

        -- 3d. Tambahkan barang masuk → harga rata-rata baru
        v_asset_value := v_asset_value + v_subtotal;
        v_base_qty    := v_base_qty + v_qty;

        if v_base_qty > 0 and v_asset_value >= 0 then
            v_avg_cost := v_asset_value / v_base_qty;
        else
            -- Fallback: total kg <= 0 (stock existing minus lebih
            -- besar dari barang masuk) atau aset negatif — rata-rata
            -- tidak bermakna, pakai harga beli hari ini saja.
            v_avg_cost := v_price;
        end if;

        -- 3e. Stock masuk ke variant default
        update product_variants
        set stock = stock + v_qty
        where id = v_variant_id
        returning stock into v_default_stock;

        -- 3f. Reprice SEMUA variant proporsional factor
        update product_variants
        set buy_price = round(v_avg_cost * conversion_factor, 2)
        where product_id = v_product_id;

        -- 3g. Sinkronkan mirror di table products
        --     (konsisten dengan update_product_with_default_variant)
        update products
        set buy_price = round(v_avg_cost, 2),
            stock     = v_default_stock
        where id = v_product_id;

    end loop;

    -- 4. Apply cash ledger if posted
    if p_status = 'posted' then
        select new_balance
        into v_new_balance
        from apply_cash_ledger(p_cash_id, v_transaction_id, 'out', v_total);
    end if;

    -- 5. Return result
    return query
    select v_transaction_id, v_total, v_new_balance;

end;
$$;