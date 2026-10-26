# AI Coding Agents Master Instructions: Tautin

| Metadata | Detail Konteks Agent |
| :--- | :--- |
| **Nama Proyek** | **Tautin** ("Temukan di mana saja, Tautin di sini.") |
| **Payung Brand** | **Senggang Labs** (`https://www.sengganglabs.my.id/`) |
| **Android Package ID** | `id.my.sengganglabs.tautin` |
| **Dokumen Referensi Wajib** | 1. `PRD.md` (Aturan Bisnis, Fitur & UI/UX)<br>2. `ARCHITECTURE.md` (Skema DB, Kontrak API & Topologi)<br>3. `IMPLEMENTATION_PLAN.md` (Urutan Fase & Checklist Kerja) |

---

## 1. Aturan Global & Batasan Mutlak (Non-Negotiable Guardrails)

Setiap AI Coding Agent yang bekerja di repositori ini **WAJIB** mematuhi 6 aturan dasar berikut tanpa pengecualian:

1. **Hierarki Kebenaran Dokumen (*Single Source of Truth*):**
   * Jangan pernah mengarang skema tabel, nama endpoint, atau aturan kuota sendiri. Selalu rujuk ke `PRD.md` dan `ARCHITECTURE.md`.
   * Kerjakan fitur secara berurutan mengikuti checklist di `IMPLEMENTATION_PLAN.md`. Setelah menyelesaikan satu sub-tugas dan memverifikasinya, perbarui status `[ ]` menjadi `[x]` di `IMPLEMENTATION_PLAN.md`.

2. **Standar Bahasa (Kode vs Antarmuka):**
   * **Bahasa Inggris (English):** Wajib digunakan untuk seluruh penamaan variabel, fungsi, *class*, nama file, tabel/kolom database, *route* API, *enum* teknis, dan komentar kode.
   * **Bahasa Indonesia (Natural & Ramah):** Wajib digunakan untuk seluruh teks antarmuka pengguna (UI Flutter & Next.js), pesan *toast/snackbar*, pesan validasi/error API (`message`), *push notification*, serta *output* ringkasan dari Gemini AI.

3. **DILARANG Menggunakan RevenueCat (100% Native Google Play Billing):**
   * Proyek ini **tidak menggunakan** RevenueCat atau layanan perantara *billing* pihak ketiga mana pun.
   * Di Flutter: Gunakan paket resmi `in_app_purchase` dan `in_app_purchase_android`.
   * Di Laravel: Gunakan paket resmi `google/apiclient` (`Google\Service\AndroidPublisher`) untuk verifikasi *receipt* secara *server-to-server* langsung ke Google Play Developer API.

4. **Jaminan Kecepatan Simpan `< 300ms` (Asynchronous by Default):**
   * Endpoint `POST /api/v1/links/quick-save` **DILARANG KERAS** menjalankan *HTTP scraping* atau memanggil Gemini API secara sinkron di dalam siklus *HTTP Request*.
   * Controller/Action hanya boleh melakukan validasi cepat, normalisasi URL via `SsrfGuard::normalizeUrlWithoutNetwork()`, pengecekan duplikat ganda via `url_hash` **ATAU** `raw_url_hash`, menyimpan status `'pending'`, men-*dispatch* `ProcessSharedLinkJob` ke antrean (`queue: 'high'`), lalu langsung mengembalikan HTTP `201 Created`.

