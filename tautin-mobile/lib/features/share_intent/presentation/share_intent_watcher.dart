import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../../core/router/app_router.dart';
import '../data/share_media_source.dart';

/// Root-level listener for Android share intents.
///
/// Subscribes to `ReceiveSharingIntent.instance.getInitialMedia()` (cold
/// start) and `getMediaStream()` (warm starts). Every consumed batch is
/// released via `reset()` so re-sharing the same text later still fires.
///
/// When a textual share arrives:
/// * user logged in  -> push `/share` which opens `QuickTautBottomSheet`;
/// * not logged in   -> the share is ignored (login gate by product design).
class ShareIntentWatcher extends ConsumerStatefulWidget {
  const ShareIntentWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShareIntentWatcher> createState() => _ShareIntentWatcherState();
}

class _ShareIntentWatcherState extends ConsumerState<ShareIntentWatcher> {
  StreamSubscription<List<SharedMediaFile>>? _streamSubscription;

  bool _isHandling = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final ShareMediaSource source = ref.read(shareMediaSourceProvider);

      final List<SharedMediaFile> initial = await source.getInitialMedia();
      await _handleMedia(initial);

      _streamSubscription = source.getMediaStream().listen(
        (List<SharedMediaFile> media) => unawaited(_handleMedia(media)),
        onError: (Object _) {
          // Platform channel hiccups must never crash the app shell.
        },
      );
    } on MissingPluginException {
      // Widget tests / non-Android hosts: quietly skip intent listening.
    } catch (_) {
      // Any platform-side failure falls back to normal app usage.
    }
  }

  Future<void> _handleMedia(List<SharedMediaFile> media) async {
    if (_isHandling) {
      return;
    }
    final String? sharedText = SharedMediaX.firstShareText(media);
    if (sharedText == null) {
      return;
    }

    _isHandling = true;
    try {
      await ref.read(shareMediaSourceProvider).reset();
    } catch (_) {
      // reset() is best-effort; consumed media is still handled below.
    }

    try {
      if (mounted) {
        final GoRouter router = GoRouter.of(context);
        final String currentLocation = router
            .routerDelegate
            .currentConfiguration
            .uri
            .toString();
        if (currentLocation != AppRoutes.quickShare) {
          router.push(AppRoutes.quickShare, extra: sharedText);
        }
      }
    } catch (_) {
      // Navigation races during shutdown are non-fatal.
    } finally {
      _isHandling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
