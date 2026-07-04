
create or replace function convert_product_variant(
    p_product_id bigint,
    p_variant_id bigint,          -- variant non-default yang dikonversi
    p_quantity numeric,           -- jumlah unit variant, mis. 4 (cup)
    p_direction varchar default 'pack',  -- 'pack' = default -> variant, 'unpack' = variant -> default
    p_note text default null,
    p_created_by uuid default null
)
returns table(
    ledger_id bigint,
    default_stock numeric,
    variant_stock numeric
)
language plpgsql
as $$
declare
    v_default_id bigint;
    v_default_stock numeric;
    v_variant_stock numeric;
    v_factor numeric;
    v_base_qty numeric;
    v_ledger_id bigint;
begin

    if p_quantity <= 0 then
        raise exception 'Quantity must be greater than zero';
    end if;

    if p_direction not in ('pack', 'unpack') then
        raise exception 'Direction must be pack or unpack';
    end if;

    -- lock variant default (urutan lock konsisten: default dulu, lalu target)
    select id, stock
    into v_default_id, v_default_stock
    from product_variants
    where product_id = p_product_id
      and name = 'default'
    for update;

    if v_default_id is null then
        raise exception 'Product % does not have a "default" variant', p_product_id;
    end if;

    if p_variant_id = v_default_id then
        raise exception 'Cannot convert default variant to itself';
    end if;

    -- lock variant target + validasi kepemilikan
    select stock, conversion_factor
    into v_variant_stock, v_factor
    from product_variants
    where id = p_variant_id
      and product_id = p_product_id
    for update;

    if not found then
        raise exception 'Variant % does not belong to product %',
            p_variant_id, p_product_id;
    end if;

    if v_factor is null or v_factor <= 0 then
        raise exception 'Variant % has invalid conversion_factor', p_variant_id;
    end if;

    v_base_qty := p_quantity * v_factor;

    if p_direction = 'pack' then
        -- default berkurang, variant bertambah
        if v_default_stock < v_base_qty then
            raise exception
                'Insufficient default stock: need %, available %',
                v_base_qty, v_default_stock;
        end if;

        update product_variants
        set stock = stock - v_base_qty
        where id = v_default_id
        returning stock into v_default_stock;

        update product_variants
        set stock = stock + p_quantity
        where id = p_variant_id
        returning stock into v_variant_stock;

        insert into variant_conversion_ledger(
            product_id, from_variant_id, to_variant_id,
            quantity, conversion_factor, base_qty, note, created_by
        )
        values(
            p_product_id, v_default_id, p_variant_id,
            p_quantity, v_factor, v_base_qty, p_note, p_created_by
        )
        returning id into v_ledger_id;

    else
        -- unpack: variant berkurang, default bertambah
        if v_variant_stock < p_quantity then
            raise exception
                'Insufficient variant stock: need %, available %',
                p_quantity, v_variant_stock;
        end if;

        update product_variants
        set stock = stock - p_quantity
        where id = p_variant_id
        returning stock into v_variant_stock;

        update product_variants
        set stock = stock + v_base_qty
        where id = v_default_id
        returning stock into v_default_stock;

        insert into variant_conversion_ledger(
            product_id, from_variant_id, to_variant_id,
            quantity, conversion_factor, base_qty, note, created_by
        )
        values(
            p_product_id, p_variant_id, v_default_id,
            p_quantity, v_factor, v_base_qty, p_note, p_created_by
        )
        returning id into v_ledger_id;

    end if;

    return query
    select v_ledger_id, v_default_stock, v_variant_stock;

end;
$$;