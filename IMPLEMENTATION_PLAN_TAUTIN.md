# Implementation Plan & Execution Roadmap: Tautin

| Metadata Dokumen | Detail Eksekusi |
| :--- | :--- |
| **Nama Proyek** | **Tautin** (`tautin-backend`, `tautin-mobile`, `tautin-web`) |
| **Payung Brand** | **Senggang Labs** (`https://www.sengganglabs.my.id/`) |
| **Android Package ID** | `id.my.sengganglabs.tautin` |
| **Acuan Dokumen** | `PRD.md` (Spesifikasi Produk) & `ARCHITECTURE.md` (Spesifikasi Teknis) |
| **Cara Penggunaan** | Kerjakan secara berurutan dari **Phase 1** hingga **Phase 7**. Tandai `[x]` hanya setelah seluruh kriteria *Verification & Definition of Done* pada fase tersebut terpenuhi. |

---

## Phase 1: Backend Foundation, Database Schema & Auth System (`tautin-backend`)

**Tujuan Fase 1:** Membangun fondasi REST API Laravel 11+, mengeksekusi seluruh skema tabel MySQL 8.0, menyiapkan format respons JSON standar, serta mengaktifkan login Google yang otomatis membuat 5 koleksi bawaan dan menerapkan batasan kuota koleksi untuk pengguna gratis.

### 1.1 Inisialisasi Proyek & Konfigurasi Dasar
- [x] **Setup Laravel 11+ & Paket Utama:**
  - Inisialisasi proyek di folder `tautin-backend/`.
  - Install paket wajib via Composer:
    - `laravel/sanctum` (Autentikasi API Token)
    - `google/apiclient` (Verifikasi Google ID Token & Google Play Developer API `AndroidPublisher`)
    - `symfony/dom-crawler` & `symfony/css-selector` (Parsing HTML & OpenGraph untuk *Scraper*)
- [x] **Buat File Konfigurasi Bisnis (`config/tautin.php`):**
  - Definisikan konstanta bisnis agar tidak *hardcoded* di dalam *controller*:
    - `free_plan.max_custom_collections` = `3` (5 koleksi bawaan `is_default = true` tidak dihitung)
    - `free_plan.max_public_collections` = `1`
    - `free_plan.monthly_ai_quota` = `10`
    - `pro_plan.fair_use_monthly_ai_quota` = `500`
    - `google_play.package_name` = `'id.my.sengganglabs.tautin'`
    - `google_play.products` = `['tautin_pro_monthly', 'tautin_pro_yearly', 'tautin_pro_lifetime']`
    - `google_play.rtdn_secret` = dari env `GOOGLE_PLAY_RTDN_SECRET` (proteksi webhook Pub/Sub `POST /webhooks/google-play-rtdn`)
    - `gemini.model` = `'gemini-2.5-flash'`

### 1.2 Standarisasi Respons API & Penanganan Error
- [x] **Buat Trait `app/Http/Traits/ApiResponseTrait.php`:**
  - Method `successResponse($data, string $message, int $code = 200, array $meta = [])` yang selalu mengembalikan struktur:
    `{ "success": true, "message": "...", "data": ..., "meta": ... }`
  - Method `errorResponse(string $errorCode, string $message, int $httpCode = 400, $errors = null)` yang mengembalikan struktur:
    `{ "success": false, "error_code": "...", "message": "...", "errors": ... }`
- [x] **Buat Custom Exception `app/Exceptions/BusinessLogicException.php`:**
  - Menerima parameter `$errorCode` (misal: `COLLECTION_LIMIT_REACHED`), `$message` (Bahasa Indonesia), dan `$httpStatus` (misal: `403`).
  - Daftarkan di `bootstrap/app.php` agar otomatis merender format JSON standar saat dilempar dari *Action* atau *Service*.

### 1.3 Migrasi Database & Model Eloquent (MySQL 8.0)
- [x] **Buat & Jalankan 5 Migrasi Utama (Sesuai DDL di `ARCHITECTURE.md`):**
  1. `database/migrations/xxxx_create_users_table.php` (Kolom: `id`, `name`, `email`, `google_id`, `avatar`, `plan_type`, `plan_expires_at`, `ai_quota_left`, `fcm_token`, timestamps + index).
  2. `database/migrations/xxxx_create_collections_table.php` (Kolom: `id`, `user_id`, `name`, `icon`, `color`, `slug`, `is_public`, `is_default`, `sort_order`, timestamps + foreign key cascade).
  3. `database/migrations/xxxx_create_links_table.php` (Kolom: `id`, `user_id`, `collection_id`, `url`, `url_hash`, `raw_url_hash` (CHAR(64) NULL — hash URL shortlink awal sebelum unshorten), `domain`, `source_type`, `title`, `thumbnail_url`, `raw_description`, `ai_summary`, `user_notes`, `status`, `is_ai_processed`, `is_pinned`, `is_read`, `remind_at`, `reminder_sent`, timestamps + `UNIQUE(user_id, url_hash)` + `INDEX(user_id, raw_url_hash)` + `FULLTEXT(title, ai_summary, user_notes)`).
  4. `database/migrations/xxxx_create_tags_tables.php` (Tabel `tags` dan tabel pivot `link_tag`).
  5. `database/migrations/xxxx_create_subscriptions_table.php` (Kolom: `id`, `user_id`, `product_id`, `purchase_token`, `purchase_token_hash`, `order_id`, `status`, `starts_at`, `expires_at`, `last_verified_at`, timestamps).
- [x] **Buat Model Eloquent & Relasinya (`app/Models/`):**
  - `User.php`: Helper methods `isPro(): bool`, `hasAiQuota(): bool`, relasi `collections()`, `links()`, `subscriptions()`.
  - `Collection.php`: Otomatis generate `slug` unik (`Str::slug($name) . '-' . Str::lower(Str::random(6))`) saat *creating*.
  - `Link.php`: Casts untuk boolean dan `remind_at` (`datetime`), relasi `user()`, `collection()`, `tags()`.
  - `Tag.php` & `Subscription.php`.

