import 'dart:convert';

/// A single AI keyword tag attached to a link by Gemini.
///
/// Mirrors the `tags` rows of `tautin-backend` (`tags` table).
class TagModel {
  const TagModel({
    required this.id,
    required this.name,
    this.userId,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String? ?? '').trim(),
      userId: json['user_id'] == null ? null : (json['user_id'] as num).toInt(),
    );
  }

  final int id;
  final int? userId;
  final String name;

  TagModel copyWith({int? id, int? userId, String? name}) {
    return TagModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'user_id': userId,
    };
  }

  String encode() => jsonEncode(toJson());

  static TagModel decode(String source) =>
      TagModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'TagModel(id: $id, name: $name)';
}

/// Parses a list of tag maps coming from the API.
List<TagModel> parseTagList(dynamic raw) {
  if (raw is! List) {
    return <TagModel>[];
  }
  return raw
      .whereType<Map<String, dynamic>>()
      .map(TagModel.fromJson)
      .toList(growable: false);
}
