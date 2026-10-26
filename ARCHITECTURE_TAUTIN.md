# System Architecture Document: Tautin

| Metadata Dokumen | Detail Spesifikasi Teknis |
| :--- | :--- |
| **Nama Sistem** | **Tautin Ecosystem** (`tautin-backend`, `tautin-mobile`, `tautin-web`) |
| **Payung Infrastruktur** | **Senggang Labs** (`https://www.sengganglabs.my.id/`) |
| **Android Application ID** | `id.my.sengganglabs.tautin` |
| **Pola Arsitektur** | Modular Service-Oriented Backend + Asynchronous Queue Pipeline + Feature-First Mobile |
| **Tech Stack Utama** | Flutter 3.24+ (Mobile), Laravel 11+ (API & Worker), MySQL 8.0+ (DB), Next.js 14+ (Web SSR) |
| **Infrastruktur Billing** | Native Google Play Billing (`in_app_purchase` + Google Play Developer API `AndroidPublisher`) |
| **AI Engine** | Google Gemini API (`gemini-2.5-flash` via REST Structured JSON Output) |
| **Versi Dokumen** | v1.0 — Full Engineering Specification |

---

## 1. Topologi Sistem Tingkat Tinggi (High-Level System Topology)

Sistem dirancang menggunakan pendekatan **Non-Blocking Ingestion**: proses penerimaan tautan dari HP pengguna dipisahkan sepenuhnya dari proses berat (*web scraping* dan analisis AI) menggunakan antrean latar belakang (*Background Queue Worker*).

```text
                                   ┌────────────────────────────────────────┐
                                   │       External Content Platforms       │
                                   │ (TikTok, Shopee, Tokopedia, IG, Blogs) │
                                   └───────────┬───────────────────┬────────┘
                  (1) Share Intent (Dirty Text)│                   │ (4) HTTP Scrape / oEmbed
                                               ▼                   ▲
┌────────────────────────────────────┐      ┌──────────────────────┴────────┐
│    Flutter Android App (Tautin)    │      │     Laravel Queue Worker      │
│     id.my.sengganglabs.tautin      │      │   (ProcessSharedLinkJob)      │
│  - Native Share Bottom Sheet       │      │  - SsrfGuard & Unshortener    │
│  - Hive Local Cache & Offline Sync │      │  - MultiLayerScraperService   │
│  - Native `in_app_purchase` SDK    │      └──────────┬───────────┬────────┘
└─────────────────┬──────────────────┘                 │           │
                  │ (2) REST API (JSON / Sanctum)      │           ▼ (5) Metadata + User Folders
                  ▼                                    │    ┌─────────────────────────┐
┌────────────────────────────────────┐                 │    │    Google Gemini API    │
│        Laravel 11+ REST API        │                 │    │   (gemini-2.5-flash)    │
│   api.tautin.sengganglabs.my.id    │◄────────────────┘    └─────────────────────────┘
│  - Thin Controllers & Actions      │ (6) Persist AI Result & Send Silent FCM
│  - Rate Limiter & Auth Sanctum     │
│  - GooglePlayBillingService        │◄─── Verify Receipt ──► ┌─────────────────────────┐
└─────────────────┬──────────────────┘                        │  Google Play Developer  │
                  │ (3) Read/Write + Full-Text Search         │  API (AndroidPublisher) │
                  ▼                                           └─────────────────────────┘
┌────────────────────────────────────┐
│         MySQL 8.0 Database         │◄─── (7) Public SSR ─── ┌─────────────────────────┐
│  - InnoDB (`utf8mb4_unicode_ci`)   │                        │    Next.js Web Viewer   │
│  - Composite & FULLTEXT Indexes    │                        │  sengganglabs.my.id/    │
└────────────────────────────────────┘                        │  tautin/c/[slug]        │
                                                              └─────────────────────────┘
```

---

## 2. Struktur Repositori & Direktori (Monorepo Blueprint)

Seluruh kode sumber diorganisir ke dalam 3 layanan terpisah di bawah satu repositori utama agar mudah dikelola oleh pengembang tunggal maupun AI Coding Agent:

