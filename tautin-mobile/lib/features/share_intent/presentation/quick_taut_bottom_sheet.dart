import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/storage_provider.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/models/user_model.dart';
import '../data/link_repository.dart';
import '../domain/dirty_url_parser.dart';

/// State machine of the Quick Taut sheet used for header styling.
enum QuickTautStatus {
  /// Extracting URL / initial phase before any request result.
  idle,

  /// quick-save in flight ("Menyimpan tautan...").
  submitting,

  /// Saved online (duplicate or fresh).
  saved,

  /// Connection failed — payload parked in the offline queue.
  savedOffline,

  /// No usable URL found in the shared text (or other visible failure).
  error,
}

/// "Quick Taut" share sheet.
///
/// Flow per FR-SAVE-03 / Mockup Screen 2 & Screen 31:
/// 1. Opens, renders folders from `collectionsCacheBox` in ~0ms and
///    auto-fires `POST /links/quick-save` with "✨ Otomatis oleh AI".
/// 2. Shows a 2-second countdown bar; when it finishes untouched the sheet
///    closes (or the whole task exits via [SystemNavigator.pop] when the
///    app was launched from an external share intent).
/// 3. Touching a collection chip or "Tambah Catatan" cancels the
///    auto-close and PATCHes the choice on `links/{id}`.
/// 4. `meta.is_duplicate == true` surfaces the "sudah ada" message.
/// 5. Connection errors park the payload into the offline queue.
class QuickTautBottomSheet extends ConsumerStatefulWidget {
  const QuickTautBottomSheet({
    super.key,
    required this.sharedText,
    this.fromExternalIntent = false,
  });

  /// Raw dirty text captured from the Android share sheet.
  final String sharedText;

  /// True when the app task was created by the SEND intent (cold start).
  final bool fromExternalIntent;

  @override
  ConsumerState<QuickTautBottomSheet> createState() =>
      _QuickTautBottomSheetState();
}

class _QuickTautBottomSheetState extends ConsumerState<QuickTautBottomSheet> {
  static const int _countdownSteps = 40; // 2s / 50ms

  Timer? _autoCloseTimer;

  QuickTautStatus _status = QuickTautStatus.idle;
  String _message = '';
  LinkModel? _savedLink;
  int? _selectedCollectionId;
  bool _autoCloseCanceled = false;
  double _countdownProgress = 0;

  ParsedShareInput? _parsed;

  int _aiQuotaLeft = 10;
  bool _isPro = false;

  bool _noteEditorOpen = false;
  final TextEditingController _noteController = TextEditingController();

  LocalStorage get _storage => ref.read(localStorageProvider);

  LinkRepository get _links => ref.read(linkRepositoryProvider);

  bool get _countdownActive =>
      !_autoCloseCanceled &&
      (_status == QuickTautStatus.submitting ||
          _status == QuickTautStatus.saved);

