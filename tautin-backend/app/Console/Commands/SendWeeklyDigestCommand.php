<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\Notification\FcmNotificationService;
use Illuminate\Console\Command;

class SendWeeklyDigestCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'tautin:send-weekly-digest';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Kirim rekap tautan belum dibaca mingguan kepada pengguna';

    /**
     * Execute the console command.
     */
    public function handle(FcmNotificationService $fcmService): int
    {
        // Find users with FCM token and >= 3 unread links
        $users = User::whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->has('links', '>=', 3, 'and', fn ($q) => $q->where('is_read', false))
            ->withCount(['links' => fn ($q) => $q->where('is_read', false)])
            ->get();

        $count = 0;

        foreach ($users as $user) {
            $fcmService->send(
                fcmToken: (string) $user->fcm_token,
                title: 'Tautan Belum Dibaca Minggu Ini 📚',
                body: "Hai {$user->name}, kamu punya {$user->links_count} tautan yang tersimpan dan belum sempat dibaca. Yuk luangkan waktu senggangmu!",
                data: [
                    'type' => 'weekly_digest',
                    'unread_count' => (string) $user->links_count,
                ]
            );

            $count++;
        }

        $this->info("Berhasil mengirimkan rekap mingguan kepada {$count} pengguna.");

        return self::SUCCESS;
    }
}
