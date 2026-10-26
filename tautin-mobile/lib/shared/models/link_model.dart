import 'dart:convert';

import 'collection_model.dart';
import 'tag_model.dart';

/// A saved Tautin link.
///
/// Mirrors `links` rows serialized by `tautin-backend`
/// (`POST /api/v1/links/quick-save`, `GET /api/v1/links`, ...). Includes the
/// optionally eager-loaded `collection` and `tags` relationships.
class LinkModel {
  const LinkModel({
    required this.id,
    required this.userId,
    required this.url,
    required this.urlHash,
    required this.domain,
    this.collectionId,
    this.sourceType = 'other',
    this.title,
    this.thumbnailUrl,
    this.rawDescription,
    this.aiSummary,
    this.userNotes,
    this.status = 'pending',
    this.isAiProcessed = false,
    this.isPinned = false,
    this.isRead = false,
    this.remindAt,
    this.reminderSent = false,
    this.collection,
    this.tags = const <TagModel>[],
    this.createdAt,
    this.updatedAt,
  });

  factory LinkModel.fromJson(Map<String, dynamic> json) {
    final dynamic collection = json['collection'];

    return LinkModel(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      collectionId:
          json['collection_id'] == null
              ? null
              : (json['collection_id'] as num).toInt(),
      url: json['url'] as String? ?? '',
      urlHash: json['url_hash'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? 'other',
      title: json['title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      rawDescription: json['raw_description'] as String?,
      aiSummary: json['ai_summary'] as String?,
      userNotes: json['user_notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      isAiProcessed: json['is_ai_processed'] == true,
      isPinned: json['is_pinned'] == true,
      isRead: json['is_read'] == true,
      remindAt: json['remind_at'] as String?,
      reminderSent: json['reminder_sent'] == true,
      collection:
          collection is Map<String, dynamic>
              ? CollectionModel.fromJson(collection)
              : null,
      tags: parseTagList(json['tags']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final int userId;
  final int? collectionId;
  final String url;

  /// SHA-256 of the canonical URL (server-side de-duplication key).
  final String urlHash;
  final String domain;

  /// One of: `video`, `ecommerce`, `article`, `social`, `other`.
  final String sourceType;
  final String? title;
  final String? thumbnailUrl;
  final String? rawDescription;
  final String? aiSummary;
  final String? userNotes;

  /// One of: `pending`, `processing`, `completed`, `failed`.
  final String status;
  final bool isAiProcessed;
  final bool isPinned;
  final bool isRead;
  final String? remindAt;
  final bool reminderSent;
  final CollectionModel? collection;
  final List<TagModel> tags;
  final String? createdAt;
  final String? updatedAt;

  bool get isPending => status == 'pending' || status == 'processing';

  bool get isCompleted => status == 'completed';

  LinkModel copyWith({
    int? id,
    int? userId,
    int? collectionId,
    String? url,
    String? urlHash,
    String? domain,
    String? sourceType,
    String? title,
    String? thumbnailUrl,
    String? rawDescription,
    String? aiSummary,
    String? userNotes,
    String? status,
    bool? isAiProcessed,
    bool? isPinned,
    bool? isRead,
    String? remindAt,
    bool? reminderSent,
    CollectionModel? collection,
    List<TagModel>? tags,
    String? createdAt,
    String? updatedAt,
  }) {
    return LinkModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      collectionId: collectionId ?? this.collectionId,
      url: url ?? this.url,
      urlHash: urlHash ?? this.urlHash,
      domain: domain ?? this.domain,
      sourceType: sourceType ?? this.sourceType,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      rawDescription: rawDescription ?? this.rawDescription,
      aiSummary: aiSummary ?? this.aiSummary,
      userNotes: userNotes ?? this.userNotes,
      status: status ?? this.status,
      isAiProcessed: isAiProcessed ?? this.isAiProcessed,
      isPinned: isPinned ?? this.isPinned,
      isRead: isRead ?? this.isRead,
      remindAt: remindAt ?? this.remindAt,
      reminderSent: reminderSent ?? this.reminderSent,
      collection: collection ?? this.collection,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'collection_id': collectionId,
      'url': url,
      'url_hash': urlHash,
      'domain': domain,
      'source_type': sourceType,
      'title': title,
      'thumbnail_url': thumbnailUrl,
      'raw_description': rawDescription,
      'ai_summary': aiSummary,
      'user_notes': userNotes,
      'status': status,
      'is_ai_processed': isAiProcessed,
      'is_pinned': isPinned,
      'is_read': isRead,
      'remind_at': remindAt,
      'reminder_sent': reminderSent,
      'collection': collection?.toJson(),
      'tags': tags.map((TagModel t) => t.toJson()).toList(),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String encode() => jsonEncode(toJson());

  static LinkModel decode(String source) =>
      LinkModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'LinkModel(id: $id, url: $url)';
}