### 1.4 Autentikasi Google, Onboarding Seeder & Manajemen Koleksi
- [x] **Buat `app/Actions/Auth/SeedDefaultCollectionsAction.php`:**
  - Membuat 5 koleksi bawaan untuk user baru — **semuanya ditandai `is_default = true`** sehingga tidak pernah memakan slot koleksi kustom (batas Free hanya menghitung `is_default = false`):
    1. `Belanja & Wishlist` (`shopping_bag`, `#EC4899`)
    2. `Resep & Kuliner` (`restaurant`, `#F59E0B`)
    3. `Tontonan & Hiburan` (`play_circle`, `#EF4444`)
    4. `Belajar & Referensi` (`school`, `#3B82F6`)
    5. `Tempat & Jalan-jalan` (`place`, `#10B981`)
- [x] **Buat `app/Actions/Auth/AuthenticateGoogleUserAction.php` & `AuthController.php`:**
  - Endpoint `POST /api/v1/auth/google`: Verifikasi `id_token` Google (atau info profil OAuth), buat user baru jika belum ada (`ai_quota_left = 10`), jalankan `SeedDefaultCollectionsAction` jika user baru, simpan `fcm_token`, dan kembalikan Sanctum Bearer Token beserta data user & daftar koleksinya.
  - Endpoint `GET /api/v1/auth/me`: Mengembalikan profil user terbaru + `meta` kuota AI.
  - Endpoint `DELETE /api/v1/auth/account`: Menghapus seluruh token Sanctum dan menghapus baris `user` (memicu `ON DELETE CASCADE` pada seluruh tabel terkait).
- [x] **Buat `app/Http/Controllers/Api/V1/CollectionController.php`:**
  - `GET /api/v1/collections`: Daftar koleksi urut berdasarkan `sort_order` dengan `withCount('links')`.
  - `POST /api/v1/collections`: Cek apakah `!$user->isPro() && $user->collections()->where('is_default', false)->count() >= 3`. Jika ya, lempar `BusinessLogicException('COLLECTION_LIMIT_REACHED', 'Batas pembuatan koleksi kustom untuk akun Gratis (3 koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!', 403)`. Aturan sama berlaku untuk clone koleksi publik (`POST /public/collections/{slug}/clone`).
  - `PATCH /api/v1/collections/{id}`: Jika mengubah `is_public = true`, cek apakah `!$user->isPro()` dan sudah punya 1 koleksi publik lain. Jika ya, lempar `BusinessLogicException('PUBLIC_COLLECTION_LIMIT_REACHED', ..., 403)`.
  - `DELETE /api/v1/collections/{id}`: Hapus koleksi.

> ### ✅ Verification & Definition of Done (Phase 1)
> 1. Jalankan `php artisan migrate:fresh` tanpa error; pastikan indeks `FULLTEXT` dan `uq_links_user_url_hash` terbentuk di MySQL.
> 2. Hit `POST /api/v1/auth/google` untuk user baru -> pastikan otomatis terbuat 5 baris di tabel `collections`.
> 3. Dengan akun `plan_type = 'free'`, coba buat **koleksi kustom ke-4** via `POST /api/v1/collections` -> pastikan API menolak dengan HTTP `403` dan `error_code: "COLLECTION_LIMIT_REACHED"` (5 koleksi bawaan `is_default = true` tidak ikut dihitung).

---

## Phase 2: Multi-Layer Scraper, SSRF Guard & Gemini AI Pipeline (`tautin-backend`)

**Tujuan Fase 2:** Membangun mesin pemroses tautan asinkron yang aman dari serangan SSRF, mampu mengekstrak metadata dari berbagai situs (TikTok, YouTube, Shopee, Artikel), dan merangkumnya menggunakan Gemini 2.5 Flash di latar belakang.

