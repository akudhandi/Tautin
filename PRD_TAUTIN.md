# Product Requirements Document (PRD): Tautin

| Metadata Dokumen | Detail Spesifikasi |
| :--- | :--- |
| **Nama Produk** | **Tautin** |
| **Judul Play Store (ASO)** | **Tautin: Simpan Link & Catatan AI** |
| **Tagline Utama** | *"Temukan di mana saja, Tautin di sini."* |
| **Payung Brand / Developer** | **Senggang Labs** (`https://www.sengganglabs.my.id/`) |
| **URL Produk & Web Viewer** | `https://www.sengganglabs.my.id/tautin/` |
| **Android Package Name** | `id.my.sengganglabs.tautin` |
| **Target Platform** | Android (Google Play Store) + Web Viewer (Next.js SSR) |
| **Model Bisnis** | Micro SaaS — Freemium, Langganan Bulanan/Tahunan, & Lifetime Deal |
| **Infrastruktur Billing** | Native Google Play Billing (`in_app_purchase` + Google Play Developer API) |
| **Versi Dokumen** | v1.0 — Full Production Specification |

---

## 1. Visi Produk & Latar Belakang Masalah

### 1.1 Masalah Utama Pengguna (Problem Statement)
Pengguna smartphone di Indonesia mengonsumsi ratusan konten setiap hari dari berbagai aplikasi (TikTok, Instagram, Shopee, Tokopedia, YouTube, X/Twitter, dan browser). Saat menemukan informasi penting yang ingin disimpan untuk nanti, pengguna menghadapi 4 masalah utama:
1. **Fragmentasi Penyimpanan (*Siloed Bookmarks*):** Video resep disimpan di *Bookmark* TikTok, barang impian di *Wishlist* Shopee, lowongan kerja di *Saved* Instagram, dan artikel di *Tab* Chrome. Saat dibutuhkan kembali, pengguna lupa di aplikasi mana informasi tersebut disimpan.
2. **Kekacauan Chat ke Diri Sendiri (*WhatsApp Self-Chat Clutter*):** Mayoritas pengguna umum mengambil jalan pintas dengan mengirim link ke nomor WhatsApp pribadi atau grup kosong. Akibatnya, link menumpuk bersama chat lain, hanya tampil sebagai teks URL mentah tanpa gambar/judul yang jelas, tidak memiliki kategori, dan mustahil dicari saat sudah tertimbun ratusan pesan.
3. **Kemalasan Mengorganisir Manual (*High Friction*):** Aplikasi *bookmark manager* yang ada di pasaran mengharuskan pengguna mengetik judul, memilih folder, dan menulis *tag* secara manual saat menyimpan link. Karena proses ini mengganggu keasyikan *scrolling*, pengguna malas melakukannya.
4. **Kuburan Tautan (*Bookmark Graveyard*):** Lebih dari 80% link yang disimpan tidak pernah dibuka kembali karena tidak adanya sistem pengingat pintar dan pengguna malas membuka ulang link satu per satu untuk mengingat apa isinya.

### 1.2 Solusi yang Ditawarkan Tautin
**Tautin** adalah aplikasi manajemen tautan pintar berbasis AI yang dirancang khusus untuk pasar umum (*mass market*). 
* **Cara Kerja Instan (Zero-Effort):** Pengguna cukup menekan tombol **Share -> pilih Tautin** dari aplikasi mana pun. Muncul *pop-up* kecil di bawah layar selama 1,5 detik, lalu tertutup otomatis agar pengguna bisa lanjut *scrolling*.
* **Otomatisasi AI di Latar Belakang:** Server Tautin secara otomatis mengekstrak isi tautan, membersihkan judul dari kata-kata promosi sampah, membuat ringkasan padat (1–2 kalimat Bahasa Indonesia), memasukkan link ke folder kategori yang paling cocok, dan memberikan 3 *tag* kata kunci.
* **Anti-Lupa:** Tautin mengingatkan pengguna melalui fitur *Resurfacing* ("Belum Dibaca Minggu Ini") dan pengingat terjadwal (*Custom Reminder*).

### 1.3 Metrik Keberhasilan Produk (Success Metrics / KPI)
* **Time-to-Save:** Waktu yang dibutuhkan pengguna dari menekan ikon *Tautin* di menu Share hingga kembali ke aplikasi asal adalah **< 2 detik** (Respons API **< 300ms**).
* **AI Categorization Accuracy:** Minimal **85%** link yang disimpan dengan AI tidak perlu dipindahkan foldernya secara manual oleh pengguna.
* **Free-to-Pro Conversion Rate:** Target konversi **2% – 5%** dari pengguna aktif bulanan (MAU) ke paket berbayar (Pro/Lifetime).

---

## 2. Target Pasar & Persona Pengguna (Pasar General)

| Persona | Kebiasaan Menyimpan Link | Kebutuhan Spesifik di Tautin |
| :--- | :--- | :--- |
| **1. Pemburu Belanja (*Shopper*)** | Menyimpan link produk dari Shopee, Tokopedia, TikTok Shop untuk dibeli saat gajian atau tanggal kembar. | • Membersihkan teks kotor bawaan *share* e-commerce.<br>• Menampilkan foto barang & judul bersih.<br>• Pengingat waktu *checkout* barang. |
| **2. Pengumpul Ide Harian (*Lifestyle*)** | Menyimpan video resep masakan (TikTok/Reels), tempat nongkrong/kuliner (IG/Maps), dan ide *outfit* / dekorasi rumah. | • Ringkasan AI langsung menyebutkan bahan utama resep.<br>• Mudah dicari dengan kata kunci sehari-hari (misal: *"ayam bawang putih"*). |
| **3. Pelajar & Pekerja (*Learner*)** | Menyimpan jurnal, referensi skripsi, *thread* X, video tutorial YouTube, dan *tools* produktivitas. | • Ringkasan AI menjelaskan intisari artikel (TL;DR).<br>• Fitur *Catatan Pribadi* di setiap link untuk menulis poin penting. |
| **4. Kurator Sosial (*Sharer*)** | Suka membagikan kumpulan link ke teman (misal: *"List Kosan Dekat Kampus"*, *"Perlengkapan Bayi"*). | • Mengubah 1 folder koleksi menjadi link publik (`sengganglabs.my.id/tautin/c/...`) yang rapi saat dibuka di browser. |

---

## 3. Spesifikasi Fungsional & Kriteria Penerimaan (Functional Requirements)

### Modul 1: Autentikasi, Akun & Smart Onboarding (`FR-AUTH`)

#### `FR-AUTH-01`: Autentikasi Satu Klik (Google Sign-In)
* **Deskripsi:** Pengguna mendaftar dan masuk hanya dengan satu tombol **"Lanjutkan dengan Google"** tanpa perlu mengisi form pendaftaran atau verifikasi email manual.
* **Kriteria Penerimaan (Acceptance Criteria):**
  * `AC-1`: Jika akun Google belum terdaftar di database, sistem membuat baris baru di tabel `users` dengan `plan_type = 'free'` dan `ai_quota_left = 10`.
  * `AC-2`: Jika akun sudah terdaftar, sistem langsung mengembalikan token sesi (Laravel Sanctum) dan memuat data pengguna.

#### `FR-AUTH-02`: Seeding Koleksi Bawaan (Zero-Blank-State Onboarding)
* **Deskripsi:** Pengguna baru tidak boleh dihadapkan pada aplikasi kosong yang membingungkan. Saat registrasi pertama, sistem otomatis membuatkan 5 koleksi (*folder*) bawaan yang seluruhnya ditandai `is_default = true` (tidak pernah memakan slot koleksi kustom pengguna).
* **Kriteria Penerimaan:**
  * `AC-1`: Lima koleksi berikut otomatis dibuat untuk user baru (semua `is_default = true`):
    1. `Belanja & Wishlist` (Ikon: `shopping_bag`, Warna: `#EC4899`)
    2. `Resep & Kuliner` (Ikon: `restaurant`, Warna: `#F59E0B`)
    3. `Tontonan & Hiburan` (Ikon: `play_circle`, Warna: `#EF4444`)
    4. `Belajar & Referensi` (Ikon: `school`, Warna: `#3B82F6`)
    5. `Tempat & Jalan-jalan` (Ikon: `place`, Warna: `#10B981`)
  * `AC-2`: Setelah login pertama kali, tampilkan panduan visual singkat (3 *slides* interaktif) yang mendemonstrasikan cara menekan tombol **Share -> Tautin** dari aplikasi lain.

#### `FR-AUTH-03`: Penghapusan Akun & Data Permanen (Kepatuhan Google Play)
* **Deskripsi:** Pengguna dapat menghapus akun dan seluruh datanya secara mandiri.
* **Kriteria Penerimaan:**
  * `AC-1`: Tersedia tombol **"Hapus Akun Permanen"** di halaman Pengaturan aplikasi dengan dialog konfirmasi ganda; endpoint `DELETE /api/v1/auth/account` wajib menerima body `{"confirmation": "HAPUS"}` — permintaan tanpa konfirmasi tersebut ditolak dengan `422 VALIDATION_ERROR`.
  * `AC-2`: Saat dieksekusi, seluruh data `users`, `collections`, `links`, dan `tags` milik pengguna dihapus permanen (`ON DELETE CASCADE`) dari database.
  * `AC-3`: Tersedia halaman web `https://www.sengganglabs.my.id/tautin/delete-account` bagi pengguna yang sudah mencopot aplikasi namun ingin mengajukan penghapusan data.

---

### Modul 2: "Quick Taut" — Penyimpanan Instan & Pembersih URL (`FR-SAVE`)

#### `FR-SAVE-01`: Integrasi Native Android Share Sheet
* **Deskripsi:** Aplikasi Tautin muncul sebagai target penerima saat pengguna menekan tombol *Share* di aplikasi Android mana pun.
* **Kriteria Penerimaan:**
  * `AC-1`: Terdaftar pada `AndroidManifest.xml` dengan action `android.intent.action.SEND` dan `mimeType="text/plain"`.
  * `AC-2`: Saat dipilih, aplikasi hanya memunculkan **`QuickTautBottomSheet`** (tinggi maksimal 35% layar) di atas aplikasi yang sedang dibuka pengguna, bukan membuka *full screen activity* yang berat.