5. **Prinsip "Zero Failed Saves" & Pembagian Kuota yang Benar:**
   * Yang memakan `ai_quota_left` **HANYA pembuatan Ringkasan AI (`ai_summary`)**. Menyimpan link, membersihkan judul, memilihkan folder (auto-folder), dan membuat tags (auto-tag) **gratis & tanpa batas** untuk semua paket.
   * Jika situs target (seperti Shopee, Tokopedia, atau Instagram) memblokir *scraper* (`HTTP 403/429/Captcha`), **jangan gagalkan penyimpanan link**. Gunakan teks bawaan `raw_description` dari *Share Intent* dan kata kunci pada *URL path* untuk dianalisis oleh AI.
   * Jika kuota ringkasan AI habis (`ai_quota_left == 0`), **jangan blokir pengguna dari menyimpan link**. `ProcessSharedLinkJob` tetap menjalankan *scraper*, lalu memilihkan koleksi dengan **pencocokan kata kunci sederhana** (kata pada judul/domain tautan vs nama koleksi pengguna, *fallback* koleksi default pertama — tanpa memanggil Gemini), dan mengatur `ai_summary = null`, `is_ai_processed = false`, `status = 'completed'`.
   * Di UI Flutter (`SmartLinkCard` dan *Quick Taut Bottom Sheet*), bila `ai_summary == null` pada link `completed`, tampilkan banner halus dengan teks baku: **"✨ Kuota ringkasan AI habis — Upgrade ke Pro"** (`AppConfig.aiQuotaExhaustedBanner`).

6. **Kerahasiaan Data pada Koleksi Publik:**
   * Endpoint publik (`GET /api/v1/public/collections/{slug}`) dan halaman web Next.js (`/tautin/c/[slug]`) **DILARANG** mengekspos alamat `email` pemilik koleksi maupun isi kolom catatan pribadi (`user_notes`).

---

## 2. Instruksi Spesifik Backend Agent (`tautin-backend` — Laravel 11+)

### 2.1 Pola Arsitektur Kode
Terapkan pemisahan tanggung jawab yang ketat:
* **Controllers (`app/Http/Controllers/Api/V1/`):** Hanya menerima *FormRequest*, memanggil satu *Action class*, dan mengembalikan respons melalui `ApiResponseTrait`. Jangan menulis query Eloquent kompleks atau logika bisnis di dalam Controller.
* **Actions (`app/Actions/`):** Menangani satu skenario bisnis utuh (contoh: `QuickSaveLinkAction`, `VerifyGooglePlayPurchaseAction`).
* **Services (`app/Services/`):** Menangani komunikasi eksternal dan algoritma teknis (`SsrfGuard`, `MultiLayerScraperService`, `GeminiOrganizerService`, `GooglePlayBillingService`, `FcmNotificationService`).
* **Jobs (`app/Jobs/`):** Menjalankan tugas latar belakang secara *idempotent* dengan konfigurasi `$tries = 2` dan `$timeout = 25`.

### 2.2 Kontrak Standar Respons JSON & Kode Error
Seluruh respons API wajib menggunakan format amplop JSON berikut:

**Respons Sukses (`200 OK` / `201 Created`):**
```json
{
  "success": true,
  "message": "Tautan berhasil disimpan.",
  "data": { ... },
  "meta": {
    "ai_quota_left": 9,
    "plan_type": "free"
  }
}
```

**Respons Error Bisnis (`400`, `401`, `403`, `422`, `429`):**
Gunakan `BusinessLogicException` untuk melempar `error_code` spesifik berikut agar aplikasi Flutter dapat memicu layar Paywall secara akurat:
* `COLLECTION_LIMIT_REACHED` (HTTP `403`): User `free` mencoba membuat **koleksi kustom ke-4** (`POST /collections` maupun clone koleksi publik). Pesan baku: *"Batas pembuatan koleksi kustom untuk akun Gratis (3 koleksi tambahan) telah tercapai. Upgrade ke Tautin Pro untuk membuat koleksi tanpa batas!"*
* `PUBLIC_COLLECTION_LIMIT_REACHED` (HTTP `403`): User `free` mencoba mengaktifkan koleksi publik ke-2.
* `PRO_REQUIRED_FOR_REMINDER` (HTTP `403`): User `free` mencoba mengisi kolom `remind_at`.
* `PRO_REQUIRED_FOR_REGENERATE` (HTTP `403`): User `free` memanggil `POST /links/{id}/regenerate-ai` (fitur buat ulang ringkasan AI khusus Pro/Lifetime).
* `PRO_REQUIRED_FOR_CUSTOM_SLUG` (HTTP `403`): User `free` mengirim bidang `slug` pada `PATCH /collections/{id}`.
* `AI_QUOTA_EXCEEDED` (HTTP `403`): Kuota ringkasan AI pengguna (`ai_quota_left == 0`) habis saat regenerasi AI manual.
* `COLLECTION_SLUG_TAKEN` (HTTP `422`): Slug kustom koleksi publik sudah dipakai koleksi lain.
* `UNAUTHORIZED_WEBHOOK` (HTTP `401`): Secret RTDN salah/kosong pada `POST /webhooks/google-play-rtdn`.
* `INVALID_PURCHASE_TOKEN` (HTTP `422`): Token Google Play tidak valid atau sudah diklaim oleh `user_id` lain.

