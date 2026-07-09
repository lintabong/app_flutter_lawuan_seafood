create table public.users (
  id uuid not null,
  name character varying(100) not null,
  email character varying(100) not null,
  role character varying(20) null default 'staff'::character varying,
  is_active boolean not null default true,
  created_at timestamp with time zone null default now(),
  constraint users_pkey primary key (id),
  constraint users_email_key unique (email),
  constraint users_role_check check (
    (
      (role)::text = any (
        (
          array[
            'admin'::character varying,
            'staff'::character varying,
            'driver'::character varying,
            'customer'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create table public.customers (
  id bigserial not null,
  name character varying(100) not null,
  phone character varying(30) null,
  address text null,
  latitude numeric(10, 6) null,
  longitude numeric(10, 6) null,
  created_at timestamp with time zone null default now(),
  constraint customers_pkey primary key (id)
) TABLESPACE pg_default;

create table public.cash (
  id bigserial not null,
  name character varying(50) not null,
  balance numeric(14, 2) not null default 0.00,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint cash_pkey primary key (id)
) TABLESPACE pg_default;

create table public.customers (
  id bigserial not null,
  name character varying(100) not null,
  phone character varying(30) null,
  address text null,
  latitude numeric(10, 6) null,
  longitude numeric(10, 6) null,
  created_at timestamp with time zone null default now(),
  constraint customers_pkey primary key (id)
) TABLESPACE pg_default;

create table public.suppliers (
  id bigserial not null,
  name character varying(150) not null,
  phone character varying(30) null,
  address text null,
  notes text null,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  constraint suppliers_pkey primary key (id)
) TABLESPACE pg_default;

create table public.products (
  id bigserial not null,
  name character varying(100) not null,
  category_id bigint null,
  unit character varying(20) null default 'kg'::character varying,
  buy_price numeric(10, 2) not null,
  sell_price numeric(10, 2) not null,
  stock numeric(10, 2) null default 0.00,
  is_active boolean not null default true,
  created_at timestamp with time zone null default now(),
  notify_stock boolean not null default false,
  constraint products_pkey primary key (id)
) TABLESPACE pg_default;

create table public.product_variants (
  id bigserial not null,
  product_id bigint not null,
  name character varying(100) not null,
  description text null,
  sku character varying(50) null,
  unit character varying(20) null,
  buy_price numeric(10, 2) null,
  sell_price numeric(10, 2) null,
  stock numeric(10, 2) null default 0,
  is_active boolean null default true,
  created_at timestamp with time zone null default now(),
  conversion_factor numeric(10, 4) not null default 1,
  constraint product_variants_pkey primary key (id),
  constraint fk_product foreign KEY (product_id) references products (id)
) TABLESPACE pg_default;

create table public.transaction_categories (
  id bigserial not null,
  name character varying(50) not null,
  type character varying(20) not null,
  created_at timestamp with time zone null default now(),
  constraint transaction_categories_pkey primary key (id),
  constraint transaction_categories_type_check check (
    (
      (type)::text = any (
        (
          array[
            'income'::character varying,
            'expense'::character varying,
            'sale'::character varying,
            'purchase'::character varying,
            'transfer'::character varying,
            'adjustment'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create table public.transactions (
  id bigserial not null,
  type character varying(20) not null,
  category_id bigint null,
  reference_type character varying(50) null,
  reference_id bigint null,
  amount numeric(12, 2) not null,
  description text null,
  created_by uuid null,
  created_at timestamp with time zone null default now(),
  transaction_date timestamp with time zone null default now(),
  updated_at timestamp with time zone null,
  status character varying(20) not null default 'posted'::character varying,
  supplier_id bigint null,
  constraint transactions_pkey primary key (id),
  constraint transactions_category_fkey foreign KEY (category_id) references transaction_categories (id),
  constraint transactions_created_by_fkey foreign KEY (created_by) references users (id),
  constraint transactions_supplier_id_fkey foreign KEY (supplier_id) references suppliers (id),
  constraint transactions_status_check check (
    (
      (status)::text = any (
        (
          array[
            'draft'::character varying,
            'posted'::character varying,
            'partial'::character varying,
            'settled'::character varying,
            'voided'::character varying,
            'reversed'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint transactions_type_check check (
    (
      (type)::text = any (
        (
          array[
            'sale'::character varying,
            'purchase'::character varying,
            'expense'::character varying,
            'income'::character varying,
            'transfer'::character varying,
            'adjustment'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create table public.transaction_items (
  id bigserial not null,
  transaction_id bigint not null,
  item_type character varying(20) null default 'product'::character varying,
  product_id bigint null,
  description text null,
  quantity numeric(10, 2) null default 1,
  price numeric(12, 2) null,
  subtotal numeric(12, 2) null,
  created_at timestamp with time zone null default now(),
  constraint transaction_items_pkey primary key (id),
  constraint transaction_items_product_fkey foreign KEY (product_id) references products (id),
  constraint transaction_items_transaction_fkey foreign KEY (transaction_id) references transactions (id) on delete CASCADE,
  constraint transaction_items_type_check check (
    (
      (item_type)::text = any (
        (
          array[
            'product'::character varying,
            'service'::character varying,
            'expense'::character varying,
            'custom'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create table public.product_conversion_ledger (
  id bigserial not null,
  from_product_id bigint not null,
  to_product_id bigint not null,
  from_variant_id bigint not null,
  to_variant_id bigint not null,
  qty_from numeric(10, 2) not null,
  qty_to numeric(10, 2) not null,
  unit_cost numeric(12, 2) not null,
  total_value numeric(14, 2) not null,
  new_avg_cost numeric(12, 2) not null,
  note text null,
  created_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint product_conversion_ledger_pkey primary key (id),
  constraint product_conversion_ledger_created_by_fkey foreign KEY (created_by) references users (id),
  constraint product_conversion_ledger_from_product_id_fkey foreign KEY (from_product_id) references products (id),
  constraint product_conversion_ledger_from_variant_id_fkey foreign KEY (from_variant_id) references product_variants (id),
  constraint product_conversion_ledger_to_variant_id_fkey foreign KEY (to_variant_id) references product_variants (id),
  constraint product_conversion_ledger_to_product_id_fkey foreign KEY (to_product_id) references products (id),
  constraint product_conversion_ledger_qty_to_check check ((qty_to > (0)::numeric)),
  constraint pcl_different_products check ((from_product_id <> to_product_id)),
  constraint product_conversion_ledger_qty_from_check check ((qty_from > (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_pcl_from_product on public.product_conversion_ledger using btree (from_product_id) TABLESPACE pg_default;

create index IF not exists idx_pcl_to_product on public.product_conversion_ledger using btree (to_product_id) TABLESPACE pg_default;

create index IF not exists idx_pcl_created_at on public.product_conversion_ledger using btree (created_at) TABLESPACE pg_default;

create table public.variant_conversion_ledger (
  id bigserial not null,
  product_id bigint not null,
  from_variant_id bigint not null,
  to_variant_id bigint not null,
  quantity numeric(10, 2) not null,
  conversion_factor numeric(10, 4) not null,
  base_qty numeric(10, 2) not null,
  note text null,
  created_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint variant_conversion_ledger_pkey primary key (id),
  constraint variant_conversion_ledger_from_variant_id_fkey foreign KEY (from_variant_id) references product_variants (id),
  constraint variant_conversion_ledger_created_by_fkey foreign KEY (created_by) references users (id),
  constraint variant_conversion_ledger_product_id_fkey foreign KEY (product_id) references products (id),
  constraint variant_conversion_ledger_to_variant_id_fkey foreign KEY (to_variant_id) references product_variants (id),
  constraint vcl_different_variants check ((from_variant_id <> to_variant_id)),
  constraint variant_conversion_ledger_quantity_check check ((quantity > (0)::numeric))
) TABLESPACE pg_default;

create index IF not exists idx_vcl_product on public.variant_conversion_ledger using btree (product_id) TABLESPACE pg_default;

create index IF not exists idx_vcl_created_at on public.variant_conversion_ledger using btree (created_at) TABLESPACE pg_default;

create table public.orders (
  id bigserial not null,
  customer_id bigint not null,
  order_date timestamp with time zone null default now(),
  status character varying(20) null default 'pending'::character varying,
  created_by uuid null,
  total_amount numeric(12, 2) null,
  delivery_price numeric(10, 2) null default 0.00,
  delivery_type character varying(20) null default 'pickup'::character varying,
  constraint orders_pkey primary key (id),
  constraint orders_created_by_fkey foreign KEY (created_by) references users (id),
  constraint orders_customer_id_fkey foreign KEY (customer_id) references customers (id),
  constraint orders_delivery_type_check check (
    (
      (delivery_type)::text = any (
        (
          array[
            'pickup'::character varying,
            'delivery'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint orders_status_check check (
    (
      (status)::text = any (
        array[
          'pending'::text,
          'paid'::text,
          'prepared'::text,
          'picked up'::text,
          'delivered'::text,
          'cancelled'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create table public.order_items (
  id bigserial not null,
  order_id bigint not null,
  product_id bigint not null,
  quantity numeric(10, 2) not null,
  buy_price numeric(10, 2) not null,
  sell_price numeric(10, 2) not null,
  is_prepared boolean null default false,
  product_variant_id bigint null,
  constraint order_items_pkey primary key (id),
  constraint order_items_order_id_fkey foreign KEY (order_id) references orders (id) on delete CASCADE,
  constraint order_items_product_id_fkey foreign KEY (product_id) references products (id),
  constraint order_items_variant_fkey foreign KEY (product_variant_id) references product_variants (id)
) TABLESPACE pg_default;

create table public.app_settings (
  key text not null,
  value text not null,
  updated_at timestamp with time zone not null default now(),
  constraint app_settings_pkey primary key (key)
) TABLESPACE pg_default;

create table public.shipments (
  id bigserial not null,
  order_id bigint not null,
  driver_id uuid not null,
  assigned_by uuid null,
  status character varying(20) not null default 'assigned'::character varying,
  recipient_name character varying(100) null,
  note text null,
  failure_reason text null,
  proof_photo_url text null,
  assigned_at timestamp with time zone null default now(),
  started_at timestamp with time zone null,
  arrived_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint shipments_pkey primary key (id),
  constraint shipments_order_id_key unique (order_id),
  constraint shipments_assigned_by_fkey foreign KEY (assigned_by) references users (id),
  constraint shipments_driver_id_fkey foreign KEY (driver_id) references users (id),
  constraint shipments_order_id_fkey foreign KEY (order_id) references orders (id) on delete CASCADE,
  constraint shipments_status_check check (
    (
      (status)::text = any (
        (
          array[
            'assigned'::character varying,
            'en_route'::character varying,
            'arrived'::character varying,
            'completed'::character varying,
            'failed'::character varying,
            'cancelled'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_shipments_driver on public.shipments using btree (driver_id) TABLESPACE pg_default;

create index IF not exists idx_shipments_status on public.shipments using btree (status) TABLESPACE pg_default;

create table public.driver_locations (
  driver_id uuid not null,
  latitude numeric(10, 6) not null,
  longitude numeric(10, 6) not null,
  accuracy numeric(10, 2) null,
  heading numeric(10, 2) null,
  speed numeric(10, 2) null,
  is_sending boolean not null default false,
  updated_at timestamp with time zone not null default now(),
  constraint driver_locations_pkey primary key (driver_id),
  constraint driver_locations_driver_id_fkey foreign KEY (driver_id) references users (id) on delete CASCADE
) TABLESPACE pg_default;

create table public.driver_location_history (
  id bigserial not null,
  driver_id uuid not null,
  latitude numeric(10, 6) not null,
  longitude numeric(10, 6) not null,
  accuracy numeric(10, 2) null,
  heading numeric(10, 2) null,
  speed numeric(10, 2) null,
  recorded_at timestamp with time zone not null default now(),
  constraint driver_location_history_pkey primary key (id),
  constraint driver_location_history_driver_id_fkey foreign KEY (driver_id) references users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_dlh_driver_time on public.driver_location_history using btree (driver_id, recorded_at) TABLESPACE pg_default;