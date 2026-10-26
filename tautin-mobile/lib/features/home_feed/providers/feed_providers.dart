import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../share_intent/data/link_repository.dart';

/// Available feed filters.
enum FeedFilter {
  all(label: 'Semua', sourceType: null, isRead: null, isUnassigned: false),
  video(label: 'Video', sourceType: 'video', isRead: null, isUnassigned: false),
  ecommerce(label: 'Belanja', sourceType: 'ecommerce', isRead: null, isUnassigned: false),
  article(label: 'Artikel', sourceType: 'article', isRead: null, isUnassigned: false),
  unread(label: 'Belum Dibaca', sourceType: null, isRead: false, isUnassigned: false),
  unassigned(label: 'Tanpa Koleksi', sourceType: null, isRead: null, isUnassigned: true);

  const FeedFilter({
    required this.label,
    required this.sourceType,
    required this.isRead,
    required this.isUnassigned,
  });

  final String label;
  final String? sourceType;
  final bool? isRead;
  final bool isUnassigned;
}

class FilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => FeedFilter.all;

  void setFilter(FeedFilter filter) => state = filter;
}

final NotifierProvider<FilterNotifier, FeedFilter> activeFilterProvider =
    NotifierProvider<FilterNotifier, FeedFilter>(FilterNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final NotifierProvider<SearchQueryNotifier, String> searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Resurfacing unread links provider (refreshes on pull-to-refresh).
final FutureProvider<List<LinkModel>> resurfaceLinksProvider =
    FutureProvider<List<LinkModel>>((Ref ref) async {
  final LinkRepository repo = ref.watch(linkRepositoryProvider);
  try {
    return await repo.fetchResurface();
  } catch (_) {
    return <LinkModel>[];
  }
});

/// Current authenticated user provider, keeping quota and Pro status in sync.
class CurrentUserNotifier extends AsyncNotifier<UserModel?> {
  @override
  FutureOr<UserModel?> build() async {
    final LocalStorage storage = ref.watch(localStorageProvider);
    final UserModel? local = storage.user;
    if (local != null) {
      _refreshInBackground();
    }
    return local;
  }

  void _refreshInBackground() {
    Future<void>.microtask(() async {
      try {
        final UserModel fresh =
            await ref.read(authRepositoryProvider).fetchCurrentUser();
        state = AsyncData<UserModel?>(fresh);
      } catch (_) {
        // Keep local on offline
      }
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading<UserModel?>();
    try {
      final UserModel fresh =
          await ref.read(authRepositoryProvider).fetchCurrentUser();
      state = AsyncData<UserModel?>(fresh);
    } catch (_) {
      final LocalStorage storage = ref.read(localStorageProvider);
      state = AsyncData<UserModel?>(storage.user);
    }
  }

  void updateLocal(UserModel updated) {
    ref.read(localStorageProvider).saveUser(updated);
    state = AsyncData<UserModel?>(updated);
  }
}

final AsyncNotifierProvider<CurrentUserNotifier, UserModel?> currentUserProvider =
    AsyncNotifierProvider<CurrentUserNotifier, UserModel?>(
  CurrentUserNotifier.new,
);

/// State for the paginated feed list.
class FeedState {
  const FeedState({
    required this.links,
    this.currentPage = 1,
    this.lastPage = 1,
    this.isLoadingMore = false,
  });

  final List<LinkModel> links;
  final int currentPage;
  final int lastPage;
  final bool isLoadingMore;

  bool get hasMore => currentPage < lastPage;

  FeedState copyWith({
    List<LinkModel>? links,
    int? currentPage,
    int? lastPage,
    bool? isLoadingMore,
  }) {
    return FeedState(
      links: links ?? this.links,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Feed controller handling pagination, filtering, search, and optimistic item updates.
class FeedController extends AsyncNotifier<FeedState> {
  @override
  FutureOr<FeedState> build() async {
    final FeedFilter filter = ref.watch(activeFilterProvider);
    final String search = ref.watch(searchQueryProvider);
    final LinkRepository repo = ref.watch(linkRepositoryProvider);

    final PaginatedLinks result = await repo.fetchLinks(
      page: 1,
      sourceType: filter.sourceType,
      isRead: filter.isRead,
      unassigned: filter.isUnassigned,
      search: search.isEmpty ? null : search,
    );

    return FeedState(
      links: result.links,
      currentPage: result.currentPage,
      lastPage: result.lastPage,
    );
  }

  Future<void> loadNextPage() async {
    final FeedState? current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) {
      return;
    }

    state = AsyncData<FeedState>(current.copyWith(isLoadingMore: true));

    try {
      final FeedFilter filter = ref.read(activeFilterProvider);
      final String search = ref.read(searchQueryProvider);
      final LinkRepository repo = ref.read(linkRepositoryProvider);

      final PaginatedLinks result = await repo.fetchLinks(
        page: current.currentPage + 1,
        sourceType: filter.sourceType,
        isRead: filter.isRead,
        unassigned: filter.isUnassigned,
        search: search.isEmpty ? null : search,
      );

      state = AsyncData<FeedState>(
        FeedState(
          links: <LinkModel>[...current.links, ...result.links],
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData<FeedState>(current.copyWith(isLoadingMore: false));
    }
  }

  void updateLinkOptimistically(LinkModel updated) {
    final FeedState? current = state.value;
    if (current == null) return;
    final List<LinkModel> list = current.links.map((LinkModel link) {
      return link.id == updated.id ? updated : link;
    }).toList();
    state = AsyncData<FeedState>(current.copyWith(links: list));
  }

  void removeLinkOptimistically(int id) {
    final FeedState? current = state.value;
    if (current == null) return;
    final List<LinkModel> list =
        current.links.where((LinkModel link) => link.id != id).toList();
    state = AsyncData<FeedState>(current.copyWith(links: list));
  }
}

final AsyncNotifierProvider<FeedController, FeedState> feedProvider =
    AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);