#### `FR-SAVE-02`: Pembersih Teks Kotor & Ekstraktor URL (Dirty Share Text Parser)
* **Deskripsi:** Aplikasi seperti Shopee, Tokopedia, dan TikTok menyisipkan kalimat promosi panjang saat membagikan link. Sistem harus memisahkan URL murni dari teks promosi tersebut.
* **Contoh Kasus Input:**
  `"Temukan Sepatu Running Pria Ortuseight seharga Rp349.000 hanya di Shopee! https://id.shp.ee/AbCdEfG"`
* **Kriteria Penerimaan:**
  * `AC-1`: Sistem mengekstrak `https://id.shp.ee/AbCdEfG` sebagai `url`.
  * `AC-2`: Teks sisanya (`"Temukan Sepatu Running Pria Ortuseight seharga Rp349.000 hanya di Shopee!"`) disimpan ke kolom `raw_description` sebagai informasi cadangan untuk AI jika halaman web target memblokir *scraper*.
  * `AC-3`: Jika di dalam teks yang dibagikan tidak ditemukan format URL valid (`http://` atau `https://`), tampilkan pesan *toast*: *"Teks yang dibagikan tidak mengandung tautan (link) yang valid."*

#### `FR-SAVE-03`: Perilaku Interaksi di Quick Taut Bottom Sheet
* **Deskripsi:** Memberikan kendali cepat kepada pengguna tanpa menghambat waktu mereka.
* **Kriteria Penerimaan:**
  * `AC-1`: Begitu *Bottom Sheet* terbuka, aplikasi **langsung** mengirim request simpan ke server (mode *Auto-Save*) dengan pilihan folder default: **"✨ Otomatis oleh AI"** (atau folder pertama jika kuota AI habis).
  * `AC-2`: Menampilkan *countdown bar* selama **2 detik** sebelum *Bottom Sheet* menutup dirinya sendiri secara otomatis.
  * `AC-3`: Jika dalam jeda 2 detik tersebut pengguna menyentuh pilihan koleksi atau tombol *"Tambah Catatan"*, maka *auto-close timer* dibatalkan agar pengguna bisa memilih folder atau mengetik catatan dengan tenang.

#### `FR-SAVE-04`: Deteksi Link di Clipboard & Input Manual
* **Deskripsi:** Mendukung pengguna yang terbiasa menekan *"Salin Tautan (Copy Link)"* alih-alih menekan tombol *Share*.
* **Kriteria Penerimaan:**
  * `AC-1`: Saat pengguna membuka aplikasi utama Tautin, aplikasi memeriksa isi *Clipboard* HP. Jika berisi URL valid yang belum pernah disimpan, munculkan *Floating Banner* di bagian bawah: *"Tautan terdeteksi di clipboard: [domain.com]. **[Simpan Sekarang]**"*.
  * `AC-2`: Tersedia tombol `+` (*Floating Action Button*) di layar utama untuk menempelkan link secara manual.

---

### Modul 3: Mesin Scraper & AI Auto-Organizer (`FR-AI`)

#### `FR-AI-01`: Pemrosesan Latar Belakang (Asynchronous Queue)
* **Deskripsi:** Proses pengambilan data website dan analisis AI tidak boleh membuat HP pengguna menunggu.
* **Kriteria Penerimaan:**
  * `AC-1`: Endpoint penyimpanan link merespons dalam waktu **< 300ms** dengan status awal link `status = 'pending'`.
  * `AC-2`: Di layar Beranda aplikasi, link yang berstatus `'pending'` atau `'processing'` menampilkan indikator animasi halus: *"✨ AI sedang merangkum dan merapikan tautan ini..."*

#### `FR-AI-02`: Strategi Multi-Layer Scraping & Resolusi Shortlink
* **Deskripsi:** Mengambil metadata yang akurat dari berbagai jenis platform yang memiliki proteksi berbeda.
* **Kriteria Penerimaan:**
  * `AC-1` (**Unshorten URL**): Mengikuti maksimal 5 kali *HTTP Redirect* (`vt.tiktok.com`, `shp.ee`, `s.id`, `bit.ly`) hingga mendapatkan URL tujuan akhir (*canonical URL*) dan menghapus parameter pelacak (`utm_source`, `fbclid`, `igshid`).
  * `AC-2` (**Layer 1 - Official oEmbed**): Untuk domain YouTube, TikTok, dan X/Twitter, memprioritaskan pemanggilan endpoint oEmbed resmi agar mendapatkan judul video, kreator, dan *thumbnail* tanpa diblokir.
  * `AC-3` (**Layer 2 - OpenGraph & Artikel**): Mengekstrak `og:title`, `og:image`, `og:description`, dan isi paragraf utama artikel (maksimal 3.000 karakter pertama).
  * `AC-4` (**Layer 3 - Fallback Anti-Blokir**): Jika situs target mengembalikan error `403 Forbidden` / `429 Too Many Requests` / halaman Captcha, sistem menggunakan `raw_description` bawaan dari *Share Intent* serta struktur kata pada URL untuk diolah oleh AI.

