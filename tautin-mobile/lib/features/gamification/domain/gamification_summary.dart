import 'package:flutter/foundation.dart';

/// Single mission payload from `GET /api/v1/gamification/summary`.
@immutable
class MissionModel {
  const MissionModel({
    required this.key,
    required this.label,
    required this.periodType,
    required this.progress,
    required this.target,
    required this.xpReward,
    required this.isCompleted,
  });

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      periodType: json['period_type'] as String? ?? 'daily',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 1,
      xpReward: (json['xp_reward'] as num?)?.toInt() ?? 20,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  final String key;
  final String label;
  final String periodType;
  final int progress;
  final int target;
  final int xpReward;
  final bool isCompleted;

  double get percent => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  MissionModel copyWith({
    String? key,
    String? label,
    String? periodType,
    int? progress,
    int? target,
    int? xpReward,
    bool? isCompleted,
  }) {
    return MissionModel(
      key: key ?? this.key,
      label: label ?? this.label,
      periodType: periodType ?? this.periodType,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      xpReward: xpReward ?? this.xpReward,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Server-side gamification state (PRD FR-GAME-01, FR-GAME-02).
@immutable
class GamificationSummary {
  const GamificationSummary({
    required this.xp,
    required this.level,
    required this.title,
    required this.streakDays,
    required this.xpToNextLevel,
    required this.levelProgressPercent,
    required this.missions,
  });

  factory GamificationSummary.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawMissions = json['missions'] as List<dynamic>? ?? <dynamic>[];
    return GamificationSummary(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Pemula Tautan',
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      xpToNextLevel: (json['xp_to_next_level'] as num?)?.toInt() ?? 100,
      levelProgressPercent:
          (json['level_progress_percent'] as num?)?.toInt() ?? 0,
      missions: rawMissions
          .whereType<Map<String, dynamic>>()
          .map(MissionModel.fromJson)
          .toList(growable: false),
    );
  }

  /// Default baseline matching mockup values when offline/unauthenticated.
  factory GamificationSummary.initial() {
    return const GamificationSummary(
      xp: 40,
      level: 3,
      title: 'Pemungut Tautan',
      streakDays: 5,
      xpToNextLevel: 60,
      levelProgressPercent: 40,
      missions: <MissionModel>[
        MissionModel(
          key: 'daily_save_3',
          label: 'Simpan 3 tautan',
          periodType: 'daily',
          progress: 2,
          target: 3,
          xpReward: 20,
          isCompleted: false,
        ),
        MissionModel(
          key: 'daily_read_1',
          label: 'Baca 1 tautan',
          periodType: 'daily',
          progress: 0,
          target: 1,
          xpReward: 20,
          isCompleted: false,
        ),
      ],
    );
  }

  final int xp;
  final int level;
  final String title;
  final int streakDays;
  final int xpToNextLevel;
  final int levelProgressPercent;
  final List<MissionModel> missions;

  /// Current XP step progress: `xp % 100` (e.g. 40 in 40/100 XP).
  int get currentStepXp {
    final int step = 100;
    return xp % step;
  }

  /// Target of the current level step (always 100 per PRD).
  int get stepTarget => 100;

  double get progressFraction =>
      (levelProgressPercent / 100.0).clamp(0.0, 1.0);
}