  @override
  void initState() {
    super.initState();
    final UserModel? initial = _storage.user;
    _aiQuotaLeft = initial?.aiQuotaLeft ?? 10;
    _isPro = initial?.isPro ?? false;
    _parsed = DirtyUrlParser.parse(widget.sharedText);
    if (_parsed == null) {
      _status = QuickTautStatus.error;
      _message = 'Tidak ada tautan yang terdeteksi pada teks dibagikan.';
    } else {
      _startCountdown();
      _submitQuickSave();
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // 2 second auto-close countdown
  // -------------------------------------------------------------------------

  void _startCountdown() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer.periodic(_tick, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownProgress = (_countdownProgress + 1 / _countdownSteps).clamp(
          0.0,
          1.0,
        );
      });
      if (_countdownProgress >= 1) {
        timer.cancel();
        _autoClose();
      }
    });
  }

  static const Duration _tick = Duration(milliseconds: 50);

  Future<void> _autoClose() async {
    if (!mounted) {
      return;
    }
    if (widget.fromExternalIntent) {
      // Return straight back to TikTok / Shopee / Chrome.
      await SystemNavigator.pop();
      return;
    }
    Navigator.of(context).pop();
  }

  void _cancelAutoClose() {
    if (!_autoCloseCanceled) {
      _autoCloseTimer?.cancel();
      setState(() {
        _autoCloseCanceled = true;
      });
    }
  }

  // -------------------------------------------------------------------------
  // quick-save + PATCH handlers
  // -------------------------------------------------------------------------

  Future<void> _submitQuickSave() async {
    final ParsedShareInput parsed = _parsed!;
    setState(() {
      _status = QuickTautStatus.submitting;
      _message = 'Menyimpan tautan...';
    });

    final Map<String, dynamic> payload = <String, dynamic>{
      'url': parsed.cleanUrl,
      if (parsed.rawDescription != null)
        'raw_description': parsed.rawDescription,
      'collection_id': _selectedCollectionId,
      'user_notes': null,
    };

    try {
      final QuickSaveOutcome outcome = await _links.quickSave(
        url: parsed.cleanUrl,
        rawDescription: parsed.rawDescription,
        collectionId: _selectedCollectionId,
      );

      if (!mounted) {
        return;
      }

      // Mirror fresh quota values delivered by meta. The AuthInterceptor has
      // already refreshed the persisted profile, so re-read the snapshot.
      final UserModel? profile = _storage.user;
      if (profile != null) {
        _aiQuotaLeft = profile.aiQuotaLeft;
        _isPro = profile.isPro;
      }

      setState(() {
        _savedLink = outcome.link;
        _message = outcome.isDuplicate
            ? 'Tautan sudah ada di Tautin, dinaikkan ke paling atas!'
            : (outcome.message.isEmpty
                  ? 'Tautan berhasil disimpan.'
                  : outcome.message);
        _status = QuickTautStatus.saved;
      });

      // The user may have tapped a chip while the POST was in flight;
      // persist the pending choice now that we know the link id.
      final int? pending = _selectedCollectionId;
      if (pending != null && outcome.link.collectionId != pending) {
        await _applyPendingCollection(
          patchId: outcome.link.id,
          collectionId: pending,
        );
      }
    } on TautinApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.isConnectionError) {
        await _storage.enqueueOfflineLink(payload: payload);
        setState(() {
          _status = QuickTautStatus.savedOffline;
          _message =
              'Tersimpan di perangkat. Akan dirapikan AI saat '
              'terhubung ke internet.';
        });
        return;
      }
      _autoCloseTimer?.cancel();
      setState(() {
        _status = QuickTautStatus.error;
        _message = e.message;
      });
    }
  }

  Future<void> _applyPendingCollection({
    required int patchId,
    required int collectionId,
  }) async {
    try {
      final LinkModel updated = await _links.updateLink(
        patchId,
        collectionId: collectionId,
      );
      if (!mounted || !(_savedLink?.id == updated.id)) {
        return;
      }
      setState(() {
        _savedLink = updated;
      });
    } on TautinApiException {
      // Network hiccup while moving folders — the link itself is saved;
      // let the countdown continue without blocking the user.
    }
  }

  Future<void> _onCollectionChipTap(CollectionModel? collection) async {
    _cancelAutoClose();
    _noteEditorOpen = false;

    setState(() {
      _selectedCollectionId = collection?.id;
    });

    final LinkModel? link = _savedLink;
    if (link == null || link.collectionId == collection?.id) {
      return;
    }
    await _applyPendingCollection(
      patchId: link.id,
      collectionId: collection!.id,
    );
  }

  Future<void> _onSaveNotes() async {
    final LinkModel? link = _savedLink;
    final String note = _noteController.text.trim();
    if (link == null || note.isEmpty) {
      setState(() {
        _noteEditorOpen = false;
      });
      return;
    }
    _cancelAutoClose();
    setState(() {
      _noteEditorOpen = false;
    });

    try {
      final LinkModel updated = await _links.updateLink(
        link.id,
        userNotes: note,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _savedLink = updated;
        _message = 'Catatan tersimpan.';
      });
    } on TautinApiException catch (e) {
      if (mounted) {
        setState(() {
          _message = e.isConnectionError
              ? 'Catatan belum terkirim, coba lagi saat online.'
              : e.message;
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<CollectionModel> collections = _storage.loadCollections();

    final Color sheetBg =
        isDark ? TautinColors.darkCard : TautinColors.creamBackground;
    final Border? sheetBorder = isDark
        ? Border.all(color: TautinColors.darkBorder)
        : null;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: sheetBorder,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0x33000000),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Drag handle (.dkgrab / light grab)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.darkBorder
                          : TautinColors.mistTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header row: Status icon + title/subtitle + AI quota pill
                _HeaderRow(
                  status: _status,
                  message: _message,
                  aiQuotaLeft: _aiQuotaLeft,
                  isPro: _isPro,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                // Link card preview
                if (_parsed != null)
                  _UrlPreview(
                    url: _parsed!.cleanUrl,
                    domain: Uri.tryParse(_parsed!.cleanUrl)?.host ??
                        _parsed!.cleanUrl,
                    description: _parsed!.rawDescription,
                    isDark: isDark,
                  ),

                // AI Quota exhausted upsell banner
                if (_status == QuickTautStatus.saved &&
                    _savedLink?.aiSummary == null) ...<Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.mossDark
                          : TautinColors.mintAccent,
                      borderRadius: BorderRadius.circular(14),
                      border: isDark
                          ? Border.all(color: TautinColors.mossAltDark)
                          : null,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.brandTeal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppConfig.aiQuotaExhaustedBanner,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Section header for collection
                if (isDark)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'SIMPAN KE KOLEKSI',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: TautinColors.textSecondaryDark,
                      ),
                    ),
                  ),

                // Collection chips horizontal list (.chips / .dkchips)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      _CollectionChip(
                        label: AppConfig.aiAutoCollectionChip,
                        selected: _selectedCollectionId == null,
                        isAutoAi: true,
                        isDark: isDark,
                        onTap: () => _onCollectionChipTap(null),
                      ),
                      for (final CollectionModel collection in collections)
                        _CollectionChip(
                          label: collection.name,
                          selected: _selectedCollectionId == collection.id,
                          isAutoAi: false,
                          isDark: isDark,
                          onTap: () => _onCollectionChipTap(collection),
                        ),
                    ],
                  ),
                ),

                // Auto-close countdown progress bar & status
                if (_countdownActive) ...<Widget>[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _countdownProgress,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? TautinColors.darkBackground
                          : const Color(0xFFDCE6C5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Menutup otomatis dalam ${(2.0 * (1.0 - _countdownProgress)).ceil()} detik',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.seamTeal,
                        ),
                      ),
                    ],
                  ),
                ],

                // Note editor field
                if (_noteEditorOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            autofocus: true,
                            maxLines: 2,
                            minLines: 1,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tulis catatan pribadi...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? TautinColors.textSecondaryDark
                                    : TautinColors.seamTeal,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? TautinColors.darkBackground
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? TautinColors.darkBorder
                                      : TautinColors.mistTeal,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? TautinColors.darkBorder
                                      : TautinColors.mistTeal,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: TautinColors.brandTeal,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Simpan catatan',
                          onPressed: _onSaveNotes,
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                            foregroundColor: isDark
                                ? TautinColors.brandTeal
                                : TautinColors.creamBackground,
                          ),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                  ),

                // Bottom action buttons: Tambah Catatan & Selesai
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _status == QuickTautStatus.saved
                              ? () {
                                  _cancelAutoClose();
                                  setState(() {
                                    _noteEditorOpen = true;
                                  });
                                }
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? TautinColors.textPrimaryDark
                                : TautinColors.brandTeal,
                            side: BorderSide(
                              color: isDark
                                  ? TautinColors.darkBorder
                                  : TautinColors.brandTeal,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Tambah Catatan',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => widget.fromExternalIntent
                              ? SystemNavigator.pop()
                              : Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                            foregroundColor: isDark
                                ? TautinColors.brandTeal
                                : TautinColors.creamBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.status,
    required this.message,
    required this.aiQuotaLeft,
    required this.isPro,
    required this.isDark,
  });

  final QuickTautStatus status;
  final String message;
  final int aiQuotaLeft;
  final bool isPro;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final String headline;
    final Widget statusIcon;

    switch (status) {
      case QuickTautStatus.saved:
        headline = 'Tersimpan di Tautin';
        statusIcon = Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: TautinColors.mintAccent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check,
            color: TautinColors.brandTeal,
            size: 20,
          ),
        );
        break;
      case QuickTautStatus.savedOffline:
        headline = 'Tersimpan Offline';
        statusIcon = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: TautinColors.warningAmber.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.cloud_off_rounded,
            color: TautinColors.warningAmber,
            size: 18,
          ),
        );
        break;
      case QuickTautStatus.error:
        headline = 'Gagal Menyimpan';
        statusIcon = Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: TautinColors.errorRed.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.error_outline_rounded,
            color: TautinColors.errorRed,
            size: 18,
          ),
        );
        break;
      case QuickTautStatus.submitting:
      case QuickTautStatus.idle:
        headline = 'Tersimpan di Tautin';
        statusIcon = Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: TautinColors.mintAccent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check,
            color: TautinColors.brandTeal,
            size: 20,
          ),
        );
        break;
    }

    final String subtext = message.isNotEmpty
        ? message
        : 'AI sedang merapikan tautan ini...';

    final Color quotaBg;
    final Color quotaText;
    final Color quotaSparkle;

    if (isDark) {
      quotaBg = TautinColors.mintAccent;
      quotaText = TautinColors.brandTeal;
      quotaSparkle = TautinColors.brandTeal;
    } else {
      quotaBg = TautinColors.brandTeal;
      quotaText = TautinColors.creamBackground;
      quotaSparkle = TautinColors.mintAccent;
    }

    return Row(
      children: <Widget>[
        statusIcon,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                headline,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: isDark ? 15 : 16,
                  letterSpacing: -0.01,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? TautinColors.textSecondaryDark
                      : TautinColors.seamTeal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: quotaBg,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.auto_awesome,
                size: 13,
                color: quotaSparkle,
              ),
              const SizedBox(width: 4),
              Text(
                isPro ? '👑 PRO' : '✨ AI: $aiQuotaLeft/10',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: quotaText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UrlPreview extends StatelessWidget {
  const _UrlPreview({
    required this.url,
    required this.domain,
    this.description,
    required this.isDark,
  });

  final String url;
  final String domain;
  final String? description;
  final bool isDark;

  IconData _iconForDomain(String domain) {
    if (domain.contains('tiktok') || domain.contains('youtube')) {
      return Icons.play_arrow_rounded;
    }
    if (domain.contains('shopee') || domain.contains('tokopedia')) {
      return Icons.shopping_bag_outlined;
    }
    return Icons.link_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isDark ? 52 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? TautinColors.darkBackground : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 16 : 20),
        border: isDark ? Border.all(color: TautinColors.darkBorder) : null,
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: TautinColors.brandTeal.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark
                  ? TautinColors.darkCard
                  : const Color(0xFFA9E0F1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _iconForDomain(domain),
              size: 18,
              color: isDark ? TautinColors.iceBlue : TautinColors.brandTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  domain,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  url,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? TautinColors.textSecondaryDark
                        : TautinColors.seamTeal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionChip extends StatelessWidget {
  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.isAutoAi,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isAutoAi;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    Border? border;

    if (isDark) {
      if (selected) {
        bgColor = TautinColors.mintAccent;
        textColor = TautinColors.brandTeal;
        border = null;
      } else {
        bgColor = TautinColors.darkBackground;
        textColor = TautinColors.textPrimaryDark;
        border = Border.all(color: TautinColors.darkBorder);
      }
    } else {
      if (selected) {
        bgColor = TautinColors.mintAccent;
        textColor = TautinColors.brandTeal;
        border = Border.all(color: TautinColors.brandTeal, width: 2);
      } else {
        bgColor = Colors.white;
        textColor = TautinColors.brandTeal;
        border = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
            border: border,
            boxShadow: (!isDark && !selected)
                ? <BoxShadow>[
                    BoxShadow(
                      color: TautinColors.brandTeal.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isAutoAi) ...<Widget>[
                Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: textColor,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
