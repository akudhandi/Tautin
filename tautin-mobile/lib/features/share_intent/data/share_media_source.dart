import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Abstraction over `receive_sharing_intent` so both production and widget
/// tests depend on a swappable interface.
abstract interface class ShareMediaSource {
  Future<List<SharedMediaFile>> getInitialMedia();
  Stream<List<SharedMediaFile>> getMediaStream();
  Future<void> reset();
}

/// Live implementation bound to `ReceiveSharingIntent.instance`.
class ReceiveSharingIntentSource implements ShareMediaSource {
  const ReceiveSharingIntentSource();

  @override
  Future<List<SharedMediaFile>> getInitialMedia() =>
      ReceiveSharingIntent.instance.getInitialMedia();

  @override
  Stream<List<SharedMediaFile>> getMediaStream() =>
      ReceiveSharingIntent.instance.getMediaStream();

  @override
  Future<void> reset() => ReceiveSharingIntent.instance.reset();
}

/// Shared text reducers for incoming Android share intents.
abstract final class SharedMediaX {
  /// Picks the first shared TEXT/URL payload within [media].
  ///
  /// Returns the raw shared text, or null when nothing textual arrived.
  static String? firstShareText(List<SharedMediaFile> media) {
    for (final SharedMediaFile item in media) {
      final bool textual = item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url;
      if (textual && item.path.trim().isNotEmpty) {
        return item.path;
      }
    }
    return null;
  }
}

/// Top-level wiring; widget tests override this with a scripted source.
final Provider<ShareMediaSource> shareMediaSourceProvider =
    Provider<ShareMediaSource>((_) => const ReceiveSharingIntentSource());