**Catatan kuota (wajib konsisten):** kuota `free` direset 10 setiap tanggal 1 pukul **00:01** (`monthlyOn(1, '00:01')`), `pro/fair-use` = 500. Ketika kuota habis, penyimpanan link tetap diperbolehkan (lihat Aturan Global #5) — kuota hanya memengaruhi `ai_summary`.

### 2.3 Aturan Keamanan SSRF & Scraper (`app/Services/Scraper/`)
Saat membangun `SsrfGuard` dan `MultiLayerScraperService`:
1. **Validasi IP Sebelum Request:**
   ```php
   $ips = gethostbynamel($host);
   foreach ($ips as $ip) {
       if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
           throw new UnsafeUrlException("Akses ke jaringan internal ditolak.");
       }
   }
   ```
2. **Batas Redirect & Ukuran File:**
   * Maksimal `5` redirects (`connect_timeout: 4s`, `timeout: 8s`). Validasi ulang IP pada setiap redirect.
   * Hanya proses body jika header `Content-Type` mengandung `text/html` atau `application/json` (untuk oEmbed). Batasi pembacaan body maksimal `1.5 MB`.
3. **Urutan Ekstraksi 3-Tier:**
   * **Tier 1 (oEmbed):** Cek domain `tiktok.com`, `youtube.com`, `youtu.be`, `twitter.com`, `x.com`. Panggil endpoint oEmbed resmi terlebih dahulu.
   * **Tier 2 (OpenGraph & DOM):** Gunakan `Symfony\Component\DomCrawler\Crawler`. Ambil `og:title`, `og:image`, `og:description`, dan teks bersih dari `<article>` / `<main>` / `<p>` (potong maksimal **3.000 karakter**).
   * **Tier 3 (Fallback):** Jika Tier 1 & 2 gagal atau terkena blokir anti-bot, gunakan `raw_description` dan kata kunci dari path URL.

### 2.4 Aturan Integrasi Gemini AI (`GeminiOrganizerService.php`)
* Gunakan model **`gemini-2.5-flash`** melalui endpoint REST v1beta `generateContent`.
* Set `temperature: 0.2`, `maxOutputTokens: 400`, dan `responseMimeType: "application/json"`.
* **Wajib menyertakan `responseSchema`** di dalam payload request agar Gemini selalu mengembalikan struktur JSON berikut:
  ```json
  {
    "clean_title": "String (maks 100 karakter, tanpa kata spam promosi)",
    "summary": "String (1-2 kalimat Bahasa Indonesia. Sebutkan bahan utama untuk resep, nama/fungsi barang untuk e-commerce, atau intisari untuk artikel)",
    "selected_collection_name": "String (harus sama persis dengan salah satu nama koleksi user)",
    "tags": ["tag-1", "tag-2", "tag-3"],
    "source_type": "video | ecommerce | article | social | other"
  }
  ```

### 2.5 Aturan Verifikasi Native Google Play Billing (`GooglePlayBillingService.php`)
* Package Name: `id.my.sengganglabs.tautin`.
* Daftar Produk Valid:
  * `tautin_pro_monthly` (Subscription)
  * `tautin_pro_yearly` (Subscription)
  * `tautin_pro_lifetime` (In-App Product / One-time purchase)
* **Anti-Replay Attack:** Simpan `purchase_token_hash = hash('sha256', $purchaseToken)` sebagai kolom `UNIQUE` di tabel `subscriptions`. Tolak transaksi jika hash tersebut sudah terdaftar milik `user_id` yang berbeda.
* **Wajib Acknowledge:** Setelah memverifikasi bahwa status pembelian valid di Google Play Developer API (`AndroidPublisher`), backend **wajib** memanggil fungsi `acknowledge()` jika status acknowledgement masih *pending*, guna mencegah *auto-refund* 3 hari dari Google Play.
* **Pencabutan Refund (Voided Purchases):** `GooglePlayBillingService::getVoidedPurchaseTokens()` mengunduh daftar `purchaseToken` yang di-*refund* dari `purchases_voidedpurchases->listVoidedpurchases()`. Komando `tautin:sync-subscriptions` (per jam) mencocokkannya dengan tabel `subscriptions` — mencakup langganan `pro` **maupun** pembelian `lifetime` (`plan_expires_at = NULL`) — lalu: `subscriptions.status = 'refunded'`, pengguna turun `plan_type = 'free'` (`plan_expires_at = NULL`), dan `ai_quota_left = min(kuota saat ini, 10)` (tanpa pernah menaikkan kuota). Proses ini **idempoten** untuk baris yang sudah `refunded`.
* **Webhook Real-Time (`POST /api/v1/webhooks/google-play-rtdn`):** Endpoint di dalam prefix `/api/v1` namun **di luar middleware Sanctum**, dilindungi *secret* `config('tautin.google_play.rtdn_secret')` dari env `GOOGLE_PLAY_RTDN_SECRET` (dikirim lewat query `?secret=...` atau header `X-RTDN-Secret`; salah/kosong → `401 UNAUTHORIZED_WEBHOOK`). Payload Pub/Sub berisi `message.data` berupa **base64 JSON**: tipe `subscriptionNotification` 1 (RECOVERED) / 2 (RENEWED) memverifikasi ulang & mengembalikan status Pro; tipe 3 (CANCELED) / 12 (REVOKED) / 13 (EXPIRED) serta `voidedPurchaseNotification` mencabut langganan terkait (refund). Endpoint selalu menjawab `202` agar Pub/Sub tidak mengulang push tanpa henti.

---

## 3. Instruksi Spesifik Mobile Agent (`tautin-mobile` — Flutter)

### 3.1 Arsitektur Folder & State Management
* Gunakan pendekatan **Feature-First Architecture** di dalam `lib/features/` (`auth`, `share_intent`, `home_feed`, `collections`, `link_detail`, `billing`, `settings`).
* Gunakan **`flutter_riverpod`** (`AsyncNotifier` / `Notifier`) untuk seluruh manajemen state. Hindari penggunaan `setState` untuk logika bisnis atau pemanggilan API.
* Gunakan **`hive_ce`** untuk penyimpanan lokal instan:
  * `collectionsCacheBox`: Menyimpan daftar koleksi user secara lokal agar `QuickTautBottomSheet` dapat langsung menampilkan pilihan folder dalam **0 milidetik** tanpa menunggu *loading* jaringan.
  * `offlineLinksQueueBox`: Menyimpan antrean link yang dibagikan saat HP sedang tidak memiliki koneksi internet.

### 3.2 Aturan "Quick Taut" & Pembersihan URL Kotor (`share_intent`)
1. **Dirty URL Regex Parser:**
   Saat menerima teks dari `ReceiveSharingIntent`, jangan pernah mengirim seluruh teks mentah sebagai `url` karena aplikasi seperti Shopee/Tokopedia menyisipkan kalimat promosi di depannya.
   * Pisahkan URL pertama menggunakan Regex: `r'(https?:\/\/[^\s\)\]\>\"\'`]+)'` -> masukkan ke field `url`.
   * Sisa teks selain URL tersebut dimasukkan ke field `raw_description`.
