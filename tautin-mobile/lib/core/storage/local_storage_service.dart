import 'dart:convert';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../shared/models/collection_model.dart';
import '../../shared/models/plan_type.dart';
import '../../shared/models/user_model.dart';

/// Canonical Hive box names (see ARCHITECTURE section 6.3).
const String kAuthBox = 'authBox';
const String kCollectionsCacheBox = 'collectionsCacheBox';
const String kOfflineLinksQueueBox = 'offlineLinksQueueBox';

const String _kTokenKey = 'sanctum_token';
const String _kUserKey = 'user_profile';

const String _kCollectionsKey = 'collections';

const String _kQueueEntriesKey = 'entries';

/// Low-friction local storage built on three Hive boxes:
///
/// 1. `authBox` — Sanctum token + mirrored profile (`plan_type`,
///    `ai_quota_left`).
/// 2. `collectionsCacheBox` — cached collection list so the
///    Quick Taut bottom sheet can render folders in ~0ms.
/// 3. `offlineLinksQueueBox` — links shared while the device was offline.
class LocalStorage {
  LocalStorage({
    required Box<dynamic> authBox,
    required Box<dynamic> collectionsBox,
    required Box<dynamic> offlineQueueBox,
  }) : _authBox = authBox,
       _collectionsBox = collectionsBox,
       _offlineQueueBox = offlineQueueBox;

  /// Opens the three boxes. Call once from `main()` (or bootstrapped in tests
  /// with `Hive.init(tempDir)` instead of the flutter variant).
  static Future<LocalStorage> init() async {
    await Hive.initFlutter();
    return openBoxes();
  }

  static Future<LocalStorage> openBoxes() async {
    final Box<dynamic> auth = await Hive.openBox<dynamic>(kAuthBox);
    final Box<dynamic> collections =
        await Hive.openBox<dynamic>(kCollectionsCacheBox);
    final Box<dynamic> offline =
        await Hive.openBox<dynamic>(kOfflineLinksQueueBox);

    return LocalStorage(
      authBox: auth,
      collectionsBox: collections,
      offlineQueueBox: offline,
    );
  }

  final Box<dynamic> _authBox;
  final Box<dynamic> _collectionsBox;
  final Box<dynamic> _offlineQueueBox;

  /// Monotonic counter so queue ids stay unique even when
  /// `DateTime.now()` returns the same coarse tick twice in a row
  /// (observed on Windows when two enqueues happen back-to-back).
  int _offlineEntrySeq = 0;

  String _nextOfflineEntryId() {
    _offlineEntrySeq += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_offlineEntrySeq';
  }

  bool get isAuthBoxOpen => _authBox.isOpen;

  // -------------------------------------------------------------------------
  // authBox: Sanctum token
  // -------------------------------------------------------------------------

  String? get sanctumToken => _authBox.get(_kTokenKey) as String?;

  bool get hasSession => (sanctumToken ?? '').isNotEmpty;

  void saveSanctumToken(String token) => _authBox.put(_kTokenKey, token);

  void clearSanctumToken() => _authBox.delete(_kTokenKey);

  // -------------------------------------------------------------------------
  // authBox: mirrored user profile
  // -------------------------------------------------------------------------

  UserModel? get user {
    final dynamic raw = _authBox.get(_kUserKey);
    if (raw is Map && raw.isNotEmpty) {
      return UserModel.fromJson(raw.cast<String, dynamic>());
    }
    return null;
  }

  void saveUser(UserModel user) => _authBox.put(_kUserKey, user.toJson());

  /// Merges fresh quota / plan values delivered through `meta` envelopes
  /// (`ai_quota_left`, `plan_type`) without discarding other profile fields.
  void updateUserQuota({int? aiQuotaLeft, PlanType? planType}) {
    final UserModel? current = user;
    if (current == null) {
      return;
    }
    saveUser(
      current.copyWith(
        aiQuotaLeft: aiQuotaLeft ?? current.aiQuotaLeft,
        planType: planType ?? current.planType,
      ),
    );
  }

  void clearUser() => _authBox.delete(_kUserKey);

  /// Clears session + profile (logout / account deletion).
  Future<void> clearSession() async {
    await _authBox.clear();
  }

  // -------------------------------------------------------------------------
  // collectionsCacheBox
  // -------------------------------------------------------------------------

  List<CollectionModel> loadCollections() {
    final dynamic raw = _collectionsBox.get(_kCollectionsKey);
    if (raw is! List) {
      return <CollectionModel>[];
    }
    try {
      return CollectionModel.decodeList(
        raw
            .map(
              (dynamic e) =>
                  e is String ? jsonDecode(e) as Map<String, dynamic> : e,
            )
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
    } on FormatException {
      return <CollectionModel>[];
    }
  }

  Future<void> saveCollections(List<CollectionModel> collections) {
    return _collectionsBox.put(
      _kCollectionsKey,
      collections.map((CollectionModel c) => c.toJson()).toList(),
    );
  }

  Future<void> clearCollections() => _collectionsBox.clear();

  // -------------------------------------------------------------------------
  // offlineLinksQueueBox
  // -------------------------------------------------------------------------

  /// Queues one quick-save payload for later processing (offline share).
  ///
  /// Each entry holds `{'id': id, 'payload': <quick-save body>}`.
  Future<String> enqueueOfflineLink({
    required Map<String, dynamic> payload,
  }) async {
    final String id = _nextOfflineEntryId();
    final List<dynamic> entries =
        (_offlineQueueBox.get(_kQueueEntriesKey) as List<dynamic>?) ?? <dynamic>[];
    final List<Map<String, dynamic>> mutable =
        entries.cast<Map<String, dynamic>>().map(_castEntry).toList();
    mutable.add(<String, dynamic>{'id': id, 'payload': payload});
    await _offlineQueueBox.put(_kQueueEntriesKey, mutable);

    return id;
  }

  Map<String, dynamic> _castEntry(dynamic entry) {
    if (entry is Map<String, dynamic>) {
      return entry;
    }
    return (entry as Map).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> readOfflineQueue() {
    final dynamic raw = _offlineQueueBox.get(_kQueueEntriesKey);
    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }
    return raw
        .map(_castEntry)
        .where((Map<String, dynamic> entry) => entry['payload'] is Map)
        .toList(growable: false);
  }

  int get pendingOfflineCount => readOfflineQueue().length;

  /// Removes a successfully synced entry by id.
  Future<void> removeOfflineEntry(String id) async {
    final List<Map<String, dynamic>> entries = _filterEntries(
      (_offlineQueueBox.get(_kQueueEntriesKey) as List<dynamic>?) ?? <dynamic>[],
    );
    entries.removeWhere((Map<String, dynamic> entry) => entry['id'] == id);
    await _offlineQueueBox.put(_kQueueEntriesKey, entries);
  }

  /// `payload` of a queue entry as a ready-to-send quick-save request.
  static Map<String, dynamic> quickSavePayloadOf(
    Map<String, dynamic> queueEntry,
  ) {
    final dynamic payload = queueEntry['payload'];
    return payload is Map<String, dynamic>
        ? payload
        : (payload as Map? ?? <String, dynamic>{}).cast<String, dynamic>();
  }

  List<Map<String, dynamic>> _filterEntries(List<dynamic> rawEntries) {
    return rawEntries
        .map(_castEntry)
        .where((Map<String, dynamic> entry) => entry['payload'] is Map)
        .toList();
  }

  Future<void> clearOfflineQueue() => _offlineQueueBox.clear();

  // -------------------------------------------------------------------------

  /// Wipes all boxes (used by unit tests and account deletion flows).
  Future<void> clearAll() async {
    await Future.wait<void>(<Future<void>>[
      _authBox.clear(),
      _collectionsBox.clear(),
      _offlineQueueBox.clear(),
    ]);
  }

  /// Deletes the backing files (used by tests when recreating fixtures).
  static void deleteTestBoxes(String tempDir) {
    final Directory dir = Directory(tempDir);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}