```text
tautin/
├── docs/
│   ├── PRD.md                                  # Dokumen Kebutuhan Produk
│   ├── ARCHITECTURE.md                         # Dokumen Arsitektur Sistem (File ini)
│   ├── IMPLEMENTATION_PLAN.md                  # Peta Jalan Eksekusi Bertahap
│   └── AGENTS.md                               # Instruksi Spesifik AI Coding Agent
│
├── tautin-backend/                             # Layanan Backend API & Worker (Laravel 11+)
│   ├── app/
│   │   ├── Actions/
│   │   │   ├── Auth/
│   │   │   │   ├── AuthenticateGoogleUserAction.php
│   │   │   │   ├── SeedDefaultCollectionsAction.php
│   │   │   │   └── DeleteUserAccountAction.php
│   │   │   ├── Links/
│   │   │   │   ├── QuickSaveLinkAction.php       # Normalisasi URL + dedup dual-hash (url_hash / raw_url_hash)
│   │   │   │   ├── RegenerateAiAction.php        # Regenerasi ringkasan AI (khusus Pro; dispatch queue 'high')
│   │   │   │   └── UpdateLinkAction.php
│   │   │   └── Billing/
│   │   │       └── VerifyGooglePlayPurchaseAction.php
│   │   ├── Console/Commands/
│   │   │   ├── ResetMonthlyAiQuotaCommand.php  # Jalan setiap tanggal 1 (00:01 WIB)
│   │   │   ├── DispatchLinkRemindersCommand.php# Jalan setiap menit
│   │   │   ├── SendWeeklyDigestCommand.php     # Jalan setiap Sabtu (09:00 WIB)
│   │   │   └── SyncExpiredSubscriptionsCommand.php # Jalan setiap jam (+ sapuan Voided Purchases)
│   │   ├── Exceptions/
│   │   │   └── BusinessLogicException.php      # Exception standar dengan error_code
│   │   ├── Http/
│   │   │   ├── Controllers/Api/V1/
│   │   │   │   ├── AuthController.php
│   │   │   │   ├── LinkController.php
│   │   │   │   ├── CollectionController.php
│   │   │   │   ├── BillingController.php
│   │   │   │   ├── PublicCollectionController.php
│   │   │   │   └── GooglePlayRtdnController.php  # Webhook RTDN Google Play (Pub/Sub)
│   │   │   ├── Requests/Api/V1/
│   │   │   └── Resources/Api/V1/
│   │   ├── Jobs/
│   │   │   ├── ProcessSharedLinkJob.php        # Pipeline utama Scraping + Gemini AI
│   │   │   └── SendFcmPushNotificationJob.php
│   │   ├── Models/
│   │   │   ├── User.php
│   │   │   ├── Collection.php
│   │   │   ├── Link.php
│   │   │   ├── Tag.php
│   │   │   └── Subscription.php
│   │   └── Services/
│   │       ├── Scraper/
│   │       │   ├── SsrfGuard.php               # Proteksi IP lokal & Unshortener URL
│   │       │   ├── OEmbedExtractor.php         # Tier 1: YouTube, TikTok, X oEmbed
│   │       │   ├── HtmlDomExtractor.php        # Tier 2: OpenGraph & Article Text
│   │       │   └── MultiLayerScraperService.php# Orchestrator Scraper Tier 1-3
│   │       ├── AI/
│   │       │   ├── GeminiOrganizerService.php  # Integrasi Gemini 2.5 Flash JSON
│   │       │   └── Data/AiAnalysisResult.php   # DTO hasil analisis AI
│   │       ├── Billing/
│   │       │   └── GooglePlayBillingService.php# Verifikasi ke AndroidPublisher API
│   │       └── Notification/
│   │           └── FcmNotificationService.php  # Firebase Cloud Messaging HTTP v1
│   ├── config/
│   │   └── tautin.php                          # Konfigurasi kuota, limit, & produk ID
│   ├── database/migrations/
│   └── routes/api.php
│
├── tautin-mobile/                              # Aplikasi Android (Flutter)
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml    # Konfigurasi Share Intent & App Links
│   └── lib/
│       ├── main.dart
│       ├── core/
│       │   ├── config/                         # Env constants & API base URL
│       │   ├── network/                        # Dio client, Auth & Error Interceptors
│       │   ├── storage/                        # Hive boxes (Collections cache, Offline queue)
│       │   ├── router/                         # GoRouter configuration
│       │   └── theme/                          # TautinTheme (Light/Dark, Typography)
│       ├── shared/
│       │   ├── models/                         # LinkModel, CollectionModel, UserModel
│       │   └── widgets/                        # SmartLinkCard, AiSummaryBox, ProBadge
│       └── features/
│           ├── auth/                           # Google Sign-In & Onboarding Slides
│           ├── share_intent/                   # DirtyUrlParser & QuickTautBottomSheet
│           ├── home_feed/                      # HomeScreen, ResurfacingCarousel, Search
│           ├── collections/                    # CollectionGridScreen, PublicShareSheet
│           ├── link_detail/                    # LinkDetailScreen, NoteEditor, ReminderPicker
│           ├── billing/                        # NativeIapService & PaywallScreen
│           └── settings/                       # Profile, Senggang Labs Cross-Promo, Delete Account
│
└── tautin-web/                                 # Web Viewer & Legal Pages (Next.js App Router)
    ├── public/.well-known/
    │   └── assetlinks.json                     # Verifikasi Deep Link Android
    └── src/app/tautin/
        ├── page.tsx                            # Landing Page Utama Tautin
        ├── c/[slug]/page.tsx                   # SSR Public Collection Viewer (Viral Loop)
        ├── privacy/page.tsx                    # Kebijakan Privasi (Wajib Play Store)
        ├── terms/page.tsx                      # Syarat & Ketentuan Layanan
        └── delete-account/page.tsx             # Formulir/Instruksi Hapus Akun
```

---

## 3. Arsitektur Database & Skema Relasional (MySQL 8.0+)

Seluruh tabel menggunakan engine `InnoDB` dan *collation* `utf8mb4_unicode_ci` untuk mendukung karakter emoji pada judul/catatan media sosial serta fitur `FULLTEXT` *indexing*.

### 3.1 Diagram Relasi Entitas (ERD)
```text
[users] 1 ─────── * [collections]
   │                      │
   │ 1                    │ 0..1
   ├───────── * [links] * ┘
   │               *
   │ 1             │
   ├─── * [tags] * ┘ (via pivot [link_tag])
   │
   └─── * [subscriptions] (Riwayat & Token Google Play Billing)
```

### 3.2 Spesifikasi DDL Lengkap (SQL Schema)

```sql
-- =========================================================================
-- 1. TABEL USERS
-- Menyimpan profil pengguna, status paket Micro SaaS, dan sisa kuota AI.
-- =========================================================================
CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    google_id VARCHAR(100) NULL,
    avatar VARCHAR(500) NULL,
    plan_type ENUM('free', 'pro', 'lifetime') NOT NULL DEFAULT 'free',
    plan_expires_at TIMESTAMP NULL,
    ai_quota_left INT UNSIGNED NOT NULL DEFAULT 10,
    fcm_token VARCHAR(255) NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_google_id (google_id),
    INDEX idx_users_plan_expiry (plan_type, plan_expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================================
-- 2. TABEL COLLECTIONS (FOLDER KATEGORI)
-- Menyimpan folder pengelompokan link dan pengaturan berbagi ke publik.
-- =========================================================================
CREATE TABLE collections (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50) NOT NULL DEFAULT 'folder',
    color VARCHAR(20) NOT NULL DEFAULT '#4F46E5',
    slug VARCHAR(120) NOT NULL UNIQUE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    is_default BOOLEAN NOT NULL DEFAULT FALSE, -- 5 koleksi bawaan signup ditandai is_default = TRUE; batas Free (3) hanya menghitung is_default = FALSE
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_collections_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_collections_user_sort (user_id, sort_order ASC),
    INDEX idx_collections_public_slug (slug, is_public)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================================
-- 3. TABEL LINKS (TABEL INTI)
-- Menyimpan URL, metadata hasil scrape, ringkasan AI, dan jadwal pengingat.
-- =========================================================================
CREATE TABLE links (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    collection_id BIGINT UNSIGNED NULL,
    url TEXT NOT NULL,
    url_hash CHAR(64) NOT NULL, -- SHA-256 dari canonical URL (ditulis ulang setelah unshorten)
    raw_url_hash CHAR(64) NULL, -- SHA-256 dari URL persis saat pertama di-share (biasanya shortlink); TIDAK PERNAH ditulis ulang oleh unshorten
    domain VARCHAR(100) NOT NULL,
    source_type ENUM('video', 'ecommerce', 'article', 'social', 'other') NOT NULL DEFAULT 'other',
    title VARCHAR(255) NULL,
    thumbnail_url TEXT NULL,
    raw_description TEXT NULL,  -- Teks kotor bawaan Share Intent (cadangan konteks AI)
    ai_summary TEXT NULL,
    user_notes TEXT NULL,
    status ENUM('pending', 'processing', 'completed', 'failed') NOT NULL DEFAULT 'pending',
    is_ai_processed BOOLEAN NOT NULL DEFAULT FALSE,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    remind_at TIMESTAMP NULL,
    reminder_sent BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_links_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_links_collection FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE SET NULL,
    
    -- Mencegah duplikasi URL kanonik yang sama pada satu akun pengguna
    UNIQUE KEY uq_links_user_url_hash (user_id, url_hash),

    -- Index deteksi duplikat instan via shortlink (raw_url_hash)
    INDEX idx_links_user_raw_hash (user_id, raw_url_hash),

    -- Index untuk query Feed utama (Pinned di atas, lalu urutan terbaru)
    INDEX idx_links_user_feed (user_id, is_pinned DESC, updated_at DESC),
    
    -- Index untuk filter per koleksi & tipe sumber
    INDEX idx_links_user_collection (user_id, collection_id, updated_at DESC),
    INDEX idx_links_user_source (user_id, source_type, updated_at DESC),
    
    -- Index untuk fitur Resurfacing ("Belum Dibaca Minggu Ini")
    INDEX idx_links_resurface (user_id, is_read, created_at),
    
    -- Index untuk Cron Scheduler Pengingat Menitan
    INDEX idx_links_pending_reminders (reminder_sent, remind_at),
    
    -- Full-Text Search Index untuk pencarian kontekstual
    FULLTEXT KEY ft_links_search (title, ai_summary, user_notes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================================
-- 4. TABEL TAGS & LINK_TAG (MANY-TO-MANY)
-- =========================================================================
CREATE TABLE tags (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(50) NOT NULL, -- Disimpan dalam format lowercase slug (misal: 'resep-ayam')
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tags_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY uq_tags_user_name (user_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE link_tag (
    link_id BIGINT UNSIGNED NOT NULL,
    tag_id BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (link_id, tag_id),
    CONSTRAINT fk_link_tag_link FOREIGN KEY (link_id) REFERENCES links(id) ON DELETE CASCADE,
    CONSTRAINT fk_link_tag_tag FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =========================================================================
-- 5. TABEL SUBSCRIPTIONS (NATIVE GOOGLE PLAY BILLING)
-- Menyimpan struk & token pembelian asli dari Google Play untuk verifikasi.
-- =========================================================================
CREATE TABLE subscriptions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    product_id VARCHAR(100) NOT NULL, -- 'tautin_pro_monthly', 'tautin_pro_yearly', 'tautin_pro_lifetime'
    purchase_token TEXT NOT NULL,
    purchase_token_hash CHAR(64) NOT NULL UNIQUE, -- SHA-256(purchase_token) cegah klaim ganda
    order_id VARCHAR(100) NULL,       -- Format: GPA.xxxx-xxxx-xxxx-xxxxx
    status ENUM('active', 'canceled', 'expired', 'refunded') NOT NULL DEFAULT 'active',
    starts_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NULL,        -- NULL jika produk adalah 'tautin_pro_lifetime'
    last_verified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_subscriptions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_subscriptions_user_status (user_id, status),
    INDEX idx_subscriptions_expiry_check (status, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 4. Arsitektur Backend, Scraper & Gemini AI (`tautin-backend`)

### 4.1 Desain Keamanan SSRF & Kanonikalisasi URL (`SsrfGuard.php`)
Karena pengguna dapat mengirimkan URL apa saja, *scraper* rentan terhadap serangan **SSRF (Server-Side Request Forgery)** di mana penyerang mengirimkan URL seperti `http://127.0.0.1:3306` atau `http://169.254.169.254/latest/meta-data/`.

**Aturan Wajib `SsrfGuard`:**
1. **Validasi Skema & Port:** Hanya izinkan skema `http` dan `https` pada port standar (`80` dan `443`).
2. **Resolusi DNS & Pemblokiran IP Privat:** Sebelum melakukan request HTTP (dan pada setiap *hop redirect*), panggil `gethostbynamel($host)` lalu validasi setiap IP menggunakan `filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)`. Jika gagal, batalkan proses *scraping*.
3. **Normalisasi Instan Tanpa Jaringan — `SsrfGuard::normalizeUrlWithoutNetwork(string $url): string` (statis, < 1ms):**
   * Dipakai `QuickSaveLinkAction` **sebelum** menyimpan link agar deteksi duplikat konsisten.
   * Memangkas seluruh spasi/whitespace di sekeliling URL, menurunkan huruf host ke *lowercase*, membuang parameter *tracking* (`utm_*`, `fbclid`, `igshid`, `gclid`, `_t`, `_r`), dan membuang `#fragment`.
   * URL yang tidak memiliki skema/host valid melempar `UnsafeUrlException('Format URL tidak valid untuk normalisasi.')`.
   * Baris baru menyimpan `url` bernilai URL ternormalisasi ini serta `url_hash = raw_url_hash = hash('sha256', $normalizedUrl)`.
4. **Unshortening & Pembersihan Parameter Pelacak:**
   * Ikuti maksimal **5 kali HTTP Redirect** (`connect_timeout: 4s`, `timeout: 8s`) untuk mengurai *shortlink* seperti `vt.tiktok.com/...`, `id.shp.ee/...`, atau `bit.ly/...`.
   * Buang parameter *tracking* dari query string: `utm_source`, `utm_medium`, `utm_campaign`, `utm_term`, `utm_content`, `fbclid`, `igshid`, `gclid`, `_t`, `_r`.
   * Setelah redirect selesai, `ProcessSharedLinkJob` **menulis ulang `url` dan `url_hash` ke canonical URL** (`url_hash = hash('sha256', $cleanCanonicalUrl)`) tetapi **tidak pernah mengubah `raw_url_hash`** — jejak hash shortlink awal dipertahankan agar share ulang shortlink yang sama tetap terdeteksi duplikat secara instan.

### 4.2 Pipeline Multi-Layer Metadata Scraper (`MultiLayerScraperService.php`)
Agar berhasil mengekstrak informasi dari berbagai platform yang sering memblokir bot:

* **Tier 1: Official oEmbed Endpoints (Prioritas Utama untuk Video/Sosmed)**
  Jika domain cocok dengan daftar di bawah ini, panggil endpoint JSON oEmbed resmi mereka terlebih dahulu:
  * **TikTok:** `https://www.tiktok.com/oembed?url={encoded_url}` -> Menghasilkan `title` (caption lengkap video), `author_name`, dan `thumbnail_url`.
  * **YouTube / Shorts:** `https://www.youtube.com/oembed?url={encoded_url}&format=json` -> Menghasilkan `title`, `author_name`, dan `thumbnail_url`.
  * **X / Twitter:** `https://publish.twitter.com/oembed?url={encoded_url}` -> Menghasilkan `author_name` dan isi teks cuitan di dalam properti `html`.
* **Tier 2: OpenGraph & HTML Reader Mode (Untuk Artikel, Resep, & Web Umum)**
  * Gunakan header menyerupai browser mobile:
    `User-Agent: Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36`
  * Batasi ukuran unduhan respons maksimal **1.5 MB** (tolak file biner/video/PDF besar dengan memeriksa header `Content-Type: text/html`).
  * Ekstrak tag `<meta property="og:title">`, `<meta property="og:image">`, `<meta property="og:description">`, dan `<title>`.
  * Hapus tag `<script>`, `<style>`, `<nav>`, `<footer>`, lalu ekstrak teks bersih dari dalam `<article>` atau `<main>` dan potong maksimal **3.000 karakter pertama** untuk menghemat pemakaian token AI.
* **Tier 3: Dirty Share Text & URL Slug Fallback (Anti-Blokir Shopee/Tokopedia/IG)**
  * Platform e-commerce seperti Shopee/Tokopedia sering memblokir IP server cloud (`HTTP 403` atau melempar ke halaman login).
  * Jika Tier 1 dan Tier 2 gagal mendapatkan judul yang valid, sistem mengambil **`raw_description`** (teks bawaan saat pengguna menekan tombol *Share* di HP) serta membaca kata-kata pada *path* URL (misal: `tokopedia.com/toko/sepatu-lari-pria-ukuran-42` -> `"sepatu lari pria ukuran 42"`) untuk diserahkan ke Gemini AI.

### 4.3 Arsitektur Integrasi Gemini AI (`GeminiOrganizerService.php`)

* **Endpoint (Tanpa API Key di URL):** `POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
* **Keamanan API Key (Wajib!):** API key **TIDAK PERNAH** melewati query string (`?key=...` dilarang karena bocor ke log URL & *exception trace*). Kirimkan selalu lewat HTTP Header: `x-goog-api-key: {GEMINI_API_KEY}`.
* **Payload Konfigurasi:**
  ```json
  {
    "systemInstruction": {
      "parts": [
        {
          "text": "Kamu adalah mesin pengorganisir tautan pintar untuk aplikasi Tautin. Analisis data URL berikut dan kembalikan JSON yang valid. Aturan: 1. clean_title: Bersihkan judul dari kata spam promosi (maks 100 karakter). 2. summary: Ringkasan padat 1-2 kalimat dalam Bahasa Indonesia. Jika resep, sebutkan bahan utama. Jika produk belanja, sebutkan jenis barang & harga/keunggulan. Jika artikel/edukasi, sebutkan intisarinya. 3. selected_collection_name: Pilih tepat satu nama koleksi yang paling cocok dari daftar koleksi milik user. 4. tags: Maksimal 3 tag huruf kecil dengan tanda hubung (contoh: ['resep-ayam', 'menu-harian']). 5. source_type: Pilih satu dari 'video', 'ecommerce', 'article', 'social', 'other'."
        }
      ]
    },
    "contents": [
      {
        "role": "user",
        "parts": [
          {
            "text": "URL: {url}\nDomain: {domain}\nScraped Title: {scraped_title}\nRaw Share Text: {raw_description}\nBody Excerpt: {body_text}\nDaftar Koleksi User: [{user_collection_names}]"
          }
        ]
      }
    ],
    "generationConfig": {
      "temperature": 0.2,
      "maxOutputTokens": 400,
      "responseMimeType": "application/json",
      "responseSchema": {
        "type": "OBJECT",
        "properties": {
          "clean_title": { "type": "STRING" },
          "summary": { "type": "STRING" },
          "selected_collection_name": { "type": "STRING" },
          "tags": {
            "type": "ARRAY",
            "items": { "type": "STRING" }
          },
          "source_type": {
            "type": "STRING",
            "enum": ["video", "ecommerce", "article", "social", "other"]
          }
        },
        "required": ["clean_title", "summary", "selected_collection_name", "tags", "source_type"]
      }
    }
  }
  ```

---

## 5. Arsitektur Native Google Play Billing (`GooglePlayBillingService.php`)

Tanpa menggunakan RevenueCat, verifikasi transaksi dilakukan secara *Server-to-Server* antara Laravel dan Google Play Developer API v3 menggunakan package resmi `google/apiclient`.

### 5.1 Alur Verifikasi Pembelian Baru (`POST /api/v1/billing/verify-purchase`)
```text
[Flutter App] ──(1) Request Purchase──► [Google Play Store App]
      │                                           │
      │◄─(2) Return PurchaseDetails (Token & ID)──┘
      │
      ├──(3) POST /api/v1/billing/verify-purchase (product_id, purchase_token)
      ▼
[Laravel: VerifyGooglePlayPurchaseAction]
      │
      ├──(4) Cek `purchase_token_hash` di tabel `subscriptions`
      │      (Tolak jika token sudah pernah diklaim oleh user_id lain!)
      │
      ├──(5) Panggil Google\Service\AndroidPublisher:
      │      • Jika `tautin_pro_lifetime`:
      │        `purchases_products->get('id.my.sengganglabs.tautin', $productId, $token)`
      │        Cek `purchaseState === 0`. Panggil `purchases_products->acknowledge(...)`.
      │      • Jika `tautin_pro_monthly` / `tautin_pro_yearly`:
      │        `purchases_subscriptionsv2->get('id.my.sengganglabs.tautin', $token)`
      │        Cek `subscriptionState === 'SUBSCRIPTION_STATE_ACTIVE'`.
      │        Ambil `lineItems[0]->expiryTime`. Panggil `purchases_subscriptions->acknowledge(...)`.
      │
      └──(6) Database Transaction:
             • Simpan/Update baris di tabel `subscriptions`.
             • Update `users`: `plan_type = 'pro' | 'lifetime'`, `plan_expires_at = $expiryTime`.
             • Kembalikan respons JSON 200 ke Flutter -> Flutter panggil `InAppPurchase.completePurchase()`.