#### `FR-AI-03`: Analisis Gemini AI (`gemini-2.5-flash`)
* **Deskripsi:** Mengubah metadata mentah menjadi informasi terstruktur yang rapi dan siap dibaca.
* **Kriteria Penerimaan:**
  * `AC-1` (**Judul Bersih**): Menghasilkan `clean_title` yang membuang kata-kata spam SEO (contoh: mengubah *"Jual Promo Diskon 50% Keyboard Mekanikal Murah Terlaris | Tokopedia"* menjadi *"Keyboard Mekanikal"*).
  * `AC-2` (**Ringkasan Kontekstual 2 Kalimat**): Menghasilkan `ai_summary` berbahasa Indonesia:
    * Jika konten **Resep**: Wajib menyebutkan nama hidangan dan bahan-bahan utamanya.
    * Jika konten **E-Commerce/Produk**: Wajib menyebutkan nama produk, kategori, dan keunggulan/harga (jika tertera di deskripsi).
    * Jika konten **Artikel/Edukasi**: Wajib menyebutkan kesimpulan atau poin inti bahasan.
  * `AC-3` (**Auto-Folder Mapping**): AI memilihkan satu folder dari daftar koleksi yang dimiliki pengguna saat ini.
  * `AC-4` (**Auto-Tagging**): AI menghasilkan maksimal 3 *tags* spesifik dalam format huruf kecil (contoh: `["resep-ayam", "menu-sahur", "masakan-mudah"]`).
  * `AC-5` (**Klasifikasi Sumber**): AI mengklasifikasikan `source_type` ke dalam salah satu dari: `'video'`, `'ecommerce'`, `'article'`, `'social'`, atau `'other'`.

---

### Modul 4: Beranda Pintar, Pencarian & Detail Tautan (`FR-FEED`)

#### `FR-FEED-01`: Tampilan Kartu Pintar (Smart Link Cards)
* **Deskripsi:** Menampilkan tautan secara visual dan informatif di layar Beranda.
* **Kriteria Penerimaan:**
  * `AC-1`: Setiap kartu menampilkan: Ikon/Favicon domain asal, nama domain (misal: `tiktok.com`), waktu simpan relatif (*"2 jam lalu"*), gambar *thumbnail* (dengan ikon ▶ di tengah jika `source_type == 'video'` atau ikon 🛒 jika `'ecommerce'`), Judul Bersih (maks 2 baris), Kotak Ringkasan AI berlatar ungu lembut dengan ikon `✨`, label Koleksi, dan deretan `#tags`.
  * `AC-1a`: Jika link tersimpan tanpa ringkasan AI karena kuota habis (`ai_summary == null`), kotak ringkasan digantikan banner halus: **"✨ Kuota ringkasan AI habis — Upgrade ke Pro"** (menjaga prinsip *Soft-Paywall*, tanpa memblokir penyimpanan).
  * `AC-2`: Pengguna dapat menyematkan (*Pin*) link penting agar selalu berada di urutan paling atas.

#### `FR-FEED-02`: Pencarian Kontekstual & Filter Multi-Dimensi
* **Deskripsi:** Memudahkan pengguna menemukan link meskipun mereka lupa judul persisnya.
* **Kriteria Penerimaan:**
  * `AC-1`: Kolom pencarian mencari kecocokan kata di dalam **Judul**, **Ringkasan AI**, **Catatan Pribadi (`user_notes`)**, **Nama Domain**, dan **Tags**. (Contoh: Mengetik *"bawang putih"* akan memunculkan link video TikTok yang ringkasan AI-nya mengandung bahan bawang putih, meskipun judul videonya hanya *"Masak Enak Cek!"*).
  * `AC-2`: Tersedia barisan *Filter Chips* horizontal untuk memfilter secara instan berdasarkan Koleksi maupun Jenis Konten (`Semua`, `🎬 Video`, `🛒 Belanja`, `📄 Artikel`, `👀 Belum Dibaca`, `📦 Tanpa Koleksi`).
  * `AC-3`: Chip **"📦 Tanpa Koleksi"** memanggil `GET /api/v1/links?collection_id=unassigned` untuk menampilkan semua link dengan `collection_id = null` (misal hasil penghapusan koleksi dengan aturan `ON DELETE SET NULL`).

#### `FR-FEED-03`: Layar Detail Link & Catatan Pribadi
* **Deskripsi:** Saat kartu link diklik, pengguna tidak langsung dilempar keluar aplikasi, melainkan melihat halaman ringkasan penuh terlebih dahulu.
* **Kriteria Penerimaan:**
  * `AC-1`: Menampilkan gambar *thumbnail* penuh, judul lengkap, kotak Ringkasan AI penuh, dan tombol besar **"Buka di Aplikasi Asli / Browser"**.
  * `AC-2`: Saat tombol **"Buka di Aplikasi Asli"** ditekan, status `is_read` otomatis berubah menjadi `true`.
  * `AC-3`: Terdapat kolom **Catatan Pribadi (`user_notes`)** tempat pengguna bisa menulis memo sendiri (contoh: *"Beli ukuran XL warna Hitam"* atau *"Kutip paragraf ke-3 untuk Bab 2"*).
  * `AC-4`: Pengguna dapat memindahkan link ke koleksi lain, mengedit judul manual, atau menghapus link.

