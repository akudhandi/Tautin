<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'google_id',
        'avatar',
        'plan_type',
        'plan_expires_at',
        'ai_quota_left',
        'fcm_token',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'plan_expires_at' => 'datetime',
            'ai_quota_left' => 'integer',
        ];
    }

    /**
     * Determine if the user has an active Pro or Lifetime plan.
     */
    public function isPro(): bool
    {
        if ($this->plan_type === 'lifetime') {
            return true;
        }

        if ($this->plan_type === 'pro') {
            return $this->plan_expires_at === null || $this->plan_expires_at->isFuture();
        }

        return false;
    }

    /**
     * Determine if the user has available AI quota.
     */
    public function hasAiQuota(): bool
    {
        return $this->ai_quota_left > 0;
    }

    /**
     * Get the user's collections.
     */
    public function collections(): HasMany
    {
        return $this->hasMany(Collection::class);
    }

    /**
     * Get the user's links.
     */
    public function links(): HasMany
    {
        return $this->hasMany(Link::class);
    }

    /**
     * Get the user's tags.
     */
    public function tags(): HasMany
    {
        return $this->hasMany(Tag::class);
    }

    /**
     * Get the user's subscriptions.
     */
    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }
}
