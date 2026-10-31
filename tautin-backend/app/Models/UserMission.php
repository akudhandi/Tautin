<?php

namespace App\Models;

use Database\Factories\UserMissionFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Progress of a single daily/weekly mission for a user.
 *
 * `progress` and `is_completed` are written server-side by
 * `App\Services\Gamification\XpLevelService`.
 */
class UserMission extends Model
{
    /** @use HasFactory<UserMissionFactory> */
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'mission_key',
        'period_type',
        'period_start',
        'target',
        'progress',
        'xp_reward',
        'is_completed',
        'completed_at',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'period_start' => 'date:Y-m-d',
            'completed_at' => 'datetime',
            'target' => 'integer',
            'progress' => 'integer',
            'xp_reward' => 'integer',
            'is_completed' => 'boolean',
        ];
    }

    /**
     * Get the user this mission belongs to.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