---

### Modul 5: Fitur Anti-Lupa — Resurfacing & Pengingat (`FR-REM`)

#### `FR-REM-01`: Carousel "Belum Dibaca Minggu Ini" (Resurfacing)
* **Deskripsi:** Mengangkat kembali tautan yang sudah disimpan namun terlupakan.
* **Kriteria Penerimaan:**
  * `AC-1`: Endpoint `GET /api/v1/links/resurface` hanya mengembalikan tautan ketika pengguna memiliki **minimal 3 link** dengan status `is_read = false` yang disimpan lebih dari 3 hari yang lalu (`created_at <= now - 3 hari`). Jika jumlah link yang memenuhi syarat **kurang dari 3**, API mengembalikan array kosong `[]` sehingga section ini sepenuhnya disembunyikan di Beranda.
  * `AC-2`: Ketika syarat minimum terpenuhi, API mengembalikan **3 kartu geser (*horizontal carousel*) yang diacak setiap hari** (`inRandomOrder`, maksimal 3 item).

#### `FR-REM-02`: Pengingat Terjadwal per Link (Custom Reminder — Fitur Pro)
* **Deskripsi:** Pengguna dapat mengatur alarm notifikasi pada link tertentu.
* **Kriteria Penerimaan:**
  * `AC-1`: Tersedia pilihan cepat (*"Nanti Malam Jam 19:00"*, *"Besok Pagi Jam 08:00"*, *"Akhir Pekan Ini"*) serta *Date & Time Picker* bebas.
  * `AC-2`: Saat waktunya tiba, server mengirim *Push Notification* (via FCM) dengan judul link dan cuplikan ringkasan AI. Menekan notifikasi akan langsung membuka layar Detail Link tersebut di Tautin.

---

### Modul 6: Viral Loop — Koleksi Publik & Web Viewer (`FR-SHARE`)

#### `FR-SHARE-01`: Pengaturan Koleksi Publik / Privat
* **Deskripsi:** Pengguna dapat membagikan satu folder kumpulan link kepada orang lain melalui satu tautan web.
* **Kriteria Penerimaan:**
  * `AC-1`: Secara default, seluruh koleksi bersifat **Privat** (`is_public = false`).
  * `AC-2`: Saat pengguna mengaktifkan *toggle* **"Bagikan ke Publik"**, sistem membuatkan URL unik: `https://www.sengganglabs.my.id/tautin/c/{slug}`.
  * `AC-3`: Demi privasi, halaman publik **tidak pernah** menampilkan alamat email pemilik maupun isi `user_notes` pribadi.
  * `AC-4`: **Kustomisasi URL Slug (Khusus Pro):** Pengguna Pro/Lifetime dapat mengganti slug publik koleksinya melalui `PATCH /api/v1/collections/{id}` dengan bidang opsional `slug` (`alpha_dash`, 3–100 karakter, unik). Pengguna gratis yang mencoba mengganti slug menerima `PRO_REQUIRED_FOR_CUSTOM_SLUG`.

#### `FR-SHARE-02`: Halaman Web Publik Next.js & Konversi Pengguna Baru
* **Deskripsi:** Menampilkan koleksi link di browser dengan tampilan modern yang memicu orang lain untuk mengunduh Tautin.
* **Kriteria Penerimaan:**
  * `AC-1`: Mendukung *Server-Side Rendering (SSR)* dan *OpenGraph Meta Tags* dinamis sehingga saat link dibagikan di WhatsApp/Telegram/X, muncul *preview* dengan format judul baku: **`📂 {collection.name} ({links_count} Tautan) — Dikurasi oleh {owner_name} di Tautin (Dirapikan oleh AI)`** (contoh: *"📂 Belanja & Wishlist (23 Tautan) — Dikurasi oleh Rani di Tautin (Dirapikan oleh AI)"*).
  * `AC-2`: Di bagian bawah layar web, terdapat *Sticky Banner*: **"Ingin menyimpan dan merangkum link otomatis seperti ini? Download Tautin di Google Play Store"** serta tombol **"Simpan Koleksi Ini ke Akun Tautin Saya"** (menggunakan Android App Links untuk langsung membuka aplikasi Tautin jika sudah terinstal).

---

## 4. Spesifikasi Monetisasi, Kuota & Native Google Play Billing

Sistem pembayaran **tidak menggunakan layanan pihak ketiga (tanpa RevenueCat)**. Seluruh transaksi dikelola menggunakan **Flutter `in_app_purchase`** dan diverifikasi langsung oleh backend Laravel ke **Google Play Developer API (`AndroidPublisher`)**.

### 4.1 Struktur Produk & Harga di Google Play Console

