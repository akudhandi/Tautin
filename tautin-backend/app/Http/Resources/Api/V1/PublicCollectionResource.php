<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Collection
 */
class PublicCollectionResource extends JsonResource
{
    /**
     * Transform the resource into an array, strictly omitting the owner's email.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'icon' => $this->icon,
            'color' => $this->color,
            'owner_name' => $this->user?->name ?? 'Pengguna Tautin',
            'links_count' => $this->links_count ?? $this->links->count(),
            'links' => PublicLinkResource::collection($this->whenLoaded('links')),
            'created_at' => $this->created_at?->toISOString(),
        ];
    }
}
