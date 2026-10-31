<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class GuestAuthenticationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Unauthenticated API requests must receive a JSON 401, never a 500
     * caused by a missing "login" redirect route.
     */
    public function test_guest_receives_json_401_instead_of_route_not_found_error(): void
    {
        $response = $this->getJson('/api/v1/links');

        $response->assertStatus(401);
        $response->assertJsonPath('message', 'Unauthenticated.');
    }

    /**
     * Unauthenticated collection listing behaves the same way.
     */
    public function test_guest_cannot_list_collections(): void
    {
        $response = $this->getJson('/api/v1/collections');

        $response->assertUnauthorized();
    }
}