| Product ID | Tipe Produk Google Play | Nama Paket di UI | Harga Jual (IDR) | Siklus Tagihan |
| :--- | :--- | :--- | :--- | :--- |
| `tautin_pro_monthly` | Subscription | **Tautin Pro Bulanan** | **Rp 29.000** | Setiap Bulan |
| `tautin_pro_yearly` | Subscription | **Tautin Pro Tahunan** *(Hemat 28%)* | **Rp 249.000** | Setiap Tahun (Rp 20.750/bln) |
| `tautin_pro_lifetime` | In-App Product (Non-Consumable) | **Tautin Pro Selamanya** *(Early Bird)* | **Rp 349.000** | Sekali Bayar Seumur Hidup |

### 4.2 Perbandingan Hak Akses (Entitlements Matrix)

| Fitur & Batasan Kuota | Pengguna Gratis (`free`) | Pengguna Pro (`pro` / `lifetime`) |
| :--- | :--- | :--- |
| **Simpan Link, Bersihkan Judul, Auto-Folder & Auto-Tag** | **GRATIS & Tanpa Batas (*Unlimited*)** | **GRATIS & Tanpa Batas (*Unlimited*)** |
| **Kuota Ringkasan AI (`ai_summary`)** | **10 Ringkasan / Bulan** *(Reset tanggal 1 pukul 00:01 WIB)* | **Fair Use: 500 ringkasan/bln** *(Reset tanggal 1 pukul 00:01 WIB)* |
| **Batas Pembuatan Koleksi (Folder)** | **5 koleksi bawaan + maksimal 3 koleksi kustom** (total 8) | **Tanpa Batas (*Unlimited*)** |
| **Pencarian Kontekstual (Full-Text Search)** | Tersedia | Tersedia |
| **Pengingat Kustom per Link (`remind_at`)** | Terkunci (🔒 Khusus Pro) | Tersedia |
| **Koleksi Publik (`sengganglabs.my.id/tautin/c/...`)** | Maksimal **1 Koleksi Publik** | **Tanpa Batas** + *Custom URL Slug* (Pro-only, 3–100 karakter) |
| **Regenerasi Ringkasan AI Manual (`POST /links/{id}/regenerate-ai`)** | Tidak Tersedia (`PRO_REQUIRED_FOR_REGENERATE`) | Tersedia (mengurangi kuota ringkasan AI) |

### 4.3 Aturan Perilaku Kuota & Soft-Paywall (Penting!)
1. **Dilarang Memblokir Penyimpanan Link (No Hard-Block on Core Save):**
   Yang memakan `ai_quota_left` **hanya pembuatan Ringkasan AI (`ai_summary`)**. Menyimpan link, membersihkan judul, memilihkan folder kategori otomatis, dan membuat tags adalah **gratis & tanpa batas** untuk semua pengguna.
   Saat kuota ringkasan AI pengguna habis (`ai_quota_left == 0`), pengguna **tetap dapat menyimpan link dari aplikasi lain tanpa batas**. Pipeline latar belakang (`ProcessSharedLinkJob`) tetap menjalankan *scraper* untuk mengambil judul & gambar *thumbnail*, lalu:
   * Memilihkan koleksi dengan **pencocokan kata kunci sederhana** (kata pada judul/domain tautan vs nama koleksi pengguna), dengan *fallback* ke koleksi default pertama.
   * Mengatur `ai_summary = null`, `is_ai_processed = false`, dan `status = 'completed'`.
   * Di UI Flutter (`SmartLinkCard` dan *Quick Taut Sheet*), jika `ai_summary == null` maka tampil banner halus:
   > *"✨ Kuota ringkasan AI habis — Upgrade ke Pro"*
2. **Titik Pemicu Layar Paywall (Paywall Triggers):**
   Layar penawaran **Tautin Pro** akan muncul secara otomatis ketika pengguna gratis:
   * Menekan tombol *"Buat Koleksi Baru"* saat sudah memakai seluruh **3 slot koleksi kustom** (5 koleksi bawaan gratis + maksimal 3 koleksi buatan sendiri).
   * Menekan ikon lonceng *"Pasang Pengingat"* pada detail link.
   * Mencoba mengaktifkan koleksi publik ke-2.
   * Menekan *badge* sisa kuota AI di pojok atas layar Beranda (`✨ Sisa AI: 2/10`).
   * Menekan tombol *"Buat Ulang Ringkasan AI"* pada detail link (khusus Pro; pengguna gratis melihat `PRO_REQUIRED_FOR_REGENERATE`).
3. **Verifikasi & Keamanan Pembelian (Anti-Mod APK / Replay Attack):**
   * Setiap pembelian di Flutter wajib mengirimkan `product_id` dan `purchase_token` ke endpoint Laravel `POST /api/v1/billing/verify-purchase`.
   * Backend Laravel memvalidasi token tersebut langsung ke server Google Play, melakukan *acknowledgement*, dan menyimpan `SHA-256(purchase_token)` agar satu struk pembelian tidak bisa diklaim oleh akun lain.
   * Tersedia tombol **"Pulihkan Pembelian (Restore Purchase)"** di layar Paywall dan Pengaturan untuk memulihkan status Pro saat pengguna berganti HP.
