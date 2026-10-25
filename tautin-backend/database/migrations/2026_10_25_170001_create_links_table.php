<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('links', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('collection_id')->nullable()->constrained('collections')->nullOnDelete();
            $table->text('url');
            $table->char('url_hash', 64);
            $table->string('domain', 100);
            $table->enum('source_type', ['video', 'ecommerce', 'article', 'social', 'other'])->default('other');
            $table->string('title', 255)->nullable();
            $table->text('thumbnail_url')->nullable();
            $table->text('raw_description')->nullable();
            $table->text('ai_summary')->nullable();
            $table->text('user_notes')->nullable();
            $table->enum('status', ['pending', 'processing', 'completed', 'failed'])->default('pending');
            $table->boolean('is_ai_processed')->default(false);
            $table->boolean('is_pinned')->default(false);
            $table->boolean('is_read')->default(false);
            $table->timestamp('remind_at')->nullable();
            $table->boolean('reminder_sent')->default(false);
            $table->timestamps();

            $table->unique(['user_id', 'url_hash'], 'uq_links_user_url_hash');
            $table->index(['user_id', 'is_pinned', 'updated_at'], 'idx_links_user_feed');
            $table->index(['user_id', 'collection_id', 'updated_at'], 'idx_links_user_collection');
            $table->index(['user_id', 'source_type', 'updated_at'], 'idx_links_user_source');
            $table->index(['user_id', 'is_read', 'created_at'], 'idx_links_resurface');
            $table->index(['reminder_sent', 'remind_at'], 'idx_links_pending_reminders');

            if (Schema::getConnection()->getDriverName() !== 'sqlite') {
                $table->fullText(['title', 'ai_summary', 'user_notes'], 'ft_links_search');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('links');
    }
};