### 2.1 Keamanan SSRF & URL Canonicalizer
- [x] **Buat `app/Services/Scraper/SsrfGuard.php`:**
  - Method `validateAndResolve(string $rawUrl): string`:
    - Pastikan skema hanya `http` atau `https` dan port hanya `80` atau `443`.
    - Resolusi host ke daftar IP menggunakan `gethostbynamel($host)`.
    - Tolak jika IP termasuk dalam range privat/lokal/reserved menggunakan `filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)`.
    - Lakukan `HEAD` / `GET` ringan dengan `max_redirects = 5` (`connect_timeout = 4s`, `timeout = 8s`), validasi ulang IP pada setiap redirect.
    - Bersihkan query parameter pelacak (`utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `fbclid`, `igshid`, `gclid`, `_t`, `_r`).
    - Kembalikan *clean canonical URL*.

### 2.2 Multi-Layer Metadata Scraper (Tier 1, Tier 2, Tier 3)
- [x] **Buat `app/Services/Scraper/OEmbedExtractor.php` (Tier 1):**
  - Deteksi domain `tiktok.com`, `youtube.com`, `youtu.be`, `twitter.com`, `x.com`.
  - Panggil endpoint oEmbed resmi masing-masing platform (`timeout = 5s`).
  - Ekstrak `title`, `author_name`, dan `thumbnail_url`.
- [x] **Buat `app/Services/Scraper/HtmlDomExtractor.php` (Tier 2):**
  - Gunakan HTTP Client dengan header `User-Agent` Android Chrome modern dan `Accept-Language: id-ID,id;q=0.9,en-US;q=0.8`.
  - Pastikan header respons `Content-Type` mengandung `text/html` dan batasi pembacaan *stream* maksimal `1.5 MB`.
  - Gunakan `Symfony\Component\DomCrawler\Crawler` untuk mengekstrak:
    - `og:title` -> fallback ke `twitter:title` -> fallback ke `<title>`.
    - `og:image` -> fallback ke `twitter:image` (ubah URL gambar relatif menjadi absolut).
    - `og:description` -> fallback ke `<meta name="description">`.
    - Bersihkan node `<script>`, `<style>`, `<nav>`, `<header>`, `<footer>`, `<aside>`, lalu ambil teks bersih dari `<article>` atau `<main>` atau `<p>`, dan potong maksimal **3.000 karakter**.
- [x] **Buat `app/Services/Scraper/MultiLayerScraperService.php`:**
  - Menggabungkan Tier 1 (oEmbed) -> Tier 2 (HTML DOM) -> Tier 3 (Fallback ke `raw_description` bawaan Share Sheet & kata kunci dari *URL slug* jika Tier 1 & 2 terkena blokir HTTP 403/429/Captcha).

### 2.3 Integrasi Gemini 2.5 Flash (Structured JSON Output)
- [x] **Buat DTO `app/Services/AI/Data/AiAnalysisResult.php`:**
  - Properti: `cleanTitle`, `summary`, `selectedCollectionName`, `tags` (array), `sourceType`.
- [x] **Buat `app/Services/AI/GeminiOrganizerService.php`:**
  - Panggil REST API `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`.
  - Masukkan daftar nama koleksi milik user (`$user->collections->pluck('name')`) ke dalam *prompt*.
  - Gunakan `responseMimeType: "application/json"` dan `responseSchema` ketat sesuai spesifikasi di `ARCHITECTURE.md`.
  - Tambahkan *try-catch* tangguh: jika Gemini API *timeout* atau error, kembalikan `null` agar proses penyimpanan link tetap selesai menggunakan metadata hasil *scraper*.

### 2.4 Endpoint Quick Save (`< 300ms`) & Background Job Queue
- [x] **Buat `app/Actions/Links/QuickSaveLinkAction.php`:**
  - Bersihkan URL awal dari spasi, ekstrak `domain`, dan hitung `url_hash = hash('sha256', $initialUrl)`.
  - Cek apakah sudah ada baris di tabel `links` dengan `user_id` dan `url_hash` tersebut:
    - **Jika Duplikat Ditemukan:** Update `updated_at = now()`, jangan potong kuota AI, kembalikan respons sukses dengan flag `is_duplicate: true` dan pesan *"Tautan sudah ada di Tautin, dinaikkan ke paling atas!"*
    - **Jika Tautan Baru:** Simpan ke tabel `links` dengan `status = 'pending'`, `raw_description`, dan `collection_id` (jika dipilih manual oleh user).
    - Dispatch `ProcessSharedLinkJob::dispatch($link->id)->onQueue('high')`.
- [x] **Buat `app/Jobs/ProcessSharedLinkJob.php`:**
  1. Ubah `link->status = 'processing'`.
  2. Jalankan `SsrfGuard` untuk mendapatkan *canonical URL* (jika setelah *unshorten* ternyata `url_hash` baru sudah ada di database user tersebut, gabungkan/hapus baris baru dan perbarui baris lama).
  3. Jalankan `MultiLayerScraperService` untuk mendapatkan judul, *thumbnail*, deskripsi, dan teks isi.
  4. Cek eligibilitas AI: `if ($user->isPro() || $user->ai_quota_left > 0)`.
  5. Jika *eligible*, panggil `GeminiOrganizerService`:
     - Simpan `title = $aiResult->cleanTitle`, `ai_summary = $aiResult->summary`, `source_type = $aiResult->sourceType`, `is_ai_processed = true`.
     - Jika user tadi tidak memilih `collection_id` secara manual, cocokkan `$aiResult->selectedCollectionName` dengan koleksi milik user dan isi `collection_id`-nya.
     - Buat/sinkronkan maksimal 3 `tags` ke tabel `tags` dan `link_tag`.
     - Jika `$user->plan_type === 'free'`, kurangi `$user->decrement('ai_quota_left')`.
  6. Jika kuota AI habis (`ai_quota_left == 0`), simpan `title` dan `thumbnail_url` dari hasil *scraper* tanpa `ai_summary`, dan arahkan ke koleksi pertama user.
  7. Ubah `link->status = 'completed'`.

> ### ✅ Verification & Definition of Done (Phase 2)
> 1. Uji `SsrfGuard` dengan URL `http://127.0.0.1:8000` dan `http://192.168.1.1` -> pastikan ditolak secara aman.
> 2. Uji `POST /api/v1/links/quick-save` dengan 3 jenis URL nyata: (a) *Shortlink* video TikTok `vt.tiktok.com/...`, (b) Tautan produk Shopee dengan `raw_description`, dan (c) Artikel berita/blog.
> 3. Pastikan waktu respons HTTP `POST /api/v1/links/quick-save` berada di bawah **300ms**.
> 4. Jalankan `php artisan queue:work --queue=high,default` -> pastikan dalam < 6 detik ketiga link berubah menjadi `status = 'completed'`, memiliki `ai_summary` Bahasa Indonesia yang akurat, masuk ke `collection_id` yang sesuai, memiliki 3 `tags`, dan `ai_quota_left` user gratis berkurang dari `10` menjadi `7`.

---

## Phase 3: Feed, Contextual Search, Reminders & Native Google Play Billing (`tautin-backend`)

**Tujuan Fase 3:** Menyelesaikan seluruh endpoint pencarian kontekstual, fitur pengingat anti-lupa, koleksi publik, serta verifikasi pembayaran langsung ke Google Play Developer API.

### 3.1 Feed, Pencarian Kontekstual (Full-Text) & Resurfacing API
- [x] **Lengkapi `app/Http/Controllers/Api/V1/LinkController.php`:**
  - `GET /api/v1/links`:
    - Urutan default: `ORDER BY is_pinned DESC, updated_at DESC`.
    - Filter opsional: `collection_id`, `source_type`, `is_read`, dan `tag` (via `whereHas('tags', ...)`).
    - Filter pencarian (`?search=kata_kunci`): Gunakan MySQL Full-Text Search `WHERE MATCH(title, ai_summary, user_notes) AGAINST(? IN BOOLEAN MODE)` dikombinasikan dengan fallback `OR domain LIKE ?` atau `whereHas('tags')` agar kata pendek tetap tertangkap dengan cepat.
  - `GET /api/v1/links/resurface`:
    - Mengambil maksimal 3 link milik user dengan kriteria `is_read = false` dan `created_at <= now()->subDays(3)` secara acak (`inRandomOrder()->limit(3)`).
  - `PATCH /api/v1/links/{id}`:
    - Mengizinkan perubahan `collection_id`, `title`, `user_notes`, `is_pinned`, `is_read`, dan `remind_at`.
    - **Proteksi Fitur Pro:** Jika request mengirimkan `remind_at != null` dan `!$user->isPro()`, lempar `BusinessLogicException('PRO_REQUIRED_FOR_REMINDER', ..., 403)`.
  - `DELETE /api/v1/links/{id}`: Hapus link milik user.

### 3.2 Native Google Play Billing Service (`AndroidPublisher`)
- [x] **Buat `app/Services/Billing/GooglePlayBillingService.php`:**
  - Inisialisasi `Google\Client` menggunakan file kredensial Service Account JSON (`storage/app/google-play-service-account.json`) dengan scope `Google\Service\AndroidPublisher::ANDROIDPUBLISHER`.
  - Method `verifyAndAcknowledgeProduct(string $productId, string $purchaseToken)`:
    - Untuk pembelian sekali bayar (`tautin_pro_lifetime`).
    - Panggil `$publisher->purchases_products->get($packageName, $productId, $purchaseToken)`.
    - Validasi `purchaseState === 0` (Purchased).
    - Jika `acknowledgementState === 0`, panggil `$publisher->purchases_products->acknowledge(...)`.
  - Method `verifyAndAcknowledgeSubscription(string $productId, string $purchaseToken)`:
    - Untuk langganan (`tautin_pro_monthly`, `tautin_pro_yearly`).
    - Panggil `$publisher->purchases_subscriptionsv2->get($packageName, $purchaseToken)`.
    - Pastikan `subscriptionState` adalah `'SUBSCRIPTION_STATE_ACTIVE'` atau `'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'`.
    - Ambil waktu kedaluwarsa dari `lineItems[0]->getExpiryTime()`.
    - Jika `acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING'`, lakukan `acknowledge` melalui `$publisher->purchases_subscriptions->acknowledge(...)`.
- [x] **Buat `app/Actions/Billing/VerifyGooglePlayPurchaseAction.php` & `BillingController.php`:**
  - Endpoint `POST /api/v1/billing/verify-purchase`:
    1. Hitung `$tokenHash = hash('sha256', $purchaseToken)`.
    2. Cek di tabel `subscriptions`: jika `$tokenHash` sudah terdaftar milik `user_id` **lain**, tolak dengan `BusinessLogicException('INVALID_PURCHASE_TOKEN', 'Bukti pembelian ini sudah digunakan oleh akun lain.', 422)`.
    3. Panggil `GooglePlayBillingService` sesuai jenis `product_id`.
    4. Simpan/perbarui catatan di tabel `subscriptions` dan update tabel `users` (`plan_type = 'pro'` atau `'lifetime'`, `plan_expires_at = $expiryTime`).
  - Endpoint `POST /api/v1/billing/restore`:
    - Menerima array daftar transaksi dari fungsi *Restore Purchase* Flutter, memverifikasi token yang masih aktif, dan memulihkan status Pro pengguna.

### 3.3 Endpoint Koleksi Publik & Penjadwalan Cron (FCM)
- [x] **Buat `app/Http/Controllers/Api/V1/PublicCollectionController.php`:**
  - `GET /api/v1/public/collections/{slug}`: Ambil koleksi dengan `is_public = true` beserta daftar `links` di dalamnya. **Sangat Penting:** Gunakan `PublicLinkResource` yang menyembunyikan `user_notes` pribadi dan menyembunyikan `email` pemilik koleksi.
  - `POST /api/v1/public/collections/{slug}/clone`: Menyalin koleksi publik beserta link di dalamnya ke akun pengguna yang sedang login.
- [x] **Buat Layanan FCM & 4 Command Scheduler (`app/Console/Commands/`):**
  - `FcmNotificationService.php`: Mengirim push notification via FCM HTTP v1 API.
  - `DispatchLinkRemindersCommand.php` (`everyMinute()`): Kirim FCM untuk link yang `remind_at <= now()` dan `reminder_sent = false`, lalu set `reminder_sent = true`.
  - `SyncExpiredSubscriptionsCommand.php` (`hourly()`): Cek user `pro` yang `plan_expires_at <= now()` ke Google Play API; perpanjang jika user memperbarui langganan, atau kembalikan ke `free` jika sudah kedaluwarsa.
  - `SendWeeklyDigestCommand.php` (`weeklyOn(6, '09:00')`): Kirim notifikasi akhir pekan untuk user yang memiliki >= 3 link belum dibaca.
  - `ResetMonthlyAiQuotaCommand.php` (`monthlyOn(1, '00:01')`): Reset `ai_quota_left = 10` untuk seluruh user `plan_type = 'free'`.

> ### ✅ Verification & Definition of Done (Phase 3)
> 1. Uji pencarian `GET /api/v1/links?search=...` menggunakan kata yang hanya ada di dalam `ai_summary` -> pastikan link terkait muncul di hasil pencarian.
> 2. Uji `GET /api/v1/public/collections/{slug}` -> pastikan JSON yang dikembalikan **tidak** mengandung kolom `user_notes` maupun `email` pemilik.
> 3. Jalankan keempat perintah artisan (`tautin:dispatch-reminders`, `tautin:sync-subscriptions`, `tautin:send-weekly-digest`, `tautin:reset-monthly-quota`) melalui terminal dan pastikan berjalan tanpa error.

---

## Phase 4: Flutter Core, Auth, Offline Cache & "Quick Taut" Share Sheet (`tautin-mobile`)

**Tujuan Fase 4:** Membangun aplikasi Android Flutter dengan identitas `id.my.sengganglabs.tautin`, menerapkan desain visual Tautin, menyimpan cache koleksi di Hive, serta mengaktifkan fitur penyimpanan instan (< 2 detik) dari menu *Share* aplikasi lain.

### 4.1 Inisialisasi Flutter, Konfigurasi Android & Design System
- [x] **Inisialisasi Proyek & Dependensi (`pubspec.yaml`):**
  - Buat proyek Flutter di `tautin-mobile/` dengan org/package `id.my.sengganglabs.tautin`.
  - Tambahkan paket: `flutter_riverpod`, `dio`, `go_router`, `hive_ce`, `hive_ce_flutter`, `receive_sharing_intent`, `google_sign_in`, `in_app_purchase`, `google_fonts`, `cached_network_image`, `url_launcher`, `share_plus`, `shimmer`, `intl` (tanpa Firebase — notifikasi FCM direncanakan di fase selanjutnya).
- [x] **Konfigurasi `android/app/src/main/AndroidManifest.xml`:**
  - Pasang permission `INTERNET`, `com.android.vending.BILLING`, dan `POST_NOTIFICATIONS`.
  - Set `android:launchMode="singleTask"` pada `.MainActivity`.
  - Tambahkan `<intent-filter>` untuk `android.intent.action.SEND` (`mimeType="text/plain"`).
  - Tambahkan `<intent-filter android:autoVerify="true">` untuk *App Links* domain `www.sengganglabs.my.id` dengan `pathPrefix="/tautin/c/"`.
- [x] **Buat Design System (`lib/core/theme/tautin_theme.dart`):**
  - Terapkan palet warna sesuai `PRD.md`: Primary Electric Indigo (`#4F46E5`), AI Accent Soft Violet (`#8B5CF6`), Light Mode (`#F8FAFC` / `#FFFFFF`), Dark Mode (`#0F172A` / `#1E293B`), serta tipografi `Plus Jakarta Sans` & `Inter`.

### 4.2 Penyimpanan Lokal (Hive) & Jaringan (Dio)
- [x] **Buat `lib/core/storage/local_storage_service.dart`:**
  - Inisialisasi 3 Hive Box saat `main()` dimulai:
    1. `authBox`: Menyimpan Sanctum token, profil user, `plan_type`, dan `ai_quota_left`.
    2. `collectionsCacheBox`: Menyimpan daftar koleksi user agar `QuickTautBottomSheet` dapat membukanya dalam `0ms`.
    3. `offlineLinksQueueBox`: Menyimpan antrean link yang di-*share* saat HP tidak memiliki koneksi internet.
- [x] **Buat `lib/core/network/dio_client.dart`:**
  - Pasang interceptor untuk menyisipkan header `Authorization: Bearer {token}` dan menangkap `error_code` (`COLLECTION_LIMIT_REACHED`, `PRO_REQUIRED_FOR_REMINDER`, `PUBLIC_COLLECTION_LIMIT_REACHED`) agar dapat memicu pembukaan `PaywallScreen`.

### 4.3 Layar Onboarding, Login Google & Sinkronisasi Awal
- [x] **Buat `lib/features/auth/presentation/onboarding_login_screen.dart`:**
  - Tampilkan 3 slide singkat cara kerja Tautin (Share -> AI Merangkum -> Anti Lupa).
  - Tombol **"Lanjutkan dengan Google"** yang mengambil `idToken` dari `google_sign_in` dan mengirimkannya ke `POST /api/v1/auth/google`.
  - Setelah login berhasil, simpan daftar 5 koleksi bawaan ke `collectionsCacheBox` dan arahkan ke `HomeScreen`.

### 4.4 Fitur "Quick Taut" — Dirty URL Parser & Share Bottom Sheet
- [x] **Buat `lib/features/share_intent/domain/dirty_url_parser.dart`:**
  - Ekstrak URL pertama menggunakan Regex `r'(https?:\/\/[^\s\)\]\>\"\'`]+)'` sebagai `cleanUrl` dan pisahkan sisa teks promosi (seperti teks Shopee/Tokopedia) sebagai `rawDescription`.
- [x] **Buat `lib/features/share_intent/presentation/quick_taut_bottom_sheet.dart`:**
  - Dengarkan stream & initial media dari `ReceiveSharingIntent.instance`.
  - Begitu menerima teks dari aplikasi lain:
    1. Ekstrak URL melalui `DirtyUrlParser`. Jika tidak ada URL valid, tampilkan *toast* peringatan.
    2. Tampilkan *Bottom Sheet* elegan (tinggi ~32% layar) dan **langsung** panggil `POST /api/v1/links/quick-save` di latar belakang.
    3. Tampilkan daftar koleksi dari `collectionsCacheBox` sebagai *horizontal chips* dengan pilihan aktif default: **"✨ Otomatis oleh AI"**.
    4. Jalankan *progress bar countdown* **2 detik** untuk menutup otomatis (`SystemNavigator.pop()` jika berasal dari *cold start* Share Intent agar pengguna langsung kembali ke TikTok/Shopee).
    5. Jika pengguna menyentuh pilihan koleksi atau tombol *"Tambah Catatan"* sebelum 2 detik habis, batalkan *timer* otomatis dan perbarui pilihan koleksi melalui `PATCH /api/v1/links/{id}`.
    6. Jika gagal karena tidak ada sinyal internet, simpan ke `offlineLinksQueueBox` dan tampilkan status: *"Tersimpan di HP. Akan dirapikan AI saat online."*

