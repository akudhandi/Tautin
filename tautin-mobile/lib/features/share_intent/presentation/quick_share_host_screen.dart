import 'package:flutter/material.dart';

import 'quick_taut_bottom_sheet.dart';

/// Route target for `/share`.
///
/// A transparent host (dimmed background) that presents the Quick Taut
/// sheet pinned to the bottom so the underlying app (TikTok/Shopee/Chrome)
/// stays visible while the save completes. Popping this route returns to
/// the previous app when launched from an external SEND intent.
class QuickShareHostScreen extends StatelessWidget {
  const QuickShareHostScreen({super.key, required this.sharedText});

  final String sharedText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: QuickTautBottomSheet(sharedText: sharedText),
      ),
    );
  }
}
