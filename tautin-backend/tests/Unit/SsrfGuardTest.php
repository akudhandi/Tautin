<?php

namespace Tests\Unit;

use App\Exceptions\UnsafeUrlException;
use App\Services\Scraper\SsrfGuard;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SsrfGuardTest extends TestCase
{
    protected SsrfGuard $guard;

    protected function setUp(): void
    {
        parent::setUp();
        $this->guard = new SsrfGuard;
    }

    public function test_rejects_loopback_ip(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('http://127.0.0.1:8000/api');
    }

    public function test_rejects_private_class_c_ip(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('http://192.168.1.1/admin');
    }

    public function test_rejects_private_class_a_ip(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('http://10.0.0.1/secret');
    }

    public function test_rejects_cloud_metadata_ip(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('http://169.254.169.254/latest/meta-data/');
    }

    public function test_rejects_localhost_hostname(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('http://localhost:8080');
    }

    public function test_rejects_disallowed_ports(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('https://example.com:22');
    }

    public function test_rejects_disallowed_schemes(): void
    {
        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateUrl('ftp://example.com/file.txt');
    }

    public function test_strips_tracking_parameters(): void
    {
        $url = 'https://example.com/produk?utm_source=shopee&utm_medium=share&id=99&fbclid=abc123xyz&_r=1';
        $cleaned = $this->guard->stripTrackingParams($url);

        $this->assertEquals('https://example.com/produk?id=99', $cleaned);
    }

    public function test_detects_ssrf_via_redirect_to_private_ip(): void
    {
        Http::fake([
            'https://example.com/shortlink' => Http::response('', 302, [
                'Location' => 'http://127.0.0.1:3306',
            ]),
        ]);

        $this->expectException(UnsafeUrlException::class);
        $this->guard->validateAndResolve('https://example.com/shortlink');
    }

    public function test_successfully_resolves_safe_redirect(): void
    {
        Http::fake([
            'https://example.com/go' => Http::response('', 301, [
                'Location' => 'https://example.com/target-page?utm_source=ad&ref=user1',
            ]),
            'https://example.com/target-page*' => Http::response('<html>OK</html>', 200),
        ]);

        $final = $this->guard->validateAndResolve('https://example.com/go');

        $this->assertEquals('https://example.com/target-page?ref=user1', $final);
    }
}
