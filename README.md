# 🐟 Fish Inventory & POS

Aplikasi manajemen inventory + point-of-sale untuk bisnis ikan segar,
dibangun dengan **Flutter** dan **Supabase (PostgreSQL)**. Mendukung
penjualan per-variant (curah kg & kemasan cup), repack, konversi antar
product dengan penyusutan, costing otomatis (Weighted Average Cost),
stock opname, dan laporan penjualan.

> Dibuat untuk kebutuhan bisnis sendiri, production-grade, single-tenant.
> Ganti nama project ini sesuai nama usahamu.

---

## ✨ Fitur

| Fitur | Deskripsi |
|---|---|
| 📊 **Dashboard** | Saldo kas & total stok (setara kg) real-time, auto-refresh 8 detik |
| 🧾 **Orders** | Buat & kelola order (pending → paid/picked up/delivered), pickup atau delivery + ongkir |
| 🚚 **Delivery Orders** | Daftar order antar, data lokasi customer (lat/long) |
| 📦 **Products & Variants** | Product dengan variant `default` (curah) + variant kemasan, harga & stok per variant |
| 🔄 **Variant Converter** | Repack curah → cup (dan sebaliknya) berdasarkan *conversion factor* |
| 🐠 **Product Converter** | Konversi antar product (ikan utuh → fillet) dengan penyusutan; biaya ikut mengalir |
| 🛒 **Product Purchase** | Kulakan per kg, stok masuk ke variant default, harga modal semua variant dihitung ulang otomatis (WAC) |
| 💸 **Transactions & Cash** | Pencatatan sale/purchase/expense, cash ledger dengan saldo berjalan |
| ✅ **Stock Opname** | Sesuaikan stok sistem dengan hitungan fisik, susut tercatat per item dalam kg **dan rupiah** |
| 📈 **Report** | Penjualan per product (qty kg, revenue, cost, profit) & ringkasan periode (COGS, gross profit, expense) |
| 👥 **Customers & Suppliers** | Master data pelanggan (dengan koordinat) dan supplier |

---

## 🧠 Konsep Inti

### Variant `default`
Setiap product wajib punya satu variant bernama `default` — representasi
barang curah product itu (satuan kg). Kulakan masuk ke sini, konversi
lewat sini. Kolom stok/harga di table `products` hanyalah *mirror* dari
variant default, disinkronkan otomatis oleh RPC.

### Conversion Factor
`product_variants.conversion_factor` = berapa kg per 1 unit variant
(cup 500 gr = `0.5`). Dipakai untuk repack, agregasi total kg, dan
distribusi harga modal.

### Weighted Average Cost (WAC)
Harga modal dihitung otomatis setiap barang masuk:

```
avg/kg = (Σ stock×buy_price + nilai_masuk) / (Σ stock×factor + qty_masuk)
buy_price variant = avg × conversion_factor
```

Pada konversi product dengan penyusutan (5 kg ikan → 3 kg fillet),
seluruh nilai tetap dibebankan ke hasil jadi — buangan otomatis menjadi
beban cost produk jadi. Profit penjualan tetap akurat secara historis
karena harga di-*snapshot* ke `order_items` saat order dibuat.

### Ledger Everywhere
Setiap mutasi tercatat: `cash_ledgers`, `variant_conversion_ledger`,
`product_conversion_ledger`, `stock_opname_ledger` — lengkap dengan
snapshot harga/factor saat kejadian, jadi selalu bisa diaudit.

---

## 🏗️ Arsitektur

```
Flutter (UI + service layer tipis)
   │  supabase_flutter → PostgREST + RPC
   ▼
Supabase / PostgreSQL
   ├─ Business logic di PL/pgSQL functions (RPC)
   │    · atomic (1 function = 1 transaksi)
   │    · row locking (SELECT ... FOR UPDATE, anti-deadlock ordering)
   │    · validasi stok & konsistensi di sisi database
   └─ Ledger tables untuk audit trail
```

Prinsip: **logic yang menyentuh uang & stok hidup di database**, Flutter
hanya menampilkan dan mengumpulkan input. Ini membuat data konsisten
walau ada multi-user atau koneksi putus di tengah jalan.

```
lib/
├── pages/            # UI per halaman (main_menu, product, order,
│                     #   convert_variant, convert_product, opname, report, ...)
├── services/
│   └── supabase_service.dart   # semua akses data & pemanggilan RPC
└── helpers/          # util (format currency, dll)
sql/
└── rpc_*.sql         # schema tambahan, ledger tables, semua RPC
```

---

## 🚀 Setup

### Prasyarat
- Flutter SDK ≥ 3.x (Dart ≥ 2.17, null safety)
- Akun [Supabase](https://supabase.com) (free tier cukup)

### 1. Database
Buat project Supabase, lalu jalankan SQL di **SQL Editor** dengan urutan:

1. Schema dasar (tables: `products`, `product_variants`, `orders`,
   `order_items`, `customers`, `suppliers`, `transactions`,
   `transaction_items`, `transaction_categories`, `cash`, `cash_ledgers`, `users`)
2. `alter table product_variants add column conversion_factor numeric(10,4) not null default 1;`
3. Ledger tables + seluruh file `sql/rpc_*.sql`
4. Seed minimal: 1 baris `cash`, kategori transaksi
   (`Product Purchases`, kategori sale id=1, dst.)

### 2. Aplikasi
```bash
git clone <repo-url> && cd <repo>
flutter pub get
```

Isi kredensial Supabase di inisialisasi app (`main.dart`):
```dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: '<anon-key>',
);
```

```bash
flutter run
```

### 3. Data pertama
Buat product lewat menu **Products → (+)** — variant `default` dibuat
otomatis. Tambah variant kemasan lewat tombol **Add** di card product
(isi conversion factor, mis. cup 500 gr = `0.5`).

---

## 🧪 Verifikasi Cepat

- Kulakan product → cek `buy_price default × factor` = buy_price tiap variant
- Pack 4× cup 500 gr → default berkurang 2 kg, ledger tercatat
- Convert 5 kg → 3 kg (susut) → avg cost tujuan naik sesuai rumus
- Edit product = edit variant default (selalu sinkron dua arah)
- Opname → selisih tercatat per item dalam kg dan rupiah

---

## 🗺️ Roadmap

- [ ] **Row Level Security** (prioritas keamanan — anon key ada di APK)
- [ ] Void/koreksi kulakan (perlu reverse WAC)
- [ ] Kolom `packing_cost` per variant (biaya cup/tenaga repack)
- [ ] Hutang-piutang (status `partial`/`settled` sudah disiapkan di schema)
- [ ] Struk/invoice via WhatsApp
- [ ] Supabase Realtime menggantikan polling dashboard
- [ ] Category picker (ganti input angka manual)

---

## 📄 Lisensi

Private project — internal business use.

---

*Dibangun dengan Flutter 💙 Supabase ⚡ dan banyak diskusi soal harga rata-rata ikan.*