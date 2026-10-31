import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gamification_repository.dart';
import '../domain/gamification_summary.dart';

/// Fetches `GET /api/v1/gamification/summary` on Beranda load.
/// Falls back to [GamificationSummary.initial] so the mascot card always shows.
final FutureProvider<GamificationSummary> gamificationSummaryProvider =
    FutureProvider<GamificationSummary>((Ref ref) async {
  final GamificationRepository repo =
      ref.watch(gamificationRepositoryProvider);
  try {
    return await repo.fetchSummary();
  } catch (_) {
    return GamificationSummary.initial();
  }
});
