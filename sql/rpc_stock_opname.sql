
-- ═══════════════════════════════════════════════════════════════════
-- STOCK OPNAME (penyesuaian stok fisik) + ledger per item
--
-- Alur:
--   1. User hitung fisik barang, input stok aktual per variant
--   2. RPC menerima array item, membandingkan dengan stok sistem
--   3. Stok variant di-set ke angka fisik
--   4. Selisihnya (susut/lebih) tercatat per item di
--      stock_opname_ledger, lengkap dengan nilai rupiahnya
--      (selisih × buy_price saat itu, di-snapshot)
--   5. Item yang selisihnya 0 TIDAK dicatat (biar ledger bersih)
--   6. Satu kali submit = satu session_id, jadi opname yang
--      mencakup banyak item bisa dikelompokkan
--
-- Jalankan file ini sekali di SQL editor Supabase.
-- ═══════════════════════════════════════════════════════════════════


-- ── 1. Table ledger ────────────────────────────────────────────────
create table public.stock_opname_ledger (
  id bigserial primary key,
  session_id uuid not null,                 -- pengelompokan per submit
  product_id bigint not null references public.products(id),
  variant_id bigint not null references public.product_variants(id),
  stock_before numeric(10,2) not null,      -- stok sistem sebelum
  stock_after  numeric(10,2) not null,      -- stok fisik hasil hitung
  difference   numeric(10,2) not null,      -- after - before (negatif = susut)
  unit_cost    numeric(12,2) not null,      -- snapshot buy_price variant
  value_diff   numeric(14,2) not null,      -- difference × unit_cost (rupiah)
  note text null,
  created_by uuid null references public.users(id),
  created_at timestamptz default now()
);

create index idx_sol_session    on stock_opname_ledger(session_id);
create index idx_sol_product    on stock_opname_ledger(product_id);
create index idx_sol_variant    on stock_opname_ledger(variant_id);
create index idx_sol_created_at on stock_opname_ledger(created_at);


-- ── 2. Function ────────────────────────────────────────────────────
-- p_items: [{"variant_id": 12, "physical_stock": 3.5}, ...]
create or replace function stock_opname(
    p_items jsonb,
    p_note text default null,
    p_created_by uuid default null
)
returns table(
    session_id uuid,
    items_adjusted int,        -- berapa item yang selisihnya != 0
    total_value_diff numeric   -- total rupiah selisih (negatif = rugi susut)
)
language plpgsql
as $$
declare
    v_session uuid := gen_random_uuid();
    v_item jsonb;
    v_variant_id bigint;
    v_physical numeric;
    v_stock numeric;
    v_buy numeric;
    v_product_id bigint;
    v_name varchar;
    v_diff numeric;
    v_count int := 0;
    v_total_value numeric := 0;
begin

    if p_items is null or jsonb_array_length(p_items) = 0 then
        raise exception 'Opname must contain at least one item';
    end if;

    for v_item in select * from jsonb_array_elements(p_items)
    loop
        v_variant_id := (v_item->>'variant_id')::bigint;
        v_physical   := (v_item->>'physical_stock')::numeric;

        if v_variant_id is null then
            raise exception 'variant_id is required for every item';
        end if;

        if v_physical is null or v_physical < 0 then
            raise exception
                'Physical stock for variant % must be >= 0', v_variant_id;
        end if;

        -- Lock variant + baca kondisi sekarang
        select stock, coalesce(buy_price, 0), product_id, name
        into v_stock, v_buy, v_product_id, v_name
        from product_variants
        where id = v_variant_id
        for update;

        if not found then
            raise exception 'Variant % not found', v_variant_id;
        end if;

        v_diff := v_physical - v_stock;

        -- Tidak ada selisih → tidak perlu dicatat maupun diupdate
        if v_diff = 0 then
            continue;
        end if;

        -- Set stok sistem = stok fisik
        update product_variants
        set stock = v_physical
        where id = v_variant_id;

        -- Kalau yang di-opname variant default, sinkronkan mirror
        -- products.stock (konsisten dengan RPC lain)
        if v_name = 'default' then
            update products
            set stock = v_physical
            where id = v_product_id;
        end if;

        -- Catat per item
        insert into stock_opname_ledger(
            session_id, product_id, variant_id,
            stock_before, stock_after, difference,
            unit_cost, value_diff,
            note, created_by
        )
        values(
            v_session, v_product_id, v_variant_id,
            v_stock, v_physical, v_diff,
            v_buy, round(v_diff * v_buy, 2),
            p_note, p_created_by
        );

        v_count := v_count + 1;
        v_total_value := v_total_value + round(v_diff * v_buy, 2);

    end loop;

    return query
    select v_session, v_count, v_total_value;

end;
$$;


-- ── Contoh test ────────────────────────────────────────────────────
-- Hitung fisik: variant 3 (default patin) ternyata 3.5 kg,
-- variant 12 (cup 500gr) ternyata 6 pcs:
--
-- select * from stock_opname(
--   '[{"variant_id": 3, "physical_stock": 3.5},
--     {"variant_id": 12, "physical_stock": 6}]'::jsonb,
--   'opname mingguan'
-- );
--
-- Laporan susut per bulan:
-- select sum(value_diff) from stock_opname_ledger
-- where created_at >= '2026-07-01' and created_at < '2026-08-01'
--   and difference < 0;