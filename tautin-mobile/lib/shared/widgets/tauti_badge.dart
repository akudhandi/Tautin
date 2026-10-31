import 'package:flutter/material.dart';

import '../../core/theme/tautin_theme.dart';

/// The Tautin "flower + t" badge from `opendesign-tautin.html` (`badge()`).
///
/// The mockup renders nine circles (one big centre + eight petals) plus the
/// letter `t`. Two colourways exist:
///
/// * default — mint petals on a spruce (ink) badge, used on light surfaces;
/// * [inverted] — ink petals on a mint badge, used on dark surfaces.
class TautiBadge extends StatelessWidget {
  const TautiBadge({super.key, this.size = 36, this.inverted = false});

  final double size;

  /// Swaps the two colours as described above.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return TautinLogoIcon(
      size: size,
      petalColor: inverted ? TautinColors.mintAccent : TautinColors.brandTeal,
      letterColor: inverted ? TautinColors.brandTeal : TautinColors.mintAccent,
    );
  }
}