4. **Refund & Pencabutan (Voided Purchases + Real-Time Developer Notifications):**
   * Komando jadwal `tautin:sync-subscriptions` (per jam) mengunduh **Voided Purchases** dari Google Play Developer API. Purchase_token yang terbukti di-refund diubah `subscriptions.status = 'refunded'`, pengguna diturunkan ke `plan_type = 'free'`, dan `ai_quota_left` dipangkas menjadi `min(kuota saat ini, 10)` — tanpa pernah menaikkan kuota. Mekanisme ini mencakup **purchase `tautin_pro_lifetime`** yang tidak terjaring pemeriksaan tanggal kedaluwarsa (`plan_expires_at = null`).
   * Endpoint `POST /api/v1/webhooks/google-play-rtdn` (dilindungi *secret* `GOOGLE_PLAY_RTDN_SECRET` via query `?secret=` atau header `X-RTDN-Secret`) menerima push Pub/Sub: tipe `subscriptionNotification` 1 (RECOVERED) / 2 (RENEWED) memverifikasi ulang & mengembalikan status Pro, sedangkan tipe 3 (CANCELED) / 12 (REVOKED) / 13 (EXPIRED) maupun `voidedPurchaseNotification` langsung mencabut langganan terkait, idempoten untuk baris yang sudah `refunded`.

---

## 5. Spesifikasi Desain Antarmuka (UI/UX & Screen Blueprint)

### 5.1 Identitas Visual & Palet Warna
* **Gaya Desain:** Modern, bersih, membulat (*rounded corners* `16px` untuk kartu, `12px` untuk tombol), memadukan kerapian visual **Pinterest** dengan kemudahan **Google Keep**.
* **Sistem Warna (Color Tokens):**
  * **Primary Brand:** Electric Indigo (`#4F46E5`)
  * **AI Magic Accent:** Soft Violet (`#8B5CF6`) — selalu dipasangkan dengan ikon kilau `✨`.
  * **Light Mode:** Background `#F8FAFC` (Slate 50), Surface Card `#FFFFFF`, Text Primary `#0F172A`, Text Secondary `#64748B`, AI Summary Box `#F5F3FF` (Border `#DDD6FE`).
  * **Dark Mode:** Background `#0F172A` (Slate 900), Surface Card `#1E293B`, Text Primary `#F8FAFC`, Text Secondary `#94A3B8`, AI Summary Box `#1E1B4B` (Border `#4C1D95`).
* **Tipografi:**
  * Heading & Judul Kartu: **`Plus Jakarta Sans`** (*SemiBold* / *Bold*).
  * Body, Ringkasan AI & Tag: **`Inter`** (*Regular* / *Medium*).

### 5.2 Daftar Layar Aplikasi (Screen-by-Screen Spec)
1. **Onboarding & Login Screen:**
   * Ilustrasi cara kerja Tautin (3 slide singkat) + Tombol **"Lanjutkan dengan Google"** + Tautan kecil ke Kebijakan Privasi & Syarat Ketentuan.
2. **Quick Taut Bottom Sheet (Overlay):**
   * Tinggi sheet baku = **32% tinggi layar** (`maxHeight * 0.32`), durasi *auto-close* = **2 detik (`2000ms`)** dengan indikator progres linear.
   * Header: Logo Tautin + Status *"✨ Menyimpan tautan..."* + Indikator sisa kuota AI.
   * Body: Preview URL yang sedang disimpan + Pilihan *Horizontal Chips* untuk mengganti Koleksi secara manual jika diinginkan + Tombol *"Selesai"*.
3. **Home Screen (Layar Utama):**
   * **Top App Bar:** Logo Tautin di kiri, *Badge* Kuota AI (`✨ 8/10` atau `👑 PRO`) di kanan.
   * **Search Bar:** *"Cari barang, resep, topik, atau #tag..."*
   * **Section 1 (Conditional):** Carousel *"Belum Dibaca Minggu Ini"* (3 kartu kompak).
   * **Section 2 (Sticky Header):** Deretan *Filter Chips* Koleksi & Jenis Konten.
   * **Section 3 (Main Feed):** Daftar vertikal `SmartLinkCard` dengan fitur *Pull-to-Refresh* dan *Infinite Scroll Pagination*.
   * **Bottom Navigation Bar:** 3 Tab sederhana -> `Beranda`, `Koleksi`, `Profil & Pro`.
4. **Collections Screen (Tab Koleksi):**
   * Tampilan *Grid* 2 kolom berisi kartu folder koleksi lengkap dengan ikon, warna aksen, jumlah link di dalamnya, dan indikator `🌐 Publik` jika dibagikan.
5. **Link Detail & AI Reader Bottom Sheet / Screen:**
   * Gambar *thumbnail* besar, Judul yang bisa diedit, kotak penuh `✨ Ringkasan AI`, pemilih Koleksi, daftar `#tags`, area ketik `Catatan Pribadi`, pemilih `Pengingat (Remind Me)`, tombol `Bagikan`, dan tombol utama **"Buka Tautan Asli"**.
