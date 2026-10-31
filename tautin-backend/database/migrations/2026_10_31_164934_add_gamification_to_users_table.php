<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Add the server-side gamification counters to `users`.
     *
     * XP and level are always computed by `XpLevelService`; `level` is persisted
     * only so ranking queries stay cheap.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->unsignedInteger('xp')->default(0);
            $table->unsignedTinyInteger('level')->default(1);
            $table->unsignedSmallInteger('streak_days')->default(0);
            $table->date('streak_last_date')->nullable();
            $table->unsignedTinyInteger('streak_shields_used')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn([
                'xp',
                'level',
                'streak_days',
                'streak_last_date',
                'streak_shields_used',
            ]);
        });
    }
};