2. **UX `QuickTautBottomSheet` (< 2 Detik):**
   * Tinggi sheet baku = **32% tinggi layar** (`maxHeight * 0.32`) dengan isi dibungkus `SingleChildScrollView` agar tidak *overflow* di layar kecil (banner kuota + *note editor* tetap terjangkau).
   * Begitu *Bottom Sheet* terbuka, langsung panggil `POST /api/v1/links/quick-save` secara otomatis.
   * Tampilkan *progress countdown* selama **2 detik (`quickTautCountdown = Duration(seconds: 2)` / 2000ms)**. Jika pengguna tidak menyentuh layar dalam 2 detik, tutup aplikasi/sheet secara otomatis (`SystemNavigator.pop()`) agar pengguna langsung kembali ke aplikasi sebelumnya (TikTok/Shopee/IG).
   * Jika pengguna menyentuh pilihan koleksi atau tombol *"Tambah Catatan"*, batalkan *auto-close timer* dan kirim pembaruan melalui `PATCH /api/v1/links/{id}`.
   * Bila link tersimpan dengan `aiSummary == null` (kuota ringkasan AI habis), tampilkan banner upsell `AppConfig.aiQuotaExhaustedBanner` di dalam sheet tanpa menghentikan alur simpan.

### 3.3 Sistem Desain & Komponen Visual (`tautin_theme.dart`)
* **Warna Utama:** Electric Indigo (`#4F46E5`).
* **Warna Aksen AI:** Soft Violet (`#8B5CF6`) — selalu pasangkan dengan ikon kilau `✨`.
* **Light Mode:** Background `#F8FAFC`, Card `#FFFFFF`, Text Primary `#0F172A`, Text Secondary `#64748B`, AI Summary Box `#F5F3FF` (Border `#DDD6FE`).
* **Dark Mode:** Background `#0F172A`, Card `#1E293B`, Text Primary `#F8FAFC`, Text Secondary `#94A3B8`, AI Summary Box `#1E1B4B` (Border `#4C1D95`).
* **Font:** `Plus Jakarta Sans` untuk judul/heading, dan `Inter` untuk teks isi/ringkasan.
* **State pada `SmartLinkCard`:**
  * Jika `status == 'pending' || status == 'processing'`: Tampilkan animasi *shimmer* ungu lembut dengan teks *"✨ AI sedang merangkum tautan ini..."*
  * Jika `status == 'completed' && aiSummary != null`: Tampilkan kotak ungu `✨` berisi ringkasan AI (maksimal 2–3 baris di beranda, penuh di layar detail).
  * Jika `status == 'completed' && aiSummary == null` (karena kuota ringkasan AI habis saat link disimpan): Tampilkan banner halus di dalam kartu bertuliskan persis: *"✨ Kuota ringkasan AI habis — Upgrade ke Pro"* (gunakan konstanta `AppConfig.aiQuotaExhaustedBanner`, jangan teks literal).
* Tombol **"Buat Ulang Ringkasan AI"** pada layar detail memanggil `POST /api/v1/links/{id}/regenerate-ai`: pengguna `free` menerima `403 PRO_REQUIRED_FOR_REGENERATE` → tampilkan `PaywallScreen`; kuota habis menerima `403 AI_QUOTA_EXCEEDED`; sukses mengubah status link kembali `pending` (_job di-*dispatch* ke antrean `high`).

### 3.4 Aturan Implementasi Native `in_app_purchase` (`billing`)
* Dengarkan stream `InAppPurchase.instance.purchaseStream` sejak aplikasi dijalankan (di dalam provider global).
* Saat menerima status `PurchaseStatus.purchased` atau `PurchaseStatus.restored`:
  1. Ambil `productID` dan `purchaseDetails.verificationData.serverVerificationData` (ini adalah `purchase_token` Google Play).
  2. Kirim ke backend Laravel `POST /api/v1/billing/verify-purchase`.
  3. **HANYA JIKA** backend mengembalikan respons sukses (`200 OK`), panggil `InAppPurchase.instance.completePurchase(purchaseDetails)` dan segarkan profil user (`GET /api/v1/auth/me`).

---

## 4. Instruksi Spesifik Web Agent (`tautin-web` — Next.js App Router)