> ### ✅ Verification & Definition of Done (Phase 4)
> 1. Buka aplikasi TikTok, Shopee, dan Chrome di HP/Emulator Android -> tekan tombol **Share** -> pilih **Tautin**.
> 2. Pastikan `QuickTautBottomSheet` muncul dengan daftar folder yang langsung terlihat tanpa *loading spinner*, menyimpan link ke server, dan menutup kembali ke aplikasi asal dalam waktu **< 2 detik**.
> 3. Matikan Wi-Fi/Data di HP -> lakukan *Share* link ke Tautin -> pastikan link tersimpan di `offlineLinksQueueBox` dan otomatis terkirim ke server begitu Wi-Fi dinyalakan kembali.

---

## Phase 5: Flutter Smart Feed, Detail Reader, Collections & Native IAP Paywall (`tautin-mobile`)

**Tujuan Fase 5:** Membangun seluruh layar utama aplikasi, pengalaman membaca ringkasan AI, manajemen koleksi publik, dan sistem pembayaran langsung menggunakan paket `in_app_purchase`.

### 5.1 Layar Beranda, Smart Link Card & Pencarian
- [ ] **Buat Widget `lib/shared/widgets/smart_link_card.dart`:**
  - Menampilkan favicon & nama domain, waktu simpan, *badge* pin, gambar *thumbnail* (dengan ikon ▶ untuk `video` atau 🛒 untuk `ecommerce`), judul bersih (maks 2 baris), kotak ungu lembut **`✨ Ringkasan AI`**, label nama Koleksi, dan deretan `#tags`.
  - Bila link tersimpan tanpa ringkasan karena kuota habis (`ai_summary == null`), kotak ringkasan digantikan banner halus bertuliskan **`✨ Kuota ringkasan AI habis — Upgrade ke Pro`** (konstanta `AppConfig.aiQuotaExhaustedBanner`); penyimpanan tetap sukses (prinsip *No Hard-Block*).
  - Jika `status` link masih `'pending'` atau `'processing'`, tampilkan efek *shimmer* halus pada kotak ringkasan AI dan lakukan *polling* ringan setelah 4 detik untuk memperbarui kartu secara otomatis.