6. **Tautin Pro Paywall Screen:**
   * Header bergradasi Indigo-Violet, daftar manfaat Pro dengan ikon yang jelas, 3 kartu pilihan paket (`Bulanan`, `Tahunan - Paling Hemat`, `Lifetime - Sekali Bayar`), tombol CTA utama, dan tombol *"Pulihkan Pembelian"*.
7. **Profile & Settings Screen (Tab Profil):**
   * Info akun Google, status langganan, pengaturan tema (*Terang / Gelap / Sistem*), bagian **"Eksplorasi Aplikasi Senggang Labs Lainnya"** (kartu promosi aplikasi **Pilah** -> `sengganglabs.my.id/pilah/`), tautan Kebijakan Privasi, dan tombol *Keluar* / *Hapus Akun*.

---

## 6. Kebutuhan Non-Fungsional & Penanganan Edge Cases

### 6.1 Performa & Keandalan
* **Kecepatan Respons Simpan (`Quick Save`):** Maksimal **300ms** untuk penyimpanan awal ke database sebelum masuk antrean *worker*.
* **Batas Waktu Scraping & AI:** Maksimal **15 detik** total di latar belakang. Jika *website* target sangat lambat (>8 detik), *scraper* langsung menghentikan koneksi dan beralih ke *fallback metadata*.

### 6.2 Penanganan Kasus Khusus (Edge Cases)
1. **Tautan Duplikat (Duplicate URL):**
   * Jika pengguna menyimpan URL yang sama persis dengan yang sudah ada di akunnya, sistem **tidak memotong kuota AI** dan tidak membuat duplikat baru.
   * Deteksi duplikat bekerja **instan (< 1ms)** melalui dua hash SHA-256: `url_hash` (URL kanonik hasil *unshorten*) **dan** `raw_url_hash` (URL persis seperti pertama kali di-*share*, biasanya shortlink seperti `vt.tiktok.com/xyz`). Karena `ProcessSharedLinkJob` menulis ulang `url` + `url_hash` ke URL kanonik namun **tidak pernah mengubah `raw_url_hash`**, men-share shortlink yang sama untuk kedua kalinya — bahkan setelah link asli selesai di-*unshorten* — langsung terdeteksi sebagai duplikat (`meta.is_duplicate = true`, HTTP 200).
   * Sistem memperbarui waktu `updated_at` link lama agar naik ke urutan paling atas beranda, dan menampilkan info di *Bottom Sheet*: *"Tautan ini sudah ada di koleksimu, dinaikkan ke paling atas!"*
2. **Konten Privat / Butuh Login (Instagram Private, Grup FB Tertutup, Shopee Captcha):**
   * Ketika *scraper* terhalang halaman login, sistem tidak boleh menandai link sebagai gagal (`failed`).
   * Sistem memanfaatkan `raw_description` (caption yang ikut ter-*copy* saat di-*share* dari aplikasi HP) untuk dirangkum oleh Gemini AI. Jika `raw_description` juga kosong, gunakan nama domain sebagai judul sementara (misal: *"Tautan Instagram — Ketuk untuk melihat"*) dan simpan dengan status berhasil.
3. **Penyimpanan Saat Offline (Tidak Ada Sinyal / Kuota Habis):**
   * Jika pengguna menekan **Share -> Tautin** saat HP tidak terhubung ke internet, aplikasi menyimpan URL tersebut di memori lokal HP (`Hive Offline Queue`).
   * Begitu HP kembali terhubung ke internet dan aplikasi dibuka, aplikasi otomatis mengirim antrean tersebut ke server untuk diproses AI.

---

## 7. Integrasi Ekosistem Senggang Labs & Kepatuhan Play Store

Seluruh aset web publik untuk **Tautin** ditempatkan di bawah domain utama **Senggang Labs**:

| Path URL | Fungsi Halaman | Status Kewajiban Play Console |
| :--- | :--- | :--- |
| `https://www.sengganglabs.my.id/tautin/` | Landing page produk, fitur utama, & link Google Play. | Wajib untuk materi promosi & ASO |
| `https://www.sengganglabs.my.id/tautin/c/[slug]` | Halaman Web Viewer untuk koleksi publik (SSR Next.js). | Fitur Utama (*Viral Loop*) |
| `https://www.sengganglabs.my.id/tautin/privacy` | Kebijakan Privasi penggunaan data & AI. | **Wajib Mutlak** (Data Safety) |
| `https://www.sengganglabs.my.id/tautin/terms` | Syarat & Ketentuan layanan serta aturan langganan. | Wajib untuk aplikasi berbayar |
| `https://www.sengganglabs.my.id/tautin/delete-account` | Formulir/instruksi penghapusan akun & data pengguna. | **Wajib Mutlak** (Kebijakan Akun Baru) |
| `https://www.sengganglabs.my.id/.well-known/assetlinks.json` | File verifikasi *Android App Links* (`id.my.sengganglabs.tautin`). | Wajib untuk *Deep Linking* otomatis |