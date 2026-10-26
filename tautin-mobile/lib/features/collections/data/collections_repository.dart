import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/collection_model.dart';

abstract interface class CollectionsRepository {
  Future<List<CollectionModel>> fetchCollections();

  Future<CollectionModel> createCollection({
    required String name,
    String? icon,
    String? color,
    bool isPublic = false,
  });

  Future<CollectionModel> updateCollection(
    int id, {
    String? name,
    String? icon,
    String? color,
    bool? isPublic,
    String? slug,
  });

  Future<void> deleteCollection(int id);

  Future<CollectionModel> clonePublicCollection(String slug);
}

class TautinCollectionsRepository implements CollectionsRepository {
  TautinCollectionsRepository({required Dio dio, required LocalStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  @override
  Future<List<CollectionModel>> fetchCollections() async {
    final Response<dynamic> response = await _dio.get<Object?>('/collections');
    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final List<dynamic> items =
        envelope.data as List<dynamic>? ?? <dynamic>[];
    final List<CollectionModel> collections = items
        .map((dynamic item) =>
            CollectionModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();

    await _storage.saveCollections(collections);
    return collections;
  }

  @override
  Future<CollectionModel> createCollection({
    required String name,
    String? icon,
    String? color,
    bool isPublic = false,
  }) async {
    final Response<dynamic> response = await _dio.post<Object?>(
      '/collections',
      data: <String, dynamic>{
        'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        'is_public': isPublic,
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    final CollectionModel created = CollectionModel.fromJson(data);

    // Refresh cached list
    await fetchCollections();
    return created;
  }

  @override
  Future<CollectionModel> updateCollection(
    int id, {
    String? name,
    String? icon,
    String? color,
    bool? isPublic,
    String? slug,
  }) async {
    final Response<dynamic> response = await _dio.patch<Object?>(
      '/collections/$id',
      data: <String, dynamic>{
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (isPublic != null) 'is_public': isPublic,
        if (slug != null) 'slug': slug,
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    final CollectionModel updated = CollectionModel.fromJson(data);

    await fetchCollections();
    return updated;
  }

  @override
  Future<void> deleteCollection(int id) async {
    final Response<dynamic> response =
        await _dio.delete<Object?>('/collections/$id');
    ApiEnvelope.requireSuccess(response);
    await fetchCollections();
  }

  @override
  Future<CollectionModel> clonePublicCollection(String slug) async {
    final Response<dynamic> response =
        await _dio.post<Object?>('/public/collections/$slug/clone');
    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    final CollectionModel cloned = CollectionModel.fromJson(data);

    await fetchCollections();
    return cloned;
  }
}

final Provider<CollectionsRepository> collectionsRepositoryProvider =
    Provider<CollectionsRepository>(
  (Ref ref) => TautinCollectionsRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  ),
);
