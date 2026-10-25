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
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name', 120);
            $table->string('email', 150)->unique();
            $table->string('google_id', 100)->nullable()->index('idx_users_google_id');
            $table->string('avatar', 500)->nullable();
            $table->enum('plan_type', ['free', 'pro', 'lifetime'])->default('free');
            $table->timestamp('plan_expires_at')->nullable();
            $table->unsignedInteger('ai_quota_left')->default(10);
            $table->string('fcm_token', 255)->nullable();
            $table->timestamps();

            $table->index(['plan_type', 'plan_expires_at'], 'idx_users_plan_expiry');
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
