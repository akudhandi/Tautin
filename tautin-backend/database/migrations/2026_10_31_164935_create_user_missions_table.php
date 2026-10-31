<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Daily/weekly mission progress per user. Progress is written by
     * `XpLevelService` so the mobile client never computes XP itself.
     */
    public function up(): void
    {
        Schema::create('user_missions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('mission_key', 60);
            $table->enum('period_type', ['daily', 'weekly'])->default('daily');
            $table->date('period_start');
            $table->unsignedInteger('target')->default(1);
            $table->unsignedInteger('progress')->default(0);
            $table->unsignedInteger('xp_reward')->default(20);
            $table->boolean('is_completed')->default(false);
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->unique(
                ['user_id', 'mission_key', 'period_start'],
                'uq_user_missions_period'
            );
            $table->index(
                ['user_id', 'is_completed', 'period_start'],
                'idx_user_missions_active'
            );
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('user_missions');
    }
};
