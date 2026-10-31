import 'package:flutter/material.dart';

import '../../../../core/theme/tautin_theme.dart';
import '../../domain/gamification_summary.dart';

/// Modal bottom sheet that shows the user's active missions and streak.
/// Opens when tapping the `Misi` chip on the mascot card.
class MissionsModalSheet extends StatelessWidget {
  const MissionsModalSheet({
    super.key,
    required this.summary,
  });

  final GamificationSummary summary;

  static Future<void> show(
    BuildContext context, {
    required GamificationSummary summary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => MissionsModalSheet(summary: summary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg =
        isDark ? TautinColors.darkCard : TautinColors.creamBackground;
    final Color primary =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;
    final Color secondary =
        isDark ? TautinColors.textSecondaryDark : TautinColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? TautinColors.seamTeal : TautinColors.mistTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header: Misi & Progres + Streak badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Misi & Progres',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selesaikan misi untuk mendapatkan XP tambahan.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TautinColors.brandTeal,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        '🔥 ',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${summary.streakDays} hari',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: TautinColors.mintAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mission items
            ...summary.missions.map((MissionModel m) => _MissionTile(
                  mission: m,
                  isDark: isDark,
                )),

            // Pro tease (Pasang pengingat)
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? TautinColors.darkBorder
                      : TautinColors.brandTeal.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pasang pengingat jadwal kustom',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: TautinColors.brandTeal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        color: TautinColors.mintAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.isDark,
  });

  final MissionModel mission;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bool done = mission.isCompleted;
    final Color primary =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: done
              ? (isDark ? TautinColors.mossDark : TautinColors.mintAccent)
              : (isDark ? TautinColors.mossAltDark : Colors.white),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done
                    ? TautinColors.brandTeal
                    : (isDark
                        ? TautinColors.darkBorder
                        : TautinColors.creamBackground),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: TautinColors.mintAccent,
                    )
                  : Text(
                      '+${mission.xpReward}',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: isDark
                            ? TautinColors.mintAccent
                            : TautinColors.brandTeal,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mission.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: done && !isDark
                          ? TautinColors.brandTeal
                          : primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? 'Selesai · +${mission.xpReward} XP diperoleh'
                        : '${mission.progress} dari ${mission.target} selesai · +${mission.xpReward} XP',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: done && !isDark
                          ? TautinColors.brandTeal.withValues(alpha: 0.8)
                          : (isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.textSecondaryLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: done
                    ? TautinColors.brandTeal
                    : (isDark
                        ? TautinColors.darkCard
                        : TautinColors.creamBackground),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                done
                    ? '100%'
                    : '${mission.progress}/${mission.target}',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: done
                      ? TautinColors.mintAccent
                      : (isDark
                          ? TautinColors.textPrimaryDark
                          : TautinColors.brandTeal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
