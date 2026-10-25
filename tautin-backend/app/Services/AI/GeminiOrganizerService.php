<?php

namespace App\Services\AI;

use App\Models\Link;
use App\Models\User;
use App\Services\AI\Data\AiAnalysisResult;
use App\Services\Scraper\Data\ScrapedMetadata;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiOrganizerService
{
    /**
     * Analyze scraped link metadata using Gemini 2.5 Flash and return structured AI insights.
     */
    public function analyze(Link $link, User $user, ScrapedMetadata $metadata): ?AiAnalysisResult
    {
        $apiKey = config('tautin.gemini.api_key');
        if (empty($apiKey)) {
            Log::info('Gemini API key is not configured, skipping AI analysis.');

            return null;
        }

        $userCollections = $user->collections()->pluck('name')->all();
        if (empty($userCollections)) {
            $userCollections = ['Umum'];
        }

        $collectionListStr = implode(', ', array_map(fn ($n) => '"'.$n.'"', $userCollections));

        $userPrompt = "URL: {$metadata->canonicalUrl}\n"
            ."Domain: {$metadata->domain}\n"
            ."Scraped Title: {$metadata->title}\n"
            ."Raw Share Text: {$link->raw_description}\n"
            .'Body Excerpt: '.mb_substr((string) ($metadata->bodyExcerpt ?? $metadata->description), 0, 1500)."\n"
            ."Daftar Koleksi User: [{$collectionListStr}]";

        $payload = [
            'systemInstruction' => [
                'parts' => [
                    [
                        'text' => 'Kamu adalah mesin pengorganisir tautan pintar untuk aplikasi Tautin. Analisis data URL berikut dan kembalikan JSON yang valid. Aturan: 1. clean_title: Bersihkan judul dari kata spam promosi (maks 100 karakter). 2. summary: Ringkasan padat 1-2 kalimat dalam Bahasa Indonesia. Jika resep, sebutkan bahan utama. Jika produk belanja, sebutkan jenis barang & harga/keunggulan. Jika artikel/edukasi, sebutkan intisarinya. 3. selected_collection_name: Pilih tepat satu nama koleksi yang paling cocok dari daftar koleksi milik user. 4. tags: Maksimal 3 tag huruf kecil dengan tanda hubung (contoh: [\'resep-ayam\', \'menu-harian\']). 5. source_type: Pilih satu dari \'video\', \'ecommerce\', \'article\', \'social\', \'other\'.',
                    ],
                ],
            ],
            'contents' => [
                [
                    'role' => 'user',
                    'parts' => [
                        [
                            'text' => $userPrompt,
                        ],
                    ],
                ],
            ],
            'generationConfig' => [
                'temperature' => 0.2,
                'maxOutputTokens' => 400,
                'responseMimeType' => 'application/json',
                'responseSchema' => [
                    'type' => 'OBJECT',
                    'properties' => [
                        'clean_title' => ['type' => 'STRING'],
                        'summary' => ['type' => 'STRING'],
                        'selected_collection_name' => ['type' => 'STRING'],
                        'tags' => [
                            'type' => 'ARRAY',
                            'items' => ['type' => 'STRING'],
                        ],
                        'source_type' => [
                            'type' => 'STRING',
                            'enum' => ['video', 'ecommerce', 'article', 'social', 'other'],
                        ],
                    ],
                    'required' => ['clean_title', 'summary', 'selected_collection_name', 'tags', 'source_type'],
                ],
            ],
        ];

        $model = config('tautin.gemini.model', 'gemini-2.5-flash');
        $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";

        try {
            $response = Http::withOptions([
                'timeout' => 12,
                'connect_timeout' => 4,
            ])->post($endpoint, $payload);

            if (! $response->successful()) {
                Log::warning('Gemini API call failed', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);

                return null;
            }

            $json = $response->json();
            $rawText = $json['candidates'][0]['content']['parts'][0]['text'] ?? null;

            if (empty($rawText)) {
                return null;
            }

            $parsed = json_decode($rawText, true);
            if (! is_array($parsed) || empty($parsed['clean_title']) || empty($parsed['summary'])) {
                return null;
            }

            $tags = [];
            if (! empty($parsed['tags']) && is_array($parsed['tags'])) {
                foreach (array_slice($parsed['tags'], 0, 3) as $tag) {
                    $cleanTag = strtolower(trim(preg_replace('/[^a-z0-9\-]+/i', '-', (string) $tag) ?? '', '-'));
                    if (! empty($cleanTag)) {
                        $tags[] = $cleanTag;
                    }
                }
            }

            $sourceType = $parsed['source_type'] ?? 'other';
            if (! in_array($sourceType, ['video', 'ecommerce', 'article', 'social', 'other'], true)) {
                $sourceType = 'other';
            }

            return new AiAnalysisResult(
                cleanTitle: mb_substr(trim($parsed['clean_title']), 0, 255),
                summary: trim($parsed['summary']),
                selectedCollectionName: trim($parsed['selected_collection_name'] ?? ($userCollections[0] ?? 'Umum')),
                tags: $tags,
                sourceType: $sourceType
            );
        } catch (\Throwable $e) {
            Log::warning('Gemini Organizer Exception', [
                'error' => $e->getMessage(),
                'url' => $link->url,
            ]);

            return null;
        }
    }
}
