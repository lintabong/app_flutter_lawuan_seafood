
-- ═══════════════════════════════════════════════════════════════════
-- RPC BARU: update_product_with_default_variant
-- Dipanggil saat user edit product ATAU edit variant bernama
-- 'default' — keduanya harus selalu sinkron.
-- Jalankan sekali di SQL editor Supabase.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.update_product_with_default_variant(
  p_product_id bigint,
  p_stock numeric,
  p_sell_price numeric,
  p_buy_price numeric
)
returns void
language plpgsql
as $$
begin

  -- 1. Update product (products.stock tetap di-maintain hanya sebagai
  --    cermin dari variant default, sumber kebenaran tetap variant)
  update public.products
  set stock      = p_stock,
      sell_price = p_sell_price,
      buy_price  = p_buy_price
  where id = p_product_id;

  if not found then
    raise exception 'Product % not found', p_product_id;
  end if;

  -- 2. Update variant default
  update public.product_variants
  set stock      = p_stock,
      sell_price = p_sell_price,
      buy_price  = p_buy_price
  where product_id = p_product_id
    and name = 'default';

  if not found then
    raise exception 'Product % does not have a "default" variant',
      p_product_id;
  end if;

end;
$$;