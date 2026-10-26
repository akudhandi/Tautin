import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/collection_model.dart';
import '../data/collections_repository.dart';

class CollectionsNotifier extends AsyncNotifier<List<CollectionModel>> {
  @override
  FutureOr<List<CollectionModel>> build() async {
    final LocalStorage storage = ref.watch(localStorageProvider);
    final List<CollectionModel> cached = storage.loadCollections();
    if (cached.isNotEmpty) {
      _refreshInBackground();
      return cached;
    }
    return _fetchFromApi();
  }

  void _refreshInBackground() {
    Future<void>.microtask(() async {
      try {
        final List<CollectionModel> fresh =
            await ref.read(collectionsRepositoryProvider).fetchCollections();
        state = AsyncData<List<CollectionModel>>(fresh);
      } catch (_) {
        // Keep cached offline
      }
    });
  }

  Future<List<CollectionModel>> _fetchFromApi() async {
    try {
      return await ref.read(collectionsRepositoryProvider).fetchCollections();
    } catch (e) {
      final LocalStorage storage = ref.read(localStorageProvider);
      return storage.loadCollections();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<CollectionModel>>();
    try {
      final List<CollectionModel> fresh =
          await ref.read(collectionsRepositoryProvider).fetchCollections();
      state = AsyncData<List<CollectionModel>>(fresh);
    } catch (e) {
      final LocalStorage storage = ref.read(localStorageProvider);
      state = AsyncData<List<CollectionModel>>(storage.loadCollections());
    }
  }

  Future<CollectionModel> createCollection({
    required String name,
    String? icon,
    String? color,
    bool isPublic = false,
  }) async {
    final CollectionModel created =
        await ref.read(collectionsRepositoryProvider).createCollection(
              name: name,
              icon: icon,
              color: color,
              isPublic: isPublic,
            );
    await refresh();
    return created;
  }

  Future<CollectionModel> updateCollection(
    int id, {
    String? name,
    String? icon,
    String? color,
    bool? isPublic,
    String? slug,
  }) async {
    final CollectionModel updated =
        await ref.read(collectionsRepositoryProvider).updateCollection(
              id,
              name: name,
              icon: icon,
              color: color,
              isPublic: isPublic,
              slug: slug,
            );
    await refresh();
    return updated;
  }

  Future<void> deleteCollection(int id) async {
    await ref.read(collectionsRepositoryProvider).deleteCollection(id);
    await refresh();
  }
}

final AsyncNotifierProvider<CollectionsNotifier, List<CollectionModel>>
    collectionsProvider =
    AsyncNotifierProvider<CollectionsNotifier, List<CollectionModel>>(
  CollectionsNotifier.new,
);