- [ ] **Buat `lib/features/home_feed/presentation/home_screen.dart`:**
  - **App Bar:** Logo Tautin + *Chip Indikator Kuota* di kanan atas (`✨ AI: 8/10` untuk Free, atau `👑 PRO` untuk pelanggan Pro/Lifetime).
  - **Clipboard Detector Banner:** Saat aplikasi dibuka (`AppLifecycleState.resumed`), cek `Clipboard.getData('text/plain')`. Jika berisi URL yang belum ada di feed terbaru, tampilkan *banner* kecil untuk menyimpannya dalam 1 klik.
  - **Search Bar:** Pencarian *debounced* (400ms) yang memanggil `GET /api/v1/links?search=...`.
  - **Resurfacing Carousel:** Bagian *"Belum Dibaca Minggu Ini"* — hanya ditampilkan ketika `GET /api/v1/links/resurface` mengembalikan isi; bila kandidat belum dibaca < 3 link, API mengembalikan `[]` dan section ini disembunyikan seluruhnya.
  - **Filter Chips:** Filter cepat berdasarkan Koleksi maupun `source_type` (`Semua`, `🎬 Video`, `🛒 Belanja`, `📄 Artikel`, `👀 Belum Dibaca`, `📦 Tanpa Koleksi` — chip terakhir memanggil `GET /api/v1/links?collection_id=unassigned`).

### 5.2 Layar Detail Tautan & Pengingat Pintar
- [ ] **Buat `lib/features/link_detail/presentation/link_detail_screen.dart`:**
  - Menampilkan gambar *thumbnail* penuh, judul yang dapat diedit, kotak penuh **`✨ Ringkasan AI`**, *dropdown* pemindah Koleksi, daftar `#tags`, dan kolom input **`Catatan Pribadi (user_notes)`** yang otomatis tersimpan.
  - **Tombol Pasang Pengingat (`remind_at`):**
    - Jika `user.planType == 'free'`, menekan tombol ini langsung membuka `PaywallScreen`.
    - Jika `pro` / `lifetime`, tampilkan pilihan waktu cepat (*Nanti Malam 19:00*, *Besok Pagi 08:00*, *Pilih Tanggal & Jam*) dan simpan via `PATCH /api/v1/links/{id}`.
  - **Tombol Utama "Buka Tautan Asli":** Membuka URL menggunakan `url_launcher` (`LaunchMode.externalApplication`) dan menandai `is_read = true`.

### 5.3 Layar Koleksi & Fitur Bagikan ke Publik (Viral Loop)
- [ ] **Buat `lib/features/collections/presentation/collections_screen.dart`:**
  - Menampilkan *Grid* 2 kolom berisi seluruh folder koleksi user + tombol **"+ Buat Koleksi"**.
  - Di dalam halaman isi koleksi, sediakan tombol **"🌐 Bagikan Koleksi"**:
    - Menampilkan *switch toggle* **"Aktifkan Link Publik"**.
    - Saat aktif, tampilkan URL `https://www.sengganglabs.my.id/tautin/c/{slug}` dengan tombol **Salin Link** dan **Bagikan ke WhatsApp/Sosmed** (`share_plus`) serta tombol **"Kustomisasi Slug"** yang memanggil `PATCH /api/v1/collections/{id}` dengan bidang `slug` (`alpha_dash`, 3–100 karakter, unik) — khusus Pro/Lifetime; pengguna gratis mendapat `403 PRO_REQUIRED_FOR_CUSTOM_SLUG` dan diarahkan ke `PaywallScreen`.

