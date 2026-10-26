import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/features/share_intent/domain/dirty_url_parser.dart';

void main() {
  group('DirtyUrlParser', () {
    group('dirty e-commerce share texts', () {
      test('extracts URL and splits leftover Shopee promo text', () {
        const String share = 'Harga spesial 12.12! '
            'https://s.shopee.co.id/3Vja8nQXm ShaShopee! Jangan sampai telat '
            'checkout.';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://s.shopee.co.id/3Vja8nQXm');
        expect(
          parsed.rawDescription,
          'Harga spesial 12.12! ShaShopee! Jangan sampai telat checkout.',
        );
      });

      test('extracts tokopedia product URL with utm junk kept in url', () {
        const String share =
            'Cek produk ini broer: https://www.tokopedia.com/sneakersku/'
            'sepatu-lari-pria-ukuran-42?extParam=ivf%3Dtrue&utm_source=wa '
            'buruan beli stok terbatas!';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(
          parsed!.cleanUrl,
          'https://www.tokopedia.com/sneakersku/'
          'sepatu-lari-pria-ukuran-42?extParam=ivf%3Dtrue&utm_source=wa',
        );
        expect(
          parsed.rawDescription,
          'Cek produk ini broer: buruan beli stok terbatas!',
        );
      });

      test('extracts tiktok video url from caption-prefixed share', () {
        const String share =
            'Resep nasi goreng gila enak TikTok\n'
            'https://vt.tiktok.com/ZSabcdef/\n'
            '#fyp #resep';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://vt.tiktok.com/ZSabcdef/');
        expect(parsed.rawDescription, 'Resep nasi goreng gila enak TikTok #fyp #resep');
      });
    });

    group('url preservation', () {
      test('keeps full query parameters and hash fragment intact', () {
        const String share =
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxyz&t=42s '
            'bagus ini';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(
          parsed!.cleanUrl,
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLxyz&t=42s',
        );
        expect(parsed.rawDescription, 'bagus ini');
      });

      test('drops surrounding parentheses of a parenthesised link', () {
        const String share = '(lihat di https://example.com/artikel-1)';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://example.com/artikel-1');
        expect(parsed.rawDescription, '(lihat di )');
      });
    });

    group('sentence punctuation tails', () {
      test('strips a trailing full stop from a sentence-ending URL', () {
        const String share = 'Menu lengkap ada di https://example.com/menu.';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://example.com/menu');
        expect(parsed.rawDescription, 'Menu lengkap ada di');
      });

      test('strips trailing comma and keeps internal dots', () {
        const String share =
            'Buka barnya: https://blog.example.com/v1.2/berita-terbaru, lalu kirimkan.';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(
          parsed!.cleanUrl,
          'https://blog.example.com/v1.2/berita-terbaru',
        );
        expect(parsed.rawDescription, 'Buka barnya: lalu kirimkan.');
      });

      test('strips an ellipsis tail', () {
        const String share = 'https://example.com/unduh\u2026';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://example.com/unduh');
      });

      test('keeps a directory file with dotted extension untouched', () {
        const String share = 'https://example.com/files/gambar.png';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://example.com/files/gambar.png');
      });
    });

    group('no usable URL', () {
      test('returns null for plain promotional text', () {
        const String share = 'TEMUKAN KEBAHAGIAAN DI SINI, diskon gede2an!!!';

        final ParsedShareInput? result = DirtyUrlParser.parse(share);

        expect(result, isNull);
      });

      test('returns null for empty input', () {
        expect(DirtyUrlParser.parse('   '), isNull);
      });

      test('returns null for scheme without host', () {
        expect(DirtyUrlParser.parse('https:// Ini URL macam apa?'), isNull);
      });

      test('returns null for a broken ftp-like scheme', () {
        expect(DirtyUrlParser.parse('ftp://files.example.com/paket.zip'),
            isNull);
      });
    });

    group('multi-line and duplicates', () {
      test('uses the FIRST url when several are shared', () {
        const String share =
            'https://one.example.com/a https://two.example.com/b';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(parsed!.cleanUrl, 'https://one.example.com/a');
      });

      test('squashes all extra whitespace into single spaces', () {
        const String share =
            'Judul   panjang\n\nbanget   \t dibagikan  '
            '\nhttps://res.example.com/x  sekali   aja';

        final ParsedShareInput? parsed = DirtyUrlParser.parse(share);

        expect(parsed, isNotNull);
        expect(
          parsed!.rawDescription,
          'Judul panjang banget dibagikan sekali aja',
        );
      });
    });
  });
}
