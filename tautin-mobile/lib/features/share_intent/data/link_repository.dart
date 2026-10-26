import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/link_model.dart';

/// Result of `POST /api/v1/links/quick-save`.
class QuickSaveOutcome {
  const QuickSaveOutcome({
    required this.link,
    required this.isDuplicate,
    this.message = '',
    this.aiQuotaLeft,
    this.planType,
  });

  final LinkModel link;

  /// true when the same URL already existed and got bumped to the top.
  final bool isDuplicate;
  final String message;
  final int? aiQuotaLeft;
  final String? planType;
}

/// Paginated link list result from `GET /api/v1/links`.
class PaginatedLinks {
  const PaginatedLinks({
    required this.links,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<LinkModel> links;
  final int currentPage;
  final int lastPage;
  final int total;
}

/// Contract for link operations across mobile app (Quick Taut, Home, Detail).
abstract interface class LinkRepository {
  Future<QuickSaveOutcome> quickSave({
    required String url,
    String? rawDescription,
    int? collectionId,
    String? userNotes,
  });

  Future<LinkModel> updateLink(
    int id, {
    int? collectionId,
    String? userNotes,
    bool? isPinned,
    bool? isRead,
    String? title,
    DateTime? remindAt,
  });

  Future<PaginatedLinks> fetchLinks({
    int page = 1,
    int? collectionId,
    bool unassigned = false,
    String? sourceType,
    String? tag,
    bool? isRead,
    String? search,
  });

  Future<List<LinkModel>> fetchResurface();

  Future<LinkModel> fetchLink(int id);

  Future<void> deleteLink(int id);

  Future<LinkModel> regenerateAi(int id);
}

/// HTTP implementation on top of the shared Dio client.
class TautinLinkRepository implements LinkRepository {
  TautinLinkRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<QuickSaveOutcome> quickSave({
    required String url,
    String? rawDescription,
    int? collectionId,
    String? userNotes,
  }) async {
    final Response<dynamic> response = await _dio.post<Object?>(
      '/links/quick-save',
      data: <String, dynamic>{
        'url': url,
        if (rawDescription != null && rawDescription.isNotEmpty)
          'raw_description': rawDescription,
        if (collectionId != null) 'collection_id': collectionId,
        if (userNotes != null && userNotes.isNotEmpty) 'user_notes': userNotes,
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);

    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();

    return QuickSaveOutcome(
      link: LinkModel.fromJson(data),
      isDuplicate: envelope.metaIsDuplicate,
      message: envelope.message,
      aiQuotaLeft: envelope.metaAiQuotaLeft,
      planType: envelope.metaPlanType,
    );
  }

  @override
  Future<LinkModel> updateLink(
    int id, {
    int? collectionId,
    String? userNotes,
    bool? isPinned,
    bool? isRead,
    String? title,
    DateTime? remindAt,
  }) async {
    final Response<dynamic> response = await _dio.patch<Object?>(
      '/links/$id',
      data: <String, dynamic>{
        if (collectionId != null) 'collection_id': collectionId,
        if (userNotes != null) 'user_notes': userNotes,
        if (isPinned != null) 'is_pinned': isPinned,
        if (isRead != null) 'is_read': isRead,
        if (title != null) 'title': title,
        if (remindAt != null) 'remind_at': remindAt.toIso8601String(),
      },
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    return LinkModel.fromJson(data);
  }

  @override
  Future<PaginatedLinks> fetchLinks({
    int page = 1,
    int? collectionId,
    bool unassigned = false,
    String? sourceType,
    String? tag,
    bool? isRead,
    String? search,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      if (unassigned)
        'collection_id': 'unassigned'
      else if (collectionId != null)
        'collection_id': collectionId,
      if (sourceType != null && sourceType.isNotEmpty) 'source_type': sourceType,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (isRead != null) 'is_read': isRead ? 1 : 0,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final Response<dynamic> response = await _dio.get<Object?>(
      '/links',
      queryParameters: query,
    );

    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();

    final List<dynamic> items = data['data'] as List<dynamic>? ?? <dynamic>[];
    final List<LinkModel> links = items
        .map((dynamic item) =>
            LinkModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();

    return PaginatedLinks(
      links: links,
      currentPage: data['current_page'] as int? ?? 1,
      lastPage: data['last_page'] as int? ?? 1,
      total: data['total'] as int? ?? links.length,
    );
  }

  @override
  Future<List<LinkModel>> fetchResurface() async {
    final Response<dynamic> response = await _dio.get<Object?>('/links/resurface');
    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final List<dynamic> items =
        envelope.data as List<dynamic>? ?? <dynamic>[];
    return items
        .map((dynamic item) =>
            LinkModel.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<LinkModel> fetchLink(int id) async {
    final Response<dynamic> response = await _dio.get<Object?>('/links/$id');
    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    return LinkModel.fromJson(data);
  }

  @override
  Future<void> deleteLink(int id) async {
    final Response<dynamic> response = await _dio.delete<Object?>('/links/$id');
    ApiEnvelope.requireSuccess(response);
  }

  @override
  Future<LinkModel> regenerateAi(int id) async {
    final Response<dynamic> response =
        await _dio.post<Object?>('/links/$id/regenerate-ai');
    final ApiEnvelope envelope = ApiEnvelope.requireSuccess(response);
    final Map<String, dynamic> data =
        (envelope.data as Map? ?? <Object?, Object?>{}).cast<String, dynamic>();
    return LinkModel.fromJson(data);
  }
}

/// Overridable wiring for tests.
final Provider<LinkRepository> linkRepositoryProvider = Provider<LinkRepository>(
  (Ref ref) => TautinLinkRepository(dio: ref.watch(dioProvider)),
);
