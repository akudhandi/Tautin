import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tautin_theme.dart';
import '../models/link_model.dart';

/// Formats a DateTime or ISO-8601 string into a friendly Indonesian relative time string.
String formatRelativeTime(dynamic dateTimeOrString) {
  DateTime? dateTime;
  if (dateTimeOrString is DateTime) {
    dateTime = dateTimeOrString;
  } else if (dateTimeOrString is String && dateTimeOrString.isNotEmpty) {
    dateTime = DateTime.tryParse(dateTimeOrString);
  }
  if (dateTime == null) {
    return 'baru saja';
  }
  final Duration diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) {
    return 'baru saja';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} menit lalu';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} jam lalu';
  } else if (diff.inDays < 7) {
    return '${diff.inDays} hari lalu';
  } else {
    return DateFormat('d MMM', 'id_ID').format(dateTime);
  }
}

/// Smart Link Card as defined in mockup design (Screen 3 - Beranda).
///
/// Features:
/// - Favicon/domain + relative time + pin indicator
/// - Thumbnail preview with video/e-commerce overlay badge
/// - Clean 2-line title
/// - AI Summary box (with shimmer while pending, or quota upsell banner)
/// - Collection chip + tags row
class SmartLinkCard extends StatelessWidget {
  const SmartLinkCard({
    super.key,
    required this.link,
    this.onTap,
    this.onOpen,
    this.onPinToggle,
    this.onQuotaBannerTap,
  });

  final LinkModel link;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onPinToggle;
  final VoidCallback? onQuotaBannerTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color cardBg = isDark ? TautinColors.darkCard : Colors.white;
    final Border border = link.isPinned
        ? Border.all(
            color: isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
            width: 2.5,
          )
        : (isDark
            ? Border.all(color: TautinColors.darkBorder)
            : Border.all(color: Colors.transparent));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(isDark ? 24 : 28),
        border: border,
        boxShadow: isDark
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: TautinColors.brandTeal.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isDark ? 24 : 28),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header row: Domain + relative time + pin status
                Row(
                  children: <Widget>[
                    Icon(
                      _iconForSource(link.sourceType),
                      size: 15,
                      color: isDark
                          ? TautinColors.textSecondaryDark
                          : TautinColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      link.domain,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: isDark ? 12 : 13,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatRelativeTime(link.updatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? TautinColors.textSecondaryDark
                            : TautinColors.seamTeal,
                      ),
                    ),
                    const Spacer(),
                    if (!link.isRead) ...<Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.brandTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // Thumbnail (if available)
                if (link.thumbnailUrl != null &&
                    link.thumbnailUrl!.trim().isNotEmpty) ...<Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: CachedNetworkImage(
                            imageUrl: link.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark
                                  ? TautinColors.darkBackground
                                  : TautinColors.creamBackground,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: isDark
                                  ? TautinColors.darkBackground
                                  : TautinColors.creamBackground,
                              child: const Center(
                                child: Icon(Icons.broken_image_rounded, size: 28),
                              ),
                            ),
                          ),
                        ),
                        if (link.sourceType == 'video')
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        if (link.sourceType == 'ecommerce')
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: TautinColors.brandTeal,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Produk',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Title
                Text(
                  link.title?.trim().isNotEmpty == true
                      ? link.title!
                      : link.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: isDark ? 15 : 16.5,
                    height: 1.25,
                    letterSpacing: -0.01,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                ),
                const SizedBox(height: 10),

                // AI Summary / Pending Shimmer / Quota Banner
                _buildSummarySection(context, isDark),
                const SizedBox(height: 10),

                // Footer row: Collection label + tags
                Row(
                  children: <Widget>[
                    if (link.collection != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? TautinColors.mossAltDark
                              : TautinColors.iceBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.folder_outlined,
                              size: 13,
                              color: isDark
                                  ? TautinColors.iceBlue
                                  : TautinColors.brandTeal,
                            ),
                            const SizedBox(width: 5),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                link.collection!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? TautinColors.iceBlue
                                      : TautinColors.brandTeal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final tag in link.tags)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  '#${tag.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? TautinColors.textSecondaryDark
                                        : TautinColors.seamTeal,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Actions row (.lc-act): Buka tautan & Pin button
                const SizedBox(height: 12),
                _buildActionButtons(context, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    // Buka Tautan styling (.btn-open)
    final Color openBg;
    final Color openText;
    Border? openBorder;

    if (isDark) {
      if (link.isRead) {
        openBg = TautinColors.darkCard;
        openText = TautinColors.creamBackground;
        openBorder = Border.all(color: TautinColors.darkBorder);
      } else {
        openBg = TautinColors.mintAccent;
        openText = TautinColors.brandTeal;
      }
    } else {
      if (link.isRead) {
        openBg = TautinColors.mintAccent;
        openText = TautinColors.brandTeal;
      } else {
        openBg = TautinColors.brandTeal;
        openText = TautinColors.creamBackground;
      }
    }

    // Pin button styling (.btn-pin)
    final Color pinBg;
    final Color pinColor;
    Border? pinBorder;

    if (isDark) {
      if (link.isPinned) {
        pinBg = TautinColors.mintAccent;
        pinColor = TautinColors.brandTeal;
      } else {
        pinBg = TautinColors.darkCard;
        pinColor = TautinColors.textSecondaryDark;
        pinBorder = Border.all(color: TautinColors.darkBorder);
      }
    } else {
      if (link.isPinned) {
        pinBg = TautinColors.brandTeal;
        pinColor = TautinColors.creamBackground;
      } else {
        pinBg = TautinColors.creamBackground;
        pinColor = TautinColors.brandTeal;
      }
    }

    return Row(
      children: <Widget>[
        // 1. Buka Tautan button
        Expanded(
          child: InkWell(
            onTap: onOpen ?? onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: openBg,
                borderRadius: BorderRadius.circular(22),
                border: openBorder,
              ),
              child: Text(
                link.isRead ? 'Buka tautan' : 'Buka & baca',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: openText,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Pin button
        InkWell(
          onTap: onPinToggle,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pinBg,
              borderRadius: BorderRadius.circular(22),
              border: pinBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: pinColor,
                ),
                const SizedBox(width: 5),
                Text(
                  link.isPinned ? 'Tersemat' : 'Sematkan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: pinColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context, bool isDark) {
    final ThemeData theme = Theme.of(context);

    // 1. Pending / Processing state -> Shimmer effect
    // Light mockup: `.ai.pending { background: linear-gradient(90deg,#CAFFA6,
    // #E6FFD3,#CAFFA6) }`; dark equivalent reuses the moss dark surface.
    if (link.isPending) {
      return Shimmer.fromColors(
        baseColor: isDark ? TautinColors.mossDark : TautinColors.mintAccent,
        highlightColor: isDark
            ? TautinColors.mossAltDark
            : const Color(0xFFE6FFD3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? TautinColors.mossDark : TautinColors.mintAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome,
                size: 16,
                color: TautinColors.brandTeal,
              ),
              const SizedBox(width: 8),
              Text(
                '✨ AI sedang merangkum tautan ini...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: TautinColors.brandTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Completed with summary -> AI summary box.
    // Light `.ai { background: #CAFFA6 }`, dark `.dkai { background: #25452F }`,
    // neither has a hairline; `.dkai-h` is mint, `.dkai-b` is `#D6E6EA`.
    if (link.aiSummary != null && link.aiSummary!.trim().isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? TautinColors.mossDark : TautinColors.mintAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: isDark
                      ? TautinColors.mintAccent
                      : TautinColors.brandTeal,
                ),
                const SizedBox(width: 5),
                Text(
                  'Ringkasan AI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? TautinColors.mintAccent
                        : TautinColors.brandTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              link.aiSummary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: isDark
                    ? TautinColors.aiSummaryBodyDark
                    : TautinColors.aiSummaryBodyLight,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Completed but aiSummary == null -> Quota exhausted upsell banner
    return InkWell(
      onTap: onQuotaBannerTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: TautinColors.mintAccent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: TautinColors.mintAccent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppConfig.aiQuotaExhaustedBanner,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: TautinColors.brandTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: TautinColors.brandTeal,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForSource(String? sourceType) {
    switch (sourceType) {
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'ecommerce':
        return Icons.shopping_bag_outlined;
      case 'article':
        return Icons.article_outlined;
      case 'social':
        return Icons.alternate_email_rounded;
      default:
        return Icons.link_rounded;
    }
  }
}
