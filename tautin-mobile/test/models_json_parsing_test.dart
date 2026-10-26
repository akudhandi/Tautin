import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tautin/core/network/api_envelope.dart';
import 'package:tautin/core/network/api_exceptions.dart';
import 'package:tautin/shared/models/models.dart';

void main() {
  group('UserModel', () {
    const Map<String, dynamic> kUserJson = <String, dynamic>{
      'id': 19,
      'name': 'Rani Maharani',
      'email': 'rani@example.com',
      'google_id': 'g-1042',
      'avatar': 'https://lh3.googleusercontent.com/rani.png',
      'plan_type': 'free',
      'plan_expires_at': null,
      'ai_quota_left': 10,
      'fcm_token': null,
      'created_at': '2026-10-20T08:00:00.000000Z',
      'updated_at': '2026-10-20T08:00:00.000000Z',
    };

    test('parses the POST /auth/google user payload 1:1', () {
      final UserModel user = UserModel.fromJson(kUserJson);

      expect(user.id, 19);
      expect(user.name, 'Rani Maharani');
      expect(user.email, 'rani@example.com');
      expect(user.googleId, 'g-1042');
      expect(user.avatar, 'https://lh3.googleusercontent.com/rani.png');
      expect(user.planType, PlanType.free);
      expect(user.planExpiresAt, isNull);
      expect(user.aiQuotaLeft, 10);
      expect(user.fcmToken, isNull);
      expect(user.createdAt, '2026-10-20T08:00:00.000000Z');
      expect(user.isPro, isFalse);
    });

    test('toJson mirrors the backend JSON contract', () {
      expect(UserModel.fromJson(kUserJson).toJson(), kUserJson);
    });

    test('encode/decode round trip', () {
      final UserModel user = UserModel.fromJson(kUserJson);
      expect(UserModel.decode(user.encode()).toJson(), kUserJson);
    });

    test('copyWith keeps unspecified fields', () {
      final UserModel user = UserModel.fromJson(kUserJson).copyWith(
        aiQuotaLeft: 7,
        planType: PlanType.pro,
        planExpiresAt: '2026-12-31T23:59:59.000000Z',
      );

      expect(user.aiQuotaLeft, 7);
      expect(user.planType, PlanType.pro);
      expect(user.planExpiresAt, '2026-12-31T23:59:59.000000Z');
      expect(user.name, 'Rani Maharani');
      expect(user.email, 'rani@example.com');
      expect(user.isPro, isTrue);
    });

    test('pro with a future expiry and lifetime both count as Pro', () {
      final UserModel pro = UserModel.fromJson(
        <String, dynamic>{...kUserJson, 'plan_type': 'pro'},
      ).copyWith(planExpiresAt: '2026-12-31T23:59:59.000000Z');
      final UserModel lifetime = UserModel.fromJson(
        <String, dynamic>{...kUserJson, 'plan_type': 'lifetime'},
      );

      expect(pro.isPro, isTrue);
      expect(lifetime.isPro, isTrue);
    });

    test('tolerate missing/AI quota fields with safe defaults', () {
      final UserModel minimal = UserModel.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Sari Siregar',
        'email': 'sari@example.com',
        'plan_type': 'weird-plan',
      });

      expect(minimal.aiQuotaLeft, 10);
      expect(minimal.planType, PlanType.free);
      expect(minimal.googleId, isNull);
    });
  });

  group('CollectionModel', () {
    const Map<String, dynamic> kCollectionJson = <String, dynamic>{
      'id': 7,
      'user_id': 19,
      'name': 'Belanja & Wishlist',
      'icon': 'shopping_bag',
      'color': '#7C3AED',
      'slug': null,
      'is_public': false,
      'is_default': true,
      'sort_order': 0,
      'links_count': 23,
      'created_at': '2026-10-20T08:00:00.000000Z',
      'updated_at': '2026-10-20T08:00:00.000000Z',
    };

    test('parses collections list fields 1:1', () {
      final CollectionModel collection = CollectionModel.fromJson(
        kCollectionJson,
      );

      expect(collection.id, 7);
      expect(collection.userId, 19);
      expect(collection.name, 'Belanja & Wishlist');
      expect(collection.icon, 'shopping_bag');
      expect(collection.color, '#7C3AED');
      expect(collection.slug, isNull);
      expect(collection.isPublic, isFalse);
      expect(collection.isDefault, isTrue);
      expect(collection.sortOrder, 0);
      expect(collection.linksCount, 23);
    });

    test('toJson mirrors the backend JSON contract', () {
      expect(
        CollectionModel.fromJson(kCollectionJson).toJson(),
        kCollectionJson,
      );
    });

    test('encode/decode round trip', () {
      final CollectionModel collection = CollectionModel.fromJson(
        kCollectionJson,
      );
      expect(CollectionModel.decode(collection.encode()).toJson(), kCollectionJson);
    });

    test('copyWith keeps unspecified fields', () {
      final CollectionModel updated = CollectionModel.fromJson(
        kCollectionJson,
      ).copyWith(isPublic: true, slug: 'belanja-wishlist', linksCount: 24);

      expect(updated.isPublic, isTrue);
      expect(updated.slug, 'belanja-wishlist');
      expect(updated.linksCount, 24);
      expect(updated.isDefault, isTrue);
      expect(updated.name, 'Belanja & Wishlist');
    });

    test('decodeList skips non-map junk entries', () {
      final List<CollectionModel> parsed = CollectionModel.decodeList(
        <dynamic>[
          kCollectionJson,
          'potongan-rusak',
          42,
        ],
      );

      expect(parsed, hasLength(1));
      expect(parsed.single.name, 'Belanja & Wishlist');
    });
  });

  group('LinkModel', () {
    const Map<String, dynamic> kQuickSaveLinkJson = <String, dynamic>{
      'id': 501,
      'user_id': 19,
      'collection_id': 7,
      'url': 'https://s.shopee.co.id/3Vja8nQXm',
      'url_hash': 'f2c9e1hash',
      'domain': 's.shopee.co.id',
      'source_type': 'ecommerce',
      'title': 'Sepatu Lari Pria Ukuran 42',
      'thumbnail_url': 'https://cf.shopee.co.id/tn.png',
      'raw_description': 'Cek produk ini broer: buruan beli stok terbatas!',
      'ai_summary': null,
      'user_notes': null,
      'status': 'pending',
      'is_ai_processed': false,
      'is_pinned': false,
      'is_read': false,
      'remind_at': null,
      'reminder_sent': false,
      'collection': <String, dynamic>{
        'id': 7,
        'user_id': 19,
        'name': 'Belanja & Wishlist',
        'icon': 'shopping_bag',
        'color': '#7C3AED',
        'slug': null,
        'is_public': false,
        'is_default': true,
        'sort_order': 0,
        'links_count': 23,
        'created_at': '2026-10-20T08:00:00.000000Z',
        'updated_at': '2026-10-20T08:00:00.000000Z',
      },
      'tags': <Map<String, dynamic>>[
        <String, dynamic>{'id': 3, 'name': 'resep-ayam', 'user_id': 19},
        <String, dynamic>{'id': 4, 'name': 'menu-harian', 'user_id': 19},
      ],
      'created_at': '2026-10-25T03:00:00.000000Z',
      'updated_at': '2026-10-25T03:00:00.000000Z',
    };

    test('parses the quick-save data payload with nested relations', () {
      final LinkModel link = LinkModel.fromJson(kQuickSaveLinkJson);

      expect(link.id, 501);
      expect(link.userId, 19);
      expect(link.collectionId, 7);
      expect(link.url, 'https://s.shopee.co.id/3Vja8nQXm');
      expect(link.urlHash, 'f2c9e1hash');
      expect(link.domain, 's.shopee.co.id');
      expect(link.sourceType, 'ecommerce');
      expect(link.title, 'Sepatu Lari Pria Ukuran 42');
      expect(link.rawDescription, 'Cek produk ini broer: buruan beli stok terbatas!');
      expect(link.aiSummary, isNull);
      expect(link.userNotes, isNull);
      expect(link.status, 'pending');
      expect(link.isAiProcessed, isFalse);
      expect(link.remindAt, isNull);
      expect(link.collection?.name, 'Belanja & Wishlist');
      expect(link.tags.map((TagModel tag) => tag.name),
          <String>['resep-ayam', 'menu-harian']);
      expect(link.isPending, isTrue);
      expect(link.isCompleted, isFalse);
    });

    test('toJson mirrors the backend JSON contract', () {
      expect(
        LinkModel.fromJson(kQuickSaveLinkJson).toJson(),
        kQuickSaveLinkJson,
      );
    });

    test('encode/decode round trip', () {
      final LinkModel link = LinkModel.fromJson(kQuickSaveLinkJson);
      expect(LinkModel.decode(link.encode()).toJson(), kQuickSaveLinkJson);
    });

    test('copyWith transitions status and notes', () {
      final LinkModel completed = LinkModel.fromJson(
        kQuickSaveLinkJson,
      ).copyWith(
        status: 'completed',
        isAiProcessed: true,
        aiSummary: 'Sepatu lari 42, harga Rp 350 ribu.',
        userNotes: 'Simpan buat checklist belanja.',
      );

      expect(completed.isCompleted, isTrue);
      expect(completed.isPending, isFalse);
      expect(completed.aiSummary, 'Sepatu lari 42, harga Rp 350 ribu.');
      expect(completed.userNotes, 'Simpan buat checklist belanja.');
      expect(completed.tags, hasLength(2));
    });

    test('handles responses without eager-loaded relations', () {
      final LinkModel bare = LinkModel.fromJson(<String, dynamic>{
        'id': 9,
        'user_id': 19,
        'url': 'https://example.com/a',
        'url_hash': 'zz',
        'domain': 'example.com',
      });

      expect(bare.collection, isNull);
      expect(bare.tags, isEmpty);
      expect(bare.status, 'pending');
      expect(bare.sourceType, 'other');
    });
  });

  group('PlanType', () {
    test('maps backend names exactly like User::isPro()', () {
      expect(PlanType.fromName('free'), PlanType.free);
      expect(PlanType.fromName('pro'), PlanType.pro);
      expect(PlanType.fromName('lifetime'), PlanType.lifetime);
      expect(PlanType.fromName('unknown'), PlanType.free);
      expect(PlanType.fromName(null), PlanType.free);
    });

    test('isProEntitled', () {
      expect(PlanType.free.isProEntitled, isFalse);
      expect(PlanType.pro.isProEntitled, isTrue);
      expect(PlanType.lifetime.isProEntitled, isTrue);
    });
  });

  group('ApiEnvelope', () {
    test('parses the auth/google login envelope', () {
      const Map<String, dynamic> kUserJson = <String, dynamic>{
        'id': 19,
        'name': 'Rani Maharani',
        'email': 'rani@example.com',
        'plan_type': 'free',
        'ai_quota_left': 10,
      };

      final ApiEnvelope envelope = ApiEnvelope.fromMap(<String, dynamic>{
        'success': true,
        'message': 'Login berhasil.',
        'data': <String, dynamic>{
          'user': kUserJson,
          'token': 'sanctum-token-abc',
          'is_new_user': true,
          'collections': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'name': 'Belanja & Wishlist',
              'is_default': true,
            },
          ],
        },
        'meta': <String, dynamic>{'ai_quota_left': 9, 'plan_type': 'free'},
      });

      expect(envelope.success, isTrue);
      expect(envelope.message, 'Login berhasil.');

      final Map<String, dynamic> data =
          (envelope.data as Map? ?? <String, dynamic>{}).cast<String, dynamic>();
      final UserModel user = UserModel.fromJson(
        (data['user'] as Map? ?? <String, dynamic>{}).cast<String, dynamic>(),
      );
      expect(user.name, 'Rani Maharani');
      expect(data['token'], 'sanctum-token-abc');
      expect(data['is_new_user'], isTrue);

      final List<CollectionModel> collections = CollectionModel.decodeList(
        data['collections'] as List<dynamic>,
      );
      expect(collections.single.name, 'Belanja & Wishlist');

      expect(envelope.metaAiQuotaLeft, 9);
      expect(envelope.metaPlanType, 'free');
      expect(envelope.metaIsDuplicate, isFalse);
    });

    test('parses the quick-save duplicate envelope', () {
      final ApiEnvelope envelope = ApiEnvelope.fromMap(<String, dynamic>{
        'success': true,
        'message': 'Tautan sudah ada di daftar, dinaikkan ke paling atas.',
        'data': <String, dynamic>{
          'id': 501,
          'user_id': 19,
          'url': 'https://s.shopee.co.id/3Vja8nQXm',
          'url_hash': 'f2c9e1hash',
          'domain': 's.shopee.co.id',
        },
        'meta': <String, dynamic>{
          'is_duplicate': true,
          'ai_quota_left': 8,
          'plan_type': 'free',
        },
      });

      expect(envelope.metaIsDuplicate, isTrue);
      expect(envelope.metaAiQuotaLeft, 8);

      final LinkModel link = LinkModel.fromJson(
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>(),
      );
      expect(link.id, 501);
      expect(link.domain, 's.shopee.co.id');
    });

    test('requireSuccess passes for 201 quick-save responses', () {
      final Response<dynamic> response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/links/quick-save'),
        statusCode: 201,
        data: <String, dynamic>{
          'success': true,
          'message': 'Tautan berhasil disimpan.',
          'data': <String, dynamic>{
            'id': 5,
            'user_id': 1,
            'url': 'https://example.com',
            'url_hash': 'x',
            'domain': 'example.com',
          },
        },
      );

      expect(
        ApiEnvelope.requireSuccess(response).message,
        'Tautan berhasil disimpan.',
      );
    });

    test('requireSuccess throws with backend error_code for 4xx bodies', () {
      final Response<dynamic> response = Response<dynamic>(
        requestOptions: RequestOptions(path: '/collections'),
        statusCode: 422,
        data: <String, dynamic>{
          'success': false,
          'message': 'Kamu sudah mencapai batas 5 koleksi.',
          'error_code': 'COLLECTION_LIMIT_REACHED',
        },
      );

      expect(
        () => ApiEnvelope.requireSuccess(response),
        throwsA(
          isA<TautinApiException>()
              .having(
                (TautinApiException e) => e.errorCode,
                'errorCode',
                'COLLECTION_LIMIT_REACHED',
              )
              .having(
                (TautinApiException e) => e.message,
                'message',
                'Kamu sudah mencapai batas 5 koleksi.',
              ),
        ),
      );
    });

    test('throws for non-map bodies', () {
      expect(
        () => ApiEnvelope.fromMap('pong'),
        throwsA(isA<TautinApiException>()),
      );
    });
  });

  group('ApiEnvelope.exceptionFromDio', () {
    test('maps connection failures as offline', () {
      for (final DioExceptionType type in <DioExceptionType>[
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final TautinApiException exception = ApiEnvelope.exceptionFromDio(
          DioException(
            requestOptions: RequestOptions(path: '/links/quick-save'),
            type: type,
          ),
        );

        expect(exception.isConnectionError, isTrue, reason: '$type');
        expect(exception.message, 'Koneksi internet tidak tersedia.');
      }
    });

    test('surfaces body error_code for bad responses', () {
      final TautinApiException exception = ApiEnvelope.exceptionFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/links'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/links'),
            statusCode: 401,
            data: <String, dynamic>{
              'success': false,
              'message': 'Sesi login tidak valid.',
              'error_code': 'UNAUTHENTICATED',
            },
          ),
        ),
      );

      expect(exception.isConnectionError, isFalse);
      expect(exception.errorCode, 'UNAUTHENTICATED');
      expect(exception.message, 'Sesi login tidak valid.');
      expect(exception.statusCode, 401);
    });

    test('falls back to an Indonesian default message', () {
      final TautinApiException exception = ApiEnvelope.exceptionFromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.cancel,
        ),
      );

      expect(exception.isConnectionError, isFalse);
      expect(exception.message, 'Permintaan dibatalkan.');
    });
  });
}
