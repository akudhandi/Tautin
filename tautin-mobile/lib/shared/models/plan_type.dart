/// Subscription / account plan of the authenticated user.
enum PlanType {
  free,
  pro,
  lifetime;

  /// Whether the plan grants Pro entitlements at the moment of call.
  ///
  /// Matches the Laravel `User::isPro()` semantics: `lifetime` is always Pro,
  /// and `pro` stays Pro while `plan_expires_at` is in the future (a null
  /// value means "never expires").
  bool get isProEntitled {
    return this == PlanType.lifetime || this == PlanType.pro;
  }

  static PlanType fromName(String? raw) {
    switch (raw) {
      case 'pro':
        return PlanType.pro;
      case 'lifetime':
        return PlanType.lifetime;
      default:
        return PlanType.free;
    }
  }

  String get uiLabel {
    return switch (this) {
      PlanType.free => 'Gratis',
      PlanType.pro => 'Pro',
      PlanType.lifetime => 'Lifetime',
    };
  }
}
