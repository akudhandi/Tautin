import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/share_intent/data/offline_sync_service.dart';

/// Flushes the offline link queue whenever the app returns to the
/// foreground (Wi-Fi / data restored -> queued shares hit the server).
class OfflineFlushLifecycle extends ConsumerStatefulWidget {
  const OfflineFlushLifecycle({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineFlushLifecycle> createState() =>
      _OfflineFlushLifecycleState();
}

class _OfflineFlushLifecycleState extends ConsumerState<OfflineFlushLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_flushOnResume());
    }
  }

  Future<void> _flushOnResume() async {
    try {
      await ref.read(offlineSyncServiceProvider).flushPendingLinks();
    } catch (_) {
      // A failed flush simply keeps entries queued for the next resume.
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
