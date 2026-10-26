import 'dart:convert';

/// A user collection folder ("Koleksi").
///
/// Mirrors `collections` table rows returned by
/// `GET /api/v1/collections`, `POST /api/v1/auth/google` and friends.
class CollectionModel {
  const CollectionModel({
    required this.id,
    required this.name,
    this.userId,
    this.icon = 'folder',
    this.color = '#4F46E5',
    this.slug,
    this.isPublic = false,
    this.isDefault = false,
    this.sortOrder = 0,
    this.linksCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] == null ? null : (json['user_id'] as num).toInt(),
      name: (json['name'] as String? ?? '').trim(),
      icon: json['icon'] as String? ?? 'folder',
      color: json['color'] as String? ?? '#4F46E5',
      slug: json['slug'] as String?,
      isPublic: json['is_public'] == true,
      isDefault: json['is_default'] == true,
      sortOrder:
          json['sort_order'] == null ? 0 : (json['sort_order'] as num).toInt(),
      linksCount:
          json['links_count'] == null ? 0 : (json['links_count'] as num).toInt(),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final int? userId;
  final String name;

  /// Material icon key shared with the backend seeds (`shopping_bag`, ...).
  final String icon;
  final String color;

  /// Public share slug (`sengganglabs.my.id/tautin/c/{slug}`).
  final String? slug;
  final bool isPublic;
  final bool isDefault;
  final int sortOrder;

  /// Added by `withCount('links')` on the backend.
  final int linksCount;
  final String? createdAt;
  final String? updatedAt;

  CollectionModel copyWith({
    int? id,
    int? userId,
    String? name,
    String? icon,
    String? color,
    String? slug,
    bool? isPublic,
    bool? isDefault,
    int? sortOrder,
    int? linksCount,
    String? createdAt,
    String? updatedAt,
  }) {
    return CollectionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      slug: slug ?? this.slug,
      isPublic: isPublic ?? this.isPublic,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
      linksCount: linksCount ?? this.linksCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'slug': slug,
      'is_public': isPublic,
      'is_default': isDefault,
      'sort_order': sortOrder,
      'links_count': linksCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String encode() => jsonEncode(toJson());

  static CollectionModel decode(String source) =>
      CollectionModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  static List<String> encodeList(List<CollectionModel> collections) =>
      collections.map((CollectionModel c) => c.encode()).toList();

  static List<CollectionModel> decodeList(List<dynamic> raw) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CollectionModel.fromJson)
        .toList(growable: false);
  }

  @override
  String toString() => 'CollectionModel(id: $id, name: $name)';
}
