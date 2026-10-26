<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('links', function (Blueprint $table): void {
            // SHA-256 of the URL exactly as it was first quick-saved (usually a
            // shortlink such as vt.tiktok.com/xyz). Keeps duplicate detection
            // instant even after ProcessSharedLinkJob rewrites `url` +
            // `url_hash` to the unshortened canonical URL.
            $table->char('raw_url_hash', 64)->nullable()->after('url_hash');

            $table->index(['user_id', 'raw_url_hash'], 'idx_links_user_raw_hash');
        });

        // Backfill: for rows created before this column existed, the stored
        // `url_hash` already hashed the first-saved (raw) URL.
        DB::table('links')
            ->whereNull('raw_url_hash')
            ->update(['raw_url_hash' => DB::raw('url_hash')]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('links', function (Blueprint $table): void {
            $table->dropIndex('idx_links_user_raw_hash');
            $table->dropColumn('raw_url_hash');
        });
    }
};