```

> **Penting (Aturan 3 Hari Google Play):** Setiap pembelian di Google Play **wajib di-*acknowledge*** dalam waktu maksimal 3 hari. Jika tidak, Google Play akan melakukan *refund* otomatis. Karena itu, fungsi `acknowledge()` langsung dipanggil oleh backend Laravel saat memverifikasi token, ditambah pemanggilan `completePurchase()` di sisi Flutter.

### 5.2 Sinkronisasi Perpanjangan, Kedaluwarsa & Refund (`SyncExpiredSubscriptionsCommand.php`)
Berjalan setiap **1 jam** melalui Laravel Scheduler:
1. Ambil seluruh pengguna dengan `plan_type = 'pro'` dan `plan_expires_at <= NOW()`.
2. Ambil `purchase_token` aktif terakhir milik pengguna tersebut dari tabel `subscriptions`.
3. Panggil `purchases_subscriptionsv2->get('id.my.sengganglabs.tautin', $token)`:
   * **Jika diperpanjang otomatis oleh pengguna (`expiryTime` di Google > `NOW()`):** Perbarui `users.plan_expires_at` dan `subscriptions.expires_at` ke tanggal baru.
   * **Jika dibatalkan/kedaluwarsa (`SUBSCRIPTION_STATE_EXPIRED`):** Ubah `subscriptions.status = 'expired'`, turunkan `users.plan_type = 'free'`, dan set `users.ai_quota_left = 10`.
4. **Sapuan Voided Purchases (`getVoidedPurchaseTokens()`):**
   * Panggil `purchases_voidedpurchases->listVoidedpurchases($packageName)` lalu bandingkan daftar `purchaseToken` hasil *refund* dengan tabel `subscriptions` — mencakup langganan `pro` **maupun** pembelian `lifetime` (`plan_expires_at = NULL` tidak pernah terjaring pemeriksaan tanggal).
   * Untuk setiap kecocokan belum diproses: `subscriptions.status = 'refunded'`, pengguna diturunkan `plan_type = 'free'`, `plan_expires_at = NULL`, dan `ai_quota_left = min(kuota saat ini, 10)` (tanpa kenaikan kuota).
   * Proses ini **idempoten**: baris yang sudah `refunded` dilewati; kegagalan jaringan Google hanya melewati sapuan (fallback aman).

### 5.3 Webhook Real-Time Developer Notifications (`POST /api/v1/webhooks/google-play-rtdn`)
* **Autentikasi:** *secret* bersama dari `config('tautin.google_play.rtdn_secret')` (`GOOGLE_PLAY_RTDN_SECRET`), dikirim Google Cloud Pub/Sub lewat query `?secret=...` atau header `X-RTDN-Secret`. Salah/kosong -> `401 UNAUTHORIZED_WEBHOOK`.
* **Payload:** push Pub/Sub berisi `message.data` berupa **base64 JSON**; handler meng-*decode* lalu memproses:
  * `subscriptionNotification.subscriptionNotificationType` **1 (RECOVERED) / 2 (RENEWED)** -> verifikasi ulang langganan (`verifyAndAcknowledgeSubscription`), set `status = 'active'`, pemilik kembali `pro` dengan kuota 500.
  * Tipe **3 (CANCELED) / 12 (REVOKED) / 13 (EXPIRED)** serta `voidedPurchaseNotification` -> jalur refund: `subscriptions.status = 'refunded'`, pengguna turun ke `free`, kuota `min(kuota saat ini, 10)`.
  * `testNotification` hanya dicatat ke log.
* **Acknowledge:** endpoint selalu menjawab `202` (bentuk sinyal Pub/Sub) untuk payload kosong/tidak terbaca agar push tidak diulang tanpa henti; stamping status pengguna dijalankan idempoten.

---

## 6. Arsitektur Aplikasi Mobile Flutter (`tautin-mobile`)

### 6.1 Konfigurasi `AndroidManifest.xml` (Share Intent & App Links)
Agar pengalaman menyimpan tautan terasa instan dan tidak menumpuk *instance* aplikasi ganda:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="id.my.sengganglabs.tautin">

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="com.android.vending.BILLING"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

    <application
        android:label="Tautin"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:theme="@style/LaunchTheme"
            android:windowSoftInputMode="adjustResize">

            <!-- 1. Main Launcher Intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <!-- 2. Native Share Sheet Receiver ("Quick Taut") -->
            <intent-filter android:label="Tautin">
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>

            <!-- 3. Android App Links untuk Koleksi Publik Senggang Labs -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https"
                      android:host="www.sengganglabs.my.id"
                      android:pathPrefix="/tautin/c/" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 6.2 Logika Pembersih Teks Kotor (`DirtyUrlParser.dart`)
```dart
class ParsedShareInput {
  final String cleanUrl;
  final String? rawDescription;

  ParsedShareInput({required this.cleanUrl, this.rawDescription});
}

class DirtyUrlParser {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s\)\]\>\"\'`]+)',
    caseSensitive: false,
  );

  static ParsedShareInput? parse(String sharedText) {
    final match = _urlRegex.firstMatch(sharedText.trim());
    if (match == null) return null;

    final extractedUrl = match.group(0)!;
    final remainingText = sharedText
        .replaceAll(extractedUrl, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return ParsedShareInput(
      cleanUrl: extractedUrl,
      rawDescription: remainingText.isNotEmpty ? remainingText : null,
    );
  }
}
```

### 6.3 Manajemen State & Offline Queue (Riverpod + Hive)
* **`collectionsCacheBox` (Hive):** Menyimpan daftar koleksi pengguna secara lokal. Saat `QuickTautBottomSheet` muncul, daftar pilihan folder langsung dirender dalam **0 milidetik** dari Hive tanpa menunggu pemanggilan API.
* **`offlineLinksQueueBox` (Hive):** Jika `POST /api/v1/links/quick-save` gagal karena `DioExceptionType.connectionError` (HP sedang tidak ada sinyal), payload disimpan ke box ini. Saat koneksi kembali menyala, `OfflineSyncService` otomatis mengirimkan seluruh antrean ke server.

---

## 7. Arsitektur Web & Ekosistem `sengganglabs.my.id/tautin`

### 7.1 Konfigurasi Next.js Sub-Path (`next.config.mjs`)
Agar terintegrasi mulus di bawah domain `https://www.sengganglabs.my.id/tautin/`:
* Gunakan `basePath: '/tautin'` pada konfigurasi Next.js.
* Halaman `/tautin/c/[slug]/page.tsx` memanggil endpoint publik `GET /api/v1/public/collections/{slug}` menggunakan `fetch(..., { next: { revalidate: 60 } })` (ISR / SSR Cache 60 detik agar server database tetap ringan meskipun link koleksi sedang viral di grup WhatsApp).

### 7.2 Spesifikasi `/.well-known/assetlinks.json`
File ini diletakkan pada root domain `https://www.sengganglabs.my.id/.well-known/assetlinks.json` (jika sudah ada untuk aplikasi **Pilah**, tambahkan elemen objek ke-2 di dalam array JSON-nya):

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "id.my.sengganglabs.tautin",
      "sha256_cert_fingerprints": [
        "ISI_DENGAN_SHA256_DARI_GOOGLE_PLAY_CONSOLE_APP_SIGNING"
      ]
    }
  }
]
```

---

## 8. Spesifikasi Kontrak REST API (`api/v1`)

Seluruh request (kecuali `/public/*`, `/auth/google`, dan `/webhooks/google-play-rtdn` yang memakai *secret* RTDN) wajib menyertakan header:
* `Accept: application/json`
* `Authorization: Bearer {sanctum_token}`

### 8.1 Daftar Lengkap Endpoint & Payload

| Method & Endpoint | Deskripsi | Request Body / Query Params |
| :--- | :--- | :--- |
| `POST /api/v1/auth/google` | Login/Register dengan Google ID Token & buat 5 koleksi bawaan. | `{ "id_token": "...", "fcm_token": "..." }` |
| `GET /api/v1/auth/me` | Ambil profil terbaru, status Pro, & sisa kuota AI. | - |
| `DELETE /api/v1/auth/account` | Hapus akun & seluruh data pengguna secara permanen. | `{ "confirmation": "HAPUS" }` |
| `POST /api/v1/links/quick-save` | Simpan link cepat dari Share Sheet (`< 300ms`). URL dinormalisasi (`SsrfGuard::normalizeUrlWithoutNetwork`), duplikat dicek via `url_hash` **atau** `raw_url_hash`. | `{ "url": "...", "raw_description": "...", "collection_id": null, "user_notes": null }` |
| `GET /api/v1/links` | Ambil daftar link (Pagination + Filter + Search). `collection_id=unassigned` -> link tanpa koleksi (`whereNull('collection_id')`). | `?page=1&collection_id=2|unassigned&source_type=video&tag=resep&is_read=0&search=ayam` |
| `GET /api/v1/links/resurface` | Ambil 3 link acak belum dibaca (> 3 hari); mengembalikan `[]` bila kandidat < 3. | - |
| `POST /api/v1/links/{id}/regenerate-ai` | Buat ulang ringkasan AI/folder/tags sebuah link (Khusus Pro/Lifetime; status kembali `pending` + dispatch `ProcessSharedLinkJob` ke antrean `high`). | - |
| `GET /api/v1/links/{id}` | Ambil detail 1 link (untuk polling status AI / layar detail). | - |
| `PATCH /api/v1/links/{id}` | Update koleksi, judul, catatan, pin, status baca, atau pengingat. | `{ "collection_id": 3, "title": "...", "user_notes": "...", "is_pinned": true, "is_read": true, "remind_at": "2026-10-30 19:00:00" }` |
| `DELETE /api/v1/links/{id}` | Hapus 1 link. | - |
| `GET /api/v1/collections` | Ambil semua koleksi pengguna beserta jumlah link (`links_count`). | - |
| `POST /api/v1/collections` | Buat koleksi kustom baru (Free: maks **3** koleksi kustom; 5 koleksi bawaan `is_default = true` tidak dihitung). | `{ "name": "Skripsi", "icon": "book", "color": "#3B82F6", "is_public": false }` |
| `PATCH /api/v1/collections/{id}` | Edit nama, warna, ikon, atau status publik koleksi. Bidang opsional `slug` (Khusus Pro: `alpha_dash`, 3–100, unik) mengubah URL publik. | `{ "name": "...", "is_public": true, "slug": "skripsi-2026" }` |
| `DELETE /api/v1/collections/{id}` | Hapus koleksi (link di dalamnya menjadi `collection_id = null`). | - |
| `POST /api/v1/billing/verify-purchase` | Verifikasi struk Google Play & aktifkan paket Pro/Lifetime. | `{ "product_id": "tautin_pro_yearly", "purchase_token": "...", "order_id": "GPA..." }` |
| `POST /api/v1/billing/restore` | Sinkronisasi ulang daftar token pembelian saat ganti HP. | `{ "purchases": [{ "product_id": "...", "purchase_token": "..." }] }` |
| `GET /api/v1/public/collections/{slug}` | Ambil data koleksi publik untuk Next.js SSR (Tanpa Auth). OG title: `📂 {collection.name} ({links_count} Tautan) — Dikurasi oleh {owner_name} di Tautin (Dirapikan oleh AI)`. | - |
| `POST /api/v1/public/collections/{slug}/clone` | Simpan seluruh link dari koleksi publik orang lain ke akun sendiri (Free tetap terikat batas 3 koleksi kustom). | - |
| `POST /api/v1/webhooks/google-play-rtdn` | Webhook Pub/Sub Google Play RTDN (Tanpa Auth Sanctum; dilindungi *secret*). Menangani `subscriptionNotification` (tipe 1/2 pemulihan & pembaharuan; tipe 3/12/13 pencabutan) serta `voidedPurchaseNotification` (refund). | Payload Pub/Sub: `{ "message": { "data": "<base64 JSON>" } }` + `?secret=...` atau header `X-RTDN-Secret` |

### 8.2 Standar Kode Error Bisnis (`error_code`)
Agar aplikasi Flutter tahu kapan harus memunculkan **Layar Paywall Tautin Pro**:

| HTTP Status | `error_code` | Kondisi Pemicu | Aksi di Aplikasi Flutter |
| :--- | :--- | :--- | :--- |
| `403 Forbidden` | `COLLECTION_LIMIT_REACHED` | User `free` mencoba membuat koleksi kustom ke-4 (`POST /collections` atau clone koleksi publik). | Buka `PaywallScreen` dengan pesan: *"Upgrade ke Pro untuk membuat koleksi tanpa batas."* |
| `403 Forbidden` | `PRO_REQUIRED_FOR_REMINDER` | User `free` mencoba mengisi `remind_at`. | Buka `PaywallScreen` dengan pesan: *"Pengingat jadwal kustom adalah fitur Tautin Pro."* |
| `403 Forbidden` | `PRO_REQUIRED_FOR_REGENERATE` | User `free` memanggil `POST /links/{id}/regenerate-ai`. | Buka `PaywallScreen` dengan pesan: *"Fitur buat ulang ringkasan AI khusus untuk pengguna Tautin Pro."* |
| `403 Forbidden` | `PRO_REQUIRED_FOR_CUSTOM_SLUG` | User `free` mengirim bidang `slug` pada `PATCH /collections/{id}`. | Buka `PaywallScreen` dengan pesan: *"Fitur kustomisasi tautan publik khusus untuk pengguna Tautin Pro."* |
| `403 Forbidden` | `PUBLIC_COLLECTION_LIMIT_REACHED` | User `free` mengaktifkan koleksi publik ke-2. | Buka `PaywallScreen` dengan pesan: *"Bagikan koleksi tanpa batas dengan Tautin Pro."* |
| `403 Forbidden` | `AI_QUOTA_EXCEEDED` | Kuota ringkasan AI (`ai_quota_left == 0`) habis saat regenerasi AI manual. | Buka `PaywallScreen` dengan pesan: *"Kuota ringkasan AI bulanan Anda telah habis."* |
| `422 Unprocessable` | `INVALID_PURCHASE_TOKEN` | Token Google Play tidak valid / sudah dipakai akun lain. | Tampilkan pesan gagal verifikasi pembayaran. |
| `422 Unprocessable` | `VALIDATION_ERROR` | Error validasi FormRequest (termasuk `DELETE /auth/account` tanpa `{"confirmation": "HAPUS"}` dan `slug` yang gagal `alpha_dash`/unik). | Tampilkan pesan per-field dari `errors`. |
| `422 Unprocessable` | `COLLECTION_SLUG_TAKEN` | Slug kustom sudah dipakai koleksi lain. | Tampilkan pesan: *"Slug sudah dipakai koleksi lain. Pilih slug lain."* |
| `401 Unauthorized` | `UNAUTHORIZED_WEBHOOK` | Secret RTDN salah/kosong pada `POST /webhooks/google-play-rtdn`. | (Internal — tidak relevan di aplikasi; push Pub/Sub akan di-retry oleh Google). |
| `429 Too Many Requests` | `RATE_LIMIT_EXCEEDED` | Mengirim > 30 request simpan link per menit. | Tampilkan *toast* peringatan batas kecepatan. |

---

## 9. Infrastruktur Antrean & Penjadwalan (Queue & Cron Jobs)

Untuk memastikan seluruh fitur otomatis berjalan tepat waktu di server produksi:

1. **Queue Worker (`Supervisor` / Docker Worker Container):**
   * Menjalankan perintah:
     `php artisan queue:work database --queue=high,default --tries=2 --backoff=5 --timeout=25`
   * Antrean `high` digunakan untuk `ProcessSharedLinkJob` agar pengguna yang baru menyimpan link langsung melihat ringkasan AI dalam hitungan detik.
2. **Laravel Task Scheduler (`routes/console.php`):**
   * `Schedule::command('tautin:dispatch-reminders')->everyMinute();`
     *(Mencari link dengan `remind_at <= NOW()` dan `reminder_sent = false`, mengirim FCM Push Notification, lalu mengubah `reminder_sent = true`).*
   * `Schedule::command('tautin:sync-subscriptions')->hourly();`
     *(Mengecek masa berlaku langganan yang jatuh tempo ke Google Play Developer API dan menyapu Voided Purchases untuk mencabut langganan/beli-langsung `lifetime` yang di-refund — `subscriptions.status = 'refunded'`, pengguna turun ke `free`, kuota `min(kuota saat ini, 10)`).*
   * `Schedule::command('tautin:send-weekly-digest')->weeklyOn(6, '09:00');`
     *(Setiap hari Sabtu jam 09:00 WIB, mengirim rekap pengingat untuk pengguna yang memiliki >= 3 link belum dibaca).*
   * `Schedule::command('tautin:reset-monthly-quota')->monthlyOn(1, '00:01');`
     *(Setiap tanggal 1 pukul 00:01 WIB, mereset `ai_quota_left = 10` untuk seluruh pengguna `free`).*