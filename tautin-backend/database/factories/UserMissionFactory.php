<?php

namespace Database\Factories;

use App\Models\User;
use App\Models\UserMission;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<UserMission>
 */
class UserMissionFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'mission_key' => 'daily_save_3',
            'period_type' => 'daily',
            'period_start' => now()->toDateString(),
            'target' => 3,
            'progress' => 0,
            'xp_reward' => 20,
            'is_completed' => false,
            'completed_at' => null,
        ];
    }
}
