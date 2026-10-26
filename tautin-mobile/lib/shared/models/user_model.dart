import 'dart:convert';

import 'plan_type.dart';

/// Authenticated Tautin account.
///
/// Mirrors `users` rows serialized by `tautin-backend`
/// (`POST /api/v1/auth/google`, `GET /api/v1/auth/me`, ...).
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.googleId,
    this.avatar,
    this.planType = PlanType.free,
    this.planExpiresAt,
    this.aiQuotaLeft = 10,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      googleId: json['google_id'] as String?,
      avatar: json['avatar'] as String?,
      planType: PlanType.fromName(json['plan_type'] as String?),
      planExpiresAt: json['plan_expires_at'] as String?,
      aiQuotaLeft:
          json['ai_quota_left'] == null ? 10 : (json['ai_quota_left'] as num).toInt(),
      fcmToken: json['fcm_token'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String name;
  final String email;
  final String? googleId;
  final String? avatar;
  final PlanType planType;

  /// ISO-8601 timestamp or null (null also allowed for active `pro`).
  final String? planExpiresAt;

  /// Remaining fair-use AI quota for this month (10 free / 500 pro+).
  final int aiQuotaLeft;
  final String? fcmToken;
  final String? createdAt;
  final String? updatedAt;

  bool get isPro => planType.isProEntitled;

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? googleId,
    String? avatar,
    PlanType? planType,
    String? planExpiresAt,
    int? aiQuotaLeft,
    String? fcmToken,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      googleId: googleId ?? this.googleId,
      avatar: avatar ?? this.avatar,
      planType: planType ?? this.planType,
      planExpiresAt: planExpiresAt ?? this.planExpiresAt,
      aiQuotaLeft: aiQuotaLeft ?? this.aiQuotaLeft,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'google_id': googleId,
      'avatar': avatar,
      'plan_type': planType.name,
      'plan_expires_at': planExpiresAt,
      'ai_quota_left': aiQuotaLeft,
      'fcm_token': fcmToken,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String encode() => jsonEncode(toJson());

  static UserModel decode(String source) =>
      UserModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'UserModel(id: $id, email: $email)';
}
