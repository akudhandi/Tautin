<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Link;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Link
 */
class PublicLinkResource extends JsonResource
{
    /**
     * Transform the resource into an array, strictly omitting private notes.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->url,
            'domain' => $this->domain,
            'source_type' => $this->source_type,
            'title' => $this->title,
            'thumbnail_url' => $this->thumbnail_url,
            'ai_summary' => $this->ai_summary,
            'created_at' => $this->created_at?->toISOString(),
            'tags' => $this->whenLoaded('tags', fn () => $this->tags->pluck('name')->all()),
        ];
    }
}
