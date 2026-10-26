<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Billing\GooglePlayBillingService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

class SyncExpiredSubscriptionsCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'tautin:sync-subscriptions';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Sinkronisasi masa berlaku langganan pengguna Pro dengan Google Play Developer API';

    /**
     * Execute the console command.
     */
    public function handle(GooglePlayBillingService $billingService): int
    {
        $now = Carbon::now();

        // Find Pro users whose subscription plan expired
        $expiredUsers = User::where('plan_type', 'pro')
            ->whereNotNull('plan_expires_at')
            ->where('plan_expires_at', '<=', $now)
            ->with(['subscriptions' => fn ($q) => $q->orderBy('created_at', 'desc')])
            ->get();

        $downgraded = 0;
        $renewed = 0;

        $freeQuota = (int) config('tautin.free_plan.monthly_ai_quota', 10);
        $proQuota = (int) config('tautin.pro_plan.fair_use_monthly_ai_quota', 500);

        foreach ($expiredUsers as $user) {
            $lastSub = $user->subscriptions->first();

            if (! $lastSub) {
                $user->update([
                    'plan_type' => 'free',
                    'ai_quota_left' => $freeQuota,
                ]);
                $downgraded++;

                continue;
            }

            try {
                $verified = $billingService->verifyAndAcknowledgeSubscription(
                    $lastSub->product_id,
                    $lastSub->purchase_token
                );

                if ($verified['expires_at'] && $verified['expires_at']->isFuture()) {
                    // Subscription auto-renewed by user in Google Play
                    $user->update([
                        'plan_expires_at' => $verified['expires_at'],
                        'ai_quota_left' => $proQuota,
                    ]);

                    $lastSub->update([
                        'expires_at' => $verified['expires_at'],
                        'status' => 'active',
                        'last_verified_at' => $now,
                    ]);

                    $renewed++;
                } else {
                    // Subscription ended
                    $lastSub->update([
                        'status' => 'expired',
                        'last_verified_at' => $now,
                    ]);

                    $user->update([
                        'plan_type' => 'free',
                        'ai_quota_left' => $freeQuota,
                    ]);

                    $downgraded++;
                }
            } catch (\Throwable $e) {
                Log::warning('Subscription sync check failed, downgrading user to free', [
                    'user_id' => $user->id,
                    'error' => $e->getMessage(),
                ]);

                $lastSub->update([
                    'status' => 'expired',
                    'last_verified_at' => $now,
                ]);

                $user->update([
                    'plan_type' => 'free',
                    'ai_quota_left' => $freeQuota,
                ]);

                $downgraded++;
            }
        }

        $this->info("Sinkronisasi langganan selesai: {$renewed} diperpanjang, {$downgraded} diturunkan ke paket gratis.");

        return self::SUCCESS;
    }
}