### 5.4 Integrasi Native Google Play Billing (`in_app_purchase`) & Paywall Screen
- [ ] **Buat `lib/features/billing/data/native_iap_service.dart`:**
  - Inisialisasi `InAppPurchase.instance` dan muat daftar produk menggunakan `queryProductDetails({'tautin_pro_monthly', 'tautin_pro_yearly', 'tautin_pro_lifetime'})`.
  - Untuk membeli paket Bulanan/Tahunan, panggil `buyNonConsumable(purchaseParam: ...)` (di Google Play Billing Flutter, baik *subscription* maupun *one-time non-consumable* menggunakan `buyNonConsumable`).
  - Dengarkan `InAppPurchase.instance.purchaseStream`:
    - Saat menerima `PurchaseStatus.purchased` atau `PurchaseStatus.restored`:
      1. Kirim `productID` dan `verificationData.serverVerificationData` (`purchase_token`) ke endpoint Laravel `POST /api/v1/billing/verify-purchase`.
      2. Jika Laravel mengembalikan `200 OK`, panggil `InAppPurchase.instance.completePurchase(purchaseDetails)` dan perbarui state user di aplikasi menjadi `pro` / `lifetime`.
- [ ] **Buat `lib/features/billing/presentation/paywall_screen.dart`:**
  - Tampilkan perbandingan manfaat Gratis vs Pro, 3 pilihan paket harga (dengan highlight **"Paling Hemat"** pada paket Tahunan dan **"Early Bird Sekali Bayar"** pada paket Lifetime), tombol beli utama, serta tombol **"Pulihkan Pembelian (Restore Purchase)"**.
- [ ] **Buat `lib/features/settings/presentation/settings_screen.dart`:**
  - Menampilkan profil akun, status langganan, pengatur tema (Terang/Gelap/Sistem), seksi **"Karya Senggang Labs Lainnya"** (kartu *banner* menuju aplikasi **Pilah** di Play Store / `https://www.sengganglabs.my.id/pilah/`), tautan Kebijakan Privasi & Syarat Ketentuan, tombol Logout, dan tombol **Hapus Akun Permanen**.

> ### ✅ Verification & Definition of Done (Phase 5)
> 1. Pastikan seluruh alur navigasi (Beranda, Pencarian, Detail Link, Koleksi, Pengaturan) berjalan mulus pada mode Terang (*Light*) dan Gelap (*Dark*).
> 2. Coba tambahkan **koleksi kustom ke-4** (atau tekan tombol *Pasang Pengingat* dan tombol *Buat Ulang Ringkasan AI*) menggunakan akun Gratis -> pastikan `PaywallScreen` muncul dengan harga asli yang ditarik dari Google Play.
> 3. Uji tombol **"Buka Tautan Asli"** pada kartu TikTok/Shopee -> pastikan langsung membuka aplikasi terkait dan status kartu berubah menjadi sudah dibaca (`is_read = true`).
> 4. Sisi backend: jalankan `tautin:sync-subscriptions` dan simulasikan refund (Voided Purchases / push ke `POST /api/v1/webhooks/google-play-rtdn` dengan secret `GOOGLE_PLAY_RTDN_SECRET`) -> pastikan langganan berubah `refunded`, pengguna turun ke `free`, dan `ai_quota_left = min(kuota saat ini, 10)` (mencakup pembelian `lifetime`).

---

## Phase 6: Next.js Web Ecosystem, Viral Viewer & Legal Pages (`tautin-web`)

**Tujuan Fase 6:** Membangun seluruh halaman web di bawah `https://www.sengganglabs.my.id/tautin/` untuk mendukung fitur berbagi koleksi publik (*Viral Loop*), *Deep Linking*, dan syarat kepatuhan mutlak Google Play Console.

### 6.1 Setup Next.js & Landing Page Produk (`/tautin`)
- [ ] **Konfigurasi Routing `/tautin`:**
  - Siapkan proyek Next.js (atau tambahkan ke dalam repositori web `sengganglabs.my.id` yang sudah ada) untuk melayani path `/tautin`.
- [ ] **Buat Landing Page `src/app/tautin/page.tsx`:**
  - Hero section: **"Tautin — Temukan di mana saja, Tautin di sini."**
  - Penjelasan visual 3 keunggulan utama: *1-Klik Share dari Sosmed/Olshop*, *Ringkasan & Kategori Otomatis AI*, dan *Pengingat Anti-Lupa*.
  - Tabel harga transparan (Gratis, Bulanan Rp29rb, Tahunan Rp249rb, Lifetime Rp349rb).
  - Tombol unduh Google Play Store dan footer resmi **Senggang Labs**.

### 6.2 Halaman SSR Koleksi Publik (`/tautin/c/[slug]`)
- [ ] **Buat `src/app/tautin/c/[slug]/page.tsx`:**
  - Ambil data secara *Server-Side* dari `GET /api/v1/public/collections/{slug}` (ISR revalidate 60 detik).
  - Implementasikan fungsi `generateMetadata()` untuk menghasilkan tag OpenGraph dinamis:
    - `og:title`: `"📂 {collection.name} ({links_count} Tautan) — Koleksi oleh {owner_name} di Tautin"`
    - `og:description`: `"Lihat kumpulan tautan lengkap beserta ringkasan AI instan di Tautin."`
    - `og:image`: Gambar *thumbnail* pertama di dalam koleksi atau *banner* default Tautin.
  - Tampilkan daftar kartu link yang rapi (judul, domain, gambar, ringkasan AI `✨`, dan `#tags`) beserta tombol **"Buka Link"**.
  - Pasang *Sticky Bottom CTA Bar*: **"Simpan & rangkum link otomatis dengan AI — Download Tautin di Google Play"** + tombol **"Buka di Aplikasi Tautin"**.

