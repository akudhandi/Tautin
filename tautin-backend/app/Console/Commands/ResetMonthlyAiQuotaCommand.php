<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class ResetMonthlyAiQuotaCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'tautin:reset-monthly-quota';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Reset sisa kuota AI bulanan untuk seluruh pengguna gratis dan pro/lifetime';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $freeQuota = (int) config('tautin.free_plan.monthly_ai_quota', 10);
        $proQuota = (int) config('tautin.pro_plan.fair_use_monthly_ai_quota', 500);

        $affectedFree = User::where('plan_type', 'free')
            ->update(['ai_quota_left' => $freeQuota]);

        $affectedPro = User::whereIn('plan_type', ['pro', 'lifetime'])
            ->update(['ai_quota_left' => $proQuota]);

        $this->info("Berhasil mereset kuota AI: {$affectedFree} pengguna gratis ({$freeQuota}), {$affectedPro} pengguna pro/lifetime ({$proQuota}).");

        return self::SUCCESS;
    }
}
