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
        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('product_id', 100);
            $table->text('purchase_token');
            $table->char('purchase_token_hash', 64)->unique();
            $table->string('order_id', 100)->nullable();
            $table->enum('status', ['active', 'canceled', 'expired', 'refunded'])->default('active');
            $table->timestamp('starts_at');
            $table->timestamp('expires_at')->nullable();
            $table->timestamp('last_verified_at')->useCurrent();
            $table->timestamps();

            $table->index(['user_id', 'status'], 'idx_subscriptions_user_status');
            $table->index(['status', 'expires_at'], 'idx_subscriptions_expiry_check');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('subscriptions');
    }
};
