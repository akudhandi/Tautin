<?php

namespace Tests\Feature;

use App\Jobs\ProcessSharedLinkJob;
use App\Models\Link;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class RegenerateAiTest extends TestCase
{
    use RefreshDatabase;

    public function test_free_user_cannot_regenerate_ai_summary(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Putri',
            'email' => 'putri@example.com',
            'plan_type' => 'free',
            'ai_quota_left' => 10,
        ]);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/article',
            'url_hash' => hash('sha256', 'https://example.com/article'),
            'raw_url_hash' => hash('sha256', 'https://example.com/article'),
            'domain' => 'example.com',
            'title' => 'Artikel',
            'status' => 'completed',
            'ai_summary' => 'Ringkasan lama.',
            'is_ai_processed' => true,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->postJson('/api/v1/links/'.$link->id.'/regenerate-ai');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'PRO_REQUIRED_FOR_REGENERATE',
                'message' => 'Fitur buat ulang ringkasan AI khusus untuk pengguna Tautin Pro.',
            ]);

        $link->refresh();
        $this->assertSame('completed', $link->status);
        Queue::assertNothingPushed();
    }

    public function test_pro_user_without_ai_quota_is_rejected(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Rizky Pro',
            'email' => 'rizky@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
            'ai_quota_left' => 0,
        ]);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/recipe',
            'url_hash' => hash('sha256', 'https://example.com/recipe'),
            'raw_url_hash' => hash('sha256', 'https://example.com/recipe'),
            'domain' => 'example.com',
            'title' => 'Resep Rendang',
            'status' => 'completed',
            'ai_summary' => 'Ringkasan lama.',
            'is_ai_processed' => true,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->postJson('/api/v1/links/'.$link->id.'/regenerate-ai');

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'error_code' => 'AI_QUOTA_EXCEEDED',
                'message' => 'Kuota ringkasan AI bulanan Anda telah habis.',
            ]);

        $link->refresh();
        $this->assertSame('completed', $link->status);
        Queue::assertNothingPushed();
    }

    public function test_pro_user_regenerates_link_and_job_dispatched_on_high_queue(): void
    {
        Queue::fake();

        $user = User::create([
            'name' => 'Dessa Pro',
            'email' => 'dessa@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
            'ai_quota_left' => 500,
        ]);

        $link = Link::create([
            'user_id' => $user->id,
            'url' => 'https://example.com/news',
            'url_hash' => hash('sha256', 'https://example.com/news'),
            'raw_url_hash' => hash('sha256', 'https://example.com/news'),
            'domain' => 'example.com',
            'title' => 'Berita Lama',
            'status' => 'completed',
            'ai_summary' => 'Ringkasan lama.',
            'is_ai_processed' => true,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$user->createToken('test')->plainTextToken)
            ->postJson('/api/v1/links/'.$link->id.'/regenerate-ai');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data' => [
                    'id' => $link->id,
                    'status' => 'pending',
                ],
                'meta' => [
                    'ai_quota_left' => 500,
                    'plan_type' => 'pro',
                ],
            ]);

        $this->assertSame(
            'Ringkasan AI akan dibuat ulang. Cek kembali beberapa saat lagi.',
            $response->json('message')
        );

        $link->refresh();
        $this->assertSame('pending', $link->status);

        Queue::assertPushedOn('high', ProcessSharedLinkJob::class, fn (ProcessSharedLinkJob $job): bool => $job->linkId === $link->id);
    }

    public function test_regenerating_another_users_link_is_not_found(): void
    {
        Queue::fake();

        $owner = User::create([
            'name' => 'Owner',
            'email' => 'owner@example.com',
        ]);
        $otherLink = Link::create([
            'user_id' => $owner->id,
            'url' => 'https://example.com/other',
            'url_hash' => hash('sha256', 'https://example.com/other'),
            'raw_url_hash' => hash('sha256', 'https://example.com/other'),
            'domain' => 'example.com',
        ]);

        $proUser = User::create([
            'name' => 'Bestpro',
            'email' => 'bestpro@example.com',
            'plan_type' => 'pro',
            'plan_expires_at' => now()->addMonth(),
            'ai_quota_left' => 500,
        ]);

        $response = $this->withHeader('Authorization', 'Bearer '.$proUser->createToken('test')->plainTextToken)
            ->postJson('/api/v1/links/'.$otherLink->id.'/regenerate-ai');

        $response->assertStatus(404);
    }
}
