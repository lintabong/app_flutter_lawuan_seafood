-- ═══════════════════════════════════════════════════════════════════
-- PRODUCT CONVERSION (A → B) dengan cost absorption + penyusutan
--
-- Alur:
--   1. Default product A berkurang p_qty_from (kg). Buy price A tetap.
--   2. Nilai yang pindah = p_qty_from × buy_price default A (snapshot)
--   3. Default product B bertambah p_qty_to (kg) — boleh beda dari
--      qty_from karena penyusutan (mis. 5 kg ikan → 3 kg fillet).
--      Seluruh nilai tetap dibebankan ke hasil jadi, sehingga cost
--      per kg B otomatis naik. Ini costing yang benar: buangan ikut
--      jadi beban produk jadi.
--   4. Buy price SEMUA variant B di-reprice via weighted average:
--      avg = (Σ stock×buy B + nilai masuk) / (Σ stock×factor B + qty_to)
--      buy_price variant = avg × conversion_factor
--   5. Mirror products (stock & buy_price) ikut disinkronkan.
--   6. Semua tercatat di product_conversion_ledger.
--
-- Jalankan file ini sekali di SQL editor Supabase.
-- ═══════════════════════════════════════════════════════════════════


-- ── 1. Table ledger ────────────────────────────────────────────────
create table public.product_conversion_ledger (
  id bigserial primary key,
  from_product_id bigint not null references public.products(id),
  to_product_id   bigint not null references public.products(id),
  from_variant_id bigint not null references public.product_variants(id),
  to_variant_id   bigint not null references public.product_variants(id),
  qty_from    numeric(10,2) not null check (qty_from > 0),  -- kg keluar dari A
  qty_to      numeric(10,2) not null check (qty_to > 0),    -- kg jadi di B
  unit_cost   numeric(12,2) not null,  -- snapshot buy_price default A saat konversi
  total_value numeric(14,2) not null,  -- qty_from × unit_cost (rupiah yang pindah)
  new_avg_cost numeric(12,2) not null, -- avg cost baru product B per kg
  note text null,
  created_by uuid null references public.users(id),
  created_at timestamptz default now(),
  constraint pcl_different_products check (from_product_id <> to_product_id)
);

create index idx_pcl_from_product on product_conversion_ledger(from_product_id);
create index idx_pcl_to_product   on product_conversion_ledger(to_product_id);
create index idx_pcl_created_at   on product_conversion_ledger(created_at);


-- ── 2. Function ────────────────────────────────────────────────────
create or replace function convert_product(
    p_from_product_id bigint,
    p_to_product_id bigint,
    p_qty_from numeric,          -- kg yang keluar dari default A
    p_qty_to numeric,            -- kg yang jadi di default B (penyusutan boleh)
    p_note text default null,
    p_created_by uuid default null
)
returns table(
    ledger_id bigint,
    from_stock numeric,     -- stock default A setelah konversi
    to_stock numeric,       -- stock default B setelah konversi
    new_avg_cost numeric    -- avg cost baru product B per kg
)
language plpgsql
as $$
declare
    v_from_variant_id bigint;
    v_from_stock numeric;
    v_from_buy numeric;
    v_to_variant_id bigint;
    v_to_stock numeric;

    v_total_value numeric;
    v_asset_value numeric;   -- Σ stock × buy_price semua variant B
    v_base_qty numeric;      -- Σ stock × conversion_factor semua variant B
    v_avg_cost numeric;
    v_ledger_id bigint;
begin

    -- ── Validasi input ──
    if p_qty_from <= 0 then
        raise exception 'Quantity out must be greater than zero';
    end if;

    if p_qty_to <= 0 then
        raise exception 'Quantity in must be greater than zero';
    end if;

    if p_from_product_id = p_to_product_id then
        raise exception 'Source and target product must be different';
    end if;

    -- ── Lock semua variant KEDUA product, urut product_id ──
    -- Urutan lock konsisten mencegah deadlock kalau ada dua konversi
    -- berlawanan arah (A→B dan B→A) berjalan bersamaan.
    perform 1
    from product_variants
    where product_id in (p_from_product_id, p_to_product_id)
    order by product_id, id
    for update;

    -- ── Ambil default A (sumber) ──
    select id, stock, coalesce(buy_price, 0)
    into v_from_variant_id, v_from_stock, v_from_buy
    from product_variants
    where product_id = p_from_product_id
      and name = 'default';

    if v_from_variant_id is null then
        raise exception
            'Source product % does not have a "default" variant',
            p_from_product_id;
    end if;

    if v_from_stock < p_qty_from then
        raise exception
            'Insufficient source stock: need %, available %',
            p_qty_from, v_from_stock;
    end if;

    -- ── Ambil default B (tujuan) ──
    select id
    into v_to_variant_id
    from product_variants
    where product_id = p_to_product_id
      and name = 'default';

    if v_to_variant_id is null then
        raise exception
            'Target product % does not have a "default" variant',
            p_to_product_id;
    end if;

    -- ── Nilai yang pindah (snapshot harga A saat ini) ──
    v_total_value := p_qty_from * v_from_buy;

    -- ── Aset & setara-kg product B SEBELUM barang masuk ──
    select
        coalesce(sum(stock * buy_price), 0),
        coalesce(sum(stock * conversion_factor), 0)
    into v_asset_value, v_base_qty
    from product_variants
    where product_id = p_to_product_id;

    -- ── Weighted average cost baru product B ──
    v_asset_value := v_asset_value + v_total_value;
    v_base_qty    := v_base_qty + p_qty_to;

    if v_base_qty > 0 and v_asset_value >= 0 then
        v_avg_cost := v_asset_value / v_base_qty;
    else
        -- Fallback (stock existing minus dsb.): pakai cost barang
        -- masuk saja — nilai pindah dibagi kg jadi.
        v_avg_cost := v_total_value / p_qty_to;
    end if;

    -- ── Kurangi default A ──
    update product_variants
    set stock = stock - p_qty_from
    where id = v_from_variant_id
    returning stock into v_from_stock;

    -- ── Tambah default B ──
    update product_variants
    set stock = stock + p_qty_to
    where id = v_to_variant_id
    returning stock into v_to_stock;

    -- ── Reprice SEMUA variant B proporsional factor ──
    update product_variants
    set buy_price = round(v_avg_cost * conversion_factor, 2)
    where product_id = p_to_product_id;

    -- ── Sinkronkan mirror products ──
    -- A: hanya stock berubah (buy price A tetap)
    update products
    set stock = v_from_stock
    where id = p_from_product_id;

    -- B: stock + buy price
    update products
    set stock     = v_to_stock,
        buy_price = round(v_avg_cost, 2)
    where id = p_to_product_id;

    -- ── Catat di ledger ──
    insert into product_conversion_ledger(
        from_product_id, to_product_id,
        from_variant_id, to_variant_id,
        qty_from, qty_to,
        unit_cost, total_value, new_avg_cost,
        note, created_by
    )
    values(
        p_from_product_id, p_to_product_id,
        v_from_variant_id, v_to_variant_id,
        p_qty_from, p_qty_to,
        v_from_buy, v_total_value, round(v_avg_cost, 2),
        p_note, p_created_by
    )
    returning id into v_ledger_id;

    return query
    select v_ledger_id, v_from_stock, v_to_stock, round(v_avg_cost, 2);

end;
$$;


-- ── Contoh test ────────────────────────────────────────────────────
-- 5 kg Ikan Patin (id=1) → 3 kg Fillet Patin (id=2), susut 2 kg:
-- select * from convert_product(1, 2, 5, 3, 'fillet batch pagi');