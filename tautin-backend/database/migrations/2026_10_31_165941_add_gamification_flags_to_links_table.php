<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Remember which gamification rewards a link already produced, so
     * re-opening or re-pinning the same link cannot farm XP
     * (PRD FR-GAME-01 AC-3).
     */
    public function up(): void
    {
        Schema::table('links', function (Blueprint $table): void {
            $table->boolean('read_xp_awarded')->default(false);
            $table->boolean('pin_xp_awarded')->default(false);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('links', function (Blueprint $table): void {
            $table->dropColumn(['read_xp_awarded', 'pin_xp_awarded']);
        });
    }
};
