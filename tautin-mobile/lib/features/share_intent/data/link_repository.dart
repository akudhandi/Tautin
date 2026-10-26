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

/// Contract for authoring/update of links used by the Quick Taut sheet.
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
  });
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
  }) async {
    final Response<dynamic> response = await _dio.patch<Object?>(
      '/links/$id',
      data: <String, dynamic>{
        if (collectionId != null) 'collection_id': collectionId,
        if (userNotes != null) 'user_notes': userNotes,
        if (isPinned != null) 'is_pinned': isPinned,
        if (isRead != null) 'is_read': isRead,
        if (title != null) 'title': title,
      },
    );

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
