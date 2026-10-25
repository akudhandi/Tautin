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
    protected $description = 'Reset sisa kuota AI bulanan menjadi 10 untuk seluruh pengguna gratis';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $defaultQuota = (int) config('tautin.free_plan.monthly_ai_quota', 10);

        $affected = User::where('plan_type', 'free')
            ->update(['ai_quota_left' => $defaultQuota]);

        $this->info("Berhasil mereset kuota AI untuk {$affected} pengguna gratis ke {$defaultQuota}.");

        return self::SUCCESS;
    }
}