### 4.1 Struktur Routing di Bawah `sengganglabs.my.id/tautin`
Seluruh rute web Tautin harus berada di bawah *basePath* `/tautin`:
1. `/tautin` (`src/app/tautin/page.tsx`): Landing page utama produk Tautin.
2. `/tautin/c/[slug]` (`src/app/tautin/c/[slug]/page.tsx`): Halaman **Server-Side Rendered (SSR / ISR 60s)** untuk menampilkan koleksi publik yang dibagikan pengguna.
3. `/tautin/privacy` (`src/app/tautin/privacy/page.tsx`): Halaman Kebijakan Privasi resmi (Wajib untuk Google Play Console).
4. `/tautin/terms` (`src/app/tautin/terms/page.tsx`): Halaman Syarat & Ketentuan layanan dan langganan.
5. `/tautin/delete-account` (`src/app/tautin/delete-account/page.tsx`): Halaman instruksi & formulir penghapusan akun beserta data pengguna (Wajib untuk bagian *Data Safety* Google Play Console).

### 4.2 Optimasi Viral Loop & OpenGraph pada `/tautin/c/[slug]`
* Gunakan fungsi `generateMetadata()` di Next.js untuk menghasilkan meta tag OpenGraph dinamis dari API `GET /api/v1/public/collections/{slug}`:
  * `title`: `"📂 {collection.name} ({links_count} Tautan) — Dikurasi oleh {owner_name} di Tautin (Dirapikan oleh AI)"` (contoh: *"📂 Belanja & Wishlist (23 Tautan) — Dikurasi oleh Rani di Tautin (Dirapikan oleh AI)"*).
  * `description`: `"Kumpulan tautan pilihan oleh {owner_name} lengkap dengan ringkasan AI instan di Tautin."`
  * `openGraph.images`: Gunakan `thumbnail_url` pertama yang valid dari daftar link di dalam koleksi tersebut.
* Pasang *Sticky Bottom Banner* di layar web koleksi publik yang mengajak pengunjung mengunduh **Tautin** di Google Play Store atau membuka koleksi tersebut langsung di dalam aplikasi Tautin (via Android App Links).

### 4.3 Integrasi Ekosistem Senggang Labs
* Pada footer halaman web `/tautin` dan di dalam halaman Pengaturan aplikasi mobile Flutter, selalu sertakan identitas penerbit **"Bagian dari Ekosistem Senggang Labs (`https://www.sengganglabs.my.id/`)"** serta kartu lintas-promosi (*cross-promotion*) menuju aplikasi **Pilah** (`https://www.sengganglabs.my.id/pilah/`).

---

## 5. Protokol Eksekusi & Verifikasi Mandiri untuk AI Agent

Setiap kali kamu (AI Agent) diminta mengerjakan sebuah tugas atau fase:
1. **Baca Konteks Terlebih Dahulu:** Periksa fase aktif di `IMPLEMENTATION_PLAN.md` dan spesifikasi terkait di `ARCHITECTURE.md`.
2. **Tulis Kode Lengkap & Bersih:** Jangan meninggalkan *placeholder* kosong seperti `// TODO: implement later` pada logika inti (seperti `SsrfGuard`, `DirtyUrlParser`, atau `GooglePlayBillingService`).
3. **Verifikasi Mandiri:**
   * Di Laravel: Jalankan pemeriksaan sintaks (`php -l`), migrasi, atau *feature test* untuk memastikan endpoint mengembalikan struktur JSON yang sesuai kontrak.
   * Di Flutter: Jalankan `flutter analyze` untuk memastikan tidak ada *compile error*, *unused imports*, atau pelanggaran *null-safety*.
   * Di Next.js: Pastikan *build* SSR (`next build` / *typecheck*) berjalan tanpa error.
4. **Update Progress:** Setelah fitur terverifikasi berjalan baik, tandai checkbox `[x]` pada item terkait di `IMPLEMENTATION_PLAN.md`.