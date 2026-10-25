<?php

namespace App\Console\Commands;

use App\Models\Link;
use App\Services\Notification\FcmNotificationService;
use Carbon\Carbon;
use Illuminate\Console\Command;

class DispatchLinkRemindersCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'tautin:dispatch-reminders';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Kirim notifikasi pengingat tautan yang jatuh tempo';

    /**
     * Execute the console command.
     */
    public function handle(FcmNotificationService $fcmService): int
    {
        $now = Carbon::now();

        $dueLinks = Link::where('reminder_sent', false)
            ->whereNotNull('remind_at')
            ->where('remind_at', '<=', $now)
            ->with('user')
            ->get();

        $count = 0;

        foreach ($dueLinks as $link) {
            $user = $link->user;

            if ($user && ! empty($user->fcm_token)) {
                $fcmService->send(
                    fcmToken: $user->fcm_token,
                    title: 'Waktunya Membaca: '.($link->title ?? 'Tautan Tersimpan'),
                    body: 'Tautin mengingatkanmu untuk melanjutkan membaca tautan yang kamu jadwalkan.',
                    data: [
                        'type' => 'reminder',
                        'link_id' => (string) $link->id,
                        'url' => $link->url,
                    ]
                );
            }

            $link->update(['reminder_sent' => true]);
            $count++;
        }

        $this->info("Berhasil mengirimkan {$count} pengingat tautan.");

        return self::SUCCESS;
    }
}
