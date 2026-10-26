/// Application environment configuration.
///
/// Values are injected at build time via `--dart-define` so the same binary
/// can target emulator (10.0.2.2), LAN device, or production servers.
class AppConfig {
  AppConfig._();

  /// REST API base URL. Points to the local Laravel host by default
  /// (`10.0.2.2` resolves to the host machine from an Android emulator).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Google OAuth Web Client ID of the Laravel backend.
  /// Required so `google_sign_in` returns an `id_token` audience the
  /// backend can verify against `GOOGLE_CLIENT_ID`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Host used by Android App Links (public collection viewer).
  static const String appLinksHost = 'www.sengganglabs.my.id';
  static const String appLinksPathPrefix = '/tautin/c/';

  /// Default collection chip shown first in the Quick Taut bottom sheet.
  static const String aiAutoCollectionChip = '✨ Otomatis oleh AI';

  /// Quick Taut auto close countdown (spec: opens app < 2 seconds).
  static const Duration quickTautCountdown = Duration(seconds: 2);

  /// Package name used by Google Play Billing.
  static const String packageName = 'id.my.sengganglabs.tautin';
}
