<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Link extends Model
{
    use HasFactory;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'collection_id',
        'url',
        'url_hash',
        'domain',
        'source_type',
        'title',
        'thumbnail_url',
        'raw_description',
        'ai_summary',
        'user_notes',
        'status',
        'is_ai_processed',
        'is_pinned',
        'is_read',
        'remind_at',
        'reminder_sent',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'is_ai_processed' => 'boolean',
            'is_pinned' => 'boolean',
            'is_read' => 'boolean',
            'reminder_sent' => 'boolean',
            'remind_at' => 'datetime',
        ];
    }

    /**
     * Get the user that owns the link.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Get the collection containing this link.
     */
    public function collection(): BelongsTo
    {
        return $this->belongsTo(Collection::class);
    }

    /**
     * Get the tags associated with this link.
     */
    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(Tag::class, 'link_tag');
    }
}
