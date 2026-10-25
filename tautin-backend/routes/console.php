<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// 1. Dispatch due link reminders every minute
Schedule::command('tautin:dispatch-reminders')->everyMinute();

// 2. Synchronize subscription status hourly
Schedule::command('tautin:sync-subscriptions')->hourly();

// 3. Send weekly unread links digest every Saturday at 09:00 WIB
Schedule::command('tautin:send-weekly-digest')->weeklyOn(6, '09:00');

// 4. Reset free tier monthly AI quota on the 1st of every month at 00:01 WIB
Schedule::command('tautin:reset-monthly-quota')->monthlyOn(1, '00:01');