### 6.3 Halaman Legal Wajib Google Play & Deep Link Assetlinks
- [ ] **Buat 3 Halaman Kepatuhan Google Play Store:**
  1. `src/app/tautin/privacy/page.tsx`: Kebijakan Privasi yang menjelaskan data apa yang disimpan (akun Google, tautan yang dibagikan pengguna, pemrosesan ringkasan melalui Google Gemini API) dan jaminan bahwa koleksi privat tidak dibagikan ke pihak ketiga.
  2. `src/app/tautin/terms/page.tsx`: Syarat & Ketentuan penggunaan layanan, aturan pembaruan langganan Google Play, dan batas pemakaian wajar (*Fair Use Policy*).
  3. `src/app/tautin/delete-account/page.tsx`: Panduan langkah demi langkah menghapus akun dari dalam aplikasi Tautin (`Profil -> Pengaturan -> Hapus Akun Permanen`) beserta formulir/kontak email resmi Senggang Labs untuk permintaan penghapusan data lewat web.
- [ ] **Konfigurasi `https://www.sengganglabs.my.id/.well-known/assetlinks.json`:**
  - Tambahkan entri `id.my.sengganglabs.tautin` beserta *SHA-256 certificate fingerprint* dari Google Play App Signing.

> ### ✅ Verification & Definition of Done (Phase 6)
> 1. Buka keempat URL di browser: `/tautin`, `/tautin/privacy`, `/tautin/terms`, dan `/tautin/delete-account` -> pastikan semuanya mengembalikan status `200 OK` dan responsif di layar HP.
> 2. Buat 1 koleksi publik dari aplikasi, lalu bagikan link `https://www.sengganglabs.my.id/tautin/c/{slug}` ke chat WhatsApp -> pastikan muncul *preview card* (OpenGraph) dengan judul koleksi dan jumlah link yang benar.
> 3. Klik link koleksi tersebut dari HP Android yang sudah menginstal Tautin -> pastikan langsung membuka aplikasi Tautin (*Android App Links* bekerja).

---

## Phase 7: Production Deployment, Play Console Setup & 14-Day Closed Testing

**Tujuan Fase 7:** Menyiapkan server produksi, menghubungkan Google Play Developer API untuk pembayaran nyata, melewati masa uji coba tertutup 14 hari di Play Console, dan merilis Tautin ke publik.

### 7.1 Deployment Server Backend, Worker & Scheduler
- [ ] **Deploy `tautin-backend` ke Server Produksi (`api.tautin.sengganglabs.my.id`):**
  - Konfigurasi SSL (HTTPS), database MySQL 8.0 produksi, dan `.env` produksi.
  - Jalankan *Queue Worker* menggunakan Supervisor atau Docker container (`php artisan queue:work --queue=high,default --tries=2 --timeout=25`).
  - Aktifkan *Cron Job* setiap menit untuk menjalankan `php artisan schedule:run`.

### 7.2 Setup Google Cloud Service Account & Produk Billing di Play Console
- [ ] **Integrasi Google Play Developer API:**
  - Buat *Service Account* di Google Cloud Console, aktifkan **Google Play Android Developer API**, dan unduh file kunci JSON-nya ke server Laravel.
  - Buka **Google Play Console (SenggangLabs) -> Users and permissions**, undang email *Service Account* tersebut, dan berikan izin: *View financial data, orders, and cancellation survey responses* serta *Manage orders and subscriptions*.
- [ ] **Buat Aplikasi & Produk Monetisasi di Google Play Console:**
  - Buat aplikasi **Tautin: Simpan Link & Catatan AI** (`id.my.sengganglabs.tautin`).
  - Di menu **Monetize -> Products**:
    - Buat Subscription `tautin_pro_monthly` (Rp 29.000/bulan) & aktifkan *Base Plan*-nya.
    - Buat Subscription `tautin_pro_yearly` (Rp 249.000/tahun) & aktifkan *Base Plan*-nya.
    - Buat In-app product `tautin_pro_lifetime` (Rp 349.000 sekali beli) & aktifkan.

### 7.3 Pengisian Data Safety, Closed Testing (14 Hari) & Rilis Publik
- [ ] **Lengkapi Administrasi Play Console:**
  - Isi formulir **App Content**: Kebijakan Privasi (`/tautin/privacy`), Penghapusan Akun (`/tautin/delete-account`), *Data Safety*, *Advertising ID* (pilih Tidak jika tidak memakai iklan pihak ketiga), dan *Government Apps* (Tidak).
  - Siapkan aset grafis Store Listing: App Icon `512x512`, Feature Graphic `1024x500`, dan minimal 4–6 *Screenshot* HP yang menonjolkan kemudahan *Share -> Ringkasan AI*.
- [ ] **Rilis ke Closed Testing Track & Pengujian License Tester:**
  - Build *Signed Android App Bundle* (`flutter build appbundle --release`) dan unggah ke **Closed Testing**.
  - Tambahkan email para tester ke daftar **License Testing** di Play Console untuk menguji transaksi pembelian `tautin_pro_monthly`, `tautin_pro_yearly`, dan `tautin_pro_lifetime` menggunakan kartu uji coba (*Test Card* Google Play).
  - Pastikan minimal **12–20 tester** melakukan *opt-in* dan menggunakan aplikasi selama **14 hari berturut-turut** sesuai kebijakan Google Play.
- [ ] **Promosi ke Production:**
  - Setelah lulus masa 14 hari *Closed Testing*, ajukan akses **Production** dan publikasikan Tautin secara resmi di Google Play Store.

> ### ✅ Final Production Readiness Checklist
> - [ ] `POST /api/v1/links/quick-save` merespons < 300ms di server produksi.
> - [ ] Worker antrean dan Scheduler Cron berjalan stabil 24/7 tanpa *memory leak*.
> - [ ] Pembelian menggunakan *License Tester Card* berhasil diverifikasi oleh Laravel (`GooglePlayBillingService`) dan ter-*acknowledge* (tidak ter-*refund* otomatis setelah 3 hari).
> - [ ] Seluruh halaman web di bawah `https://www.sengganglabs.my.id/tautin/` dapat diakses publik dengan cepat.