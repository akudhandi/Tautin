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

/// "Quick Taut" share sheet (~32% screen height).
///
/// Flow per FR-SAVE-03:
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
      _message = '✨ Menyimpan tautan...';
    });

    final Map<String, dynamic> payload = <String, dynamic>{
      'url': parsed.cleanUrl,
      if (parsed.rawDescription != null) 'raw_description': parsed.rawDescription,
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
        _message =
            outcome.isDuplicate
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
          _message = 'Tersimpan di perangkat. Akan dirapikan AI saat '
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
    await _applyPendingCollection(patchId: link.id, collectionId: collection!.id);
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
    final List<CollectionModel> collections =
        _storage.loadCollections();

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33101828),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _HeaderRow(
                status: _status,
                message: _message,
                aiQuotaLeft: _aiQuotaLeft,
                isPro: _isPro,
              ),
              const SizedBox(height: 12),
              if (_countdownActive) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _countdownProgress,
                    minHeight: 5,
                    backgroundColor:
                        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.18),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_parsed != null)
                _UrlPreview(
                  url: _parsed!.cleanUrl,
                  domain:
                      Uri.tryParse(_parsed!.cleanUrl)?.host ?? _parsed!.cleanUrl,
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: <Widget>[
                    _CollectionChip(
                      label: AppConfig.aiAutoCollectionChip,
                      selected: _selectedCollectionId == null,
                      onTap: () => _onCollectionChipTap(null),
                    ),
                    for (final CollectionModel collection in collections)
                      _CollectionChip(
                        label: collection.name,
                        selected:
                            _selectedCollectionId == collection.id,
                        onTap: () => _onCollectionChipTap(collection),
                      ),
                  ],
                ),
              ),
              if (_noteEditorOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          autofocus: true,
                          maxLines: 2,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Tulis catatan pribadi...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Simpan catatan',
                        onPressed: _onSaveNotes,
                        style: IconButton.styleFrom(
                          backgroundColor: TautinColors.primaryIndigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _status == QuickTautStatus.saved
                              ? () {
                                  _cancelAutoClose();
                                  setState(() {
                                    _noteEditorOpen = true;
                                  });
                                }
                              : null,
                      icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      label: const Text('Tambah Catatan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () =>
                          widget.fromExternalIntent
                              ? SystemNavigator.pop()
                              : Navigator.of(context).pop(),
                      icon: const Icon(Icons.done_rounded, size: 18),
                      label: const Text('Selesai'),
                    ),
                  ),
                ],
              ),
            ],
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
  });

  final QuickTautStatus status;
  final String message;
  final int aiQuotaLeft;
  final bool isPro;

  Color _colorFor(BuildContext context) {
    switch (status) {
      case QuickTautStatus.saved:
        return TautinColors.successGreen;
      case QuickTautStatus.savedOffline:
        return TautinColors.warningAmber;
      case QuickTautStatus.error:
        return TautinColors.errorRed;
      case QuickTautStatus.submitting:
      case QuickTautStatus.idle:
        return TautinColors.primaryIndigo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[TautinColors.primaryIndigo, TautinColors.aiViolet],
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'T',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                message.isEmpty ? '✨ Menyimpan tautan...' : message,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: message.isEmpty ? null : _colorFor(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: TautinColors.aiViolet.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isPro ? '👑 PRO' : '✨ AI: $aiQuotaLeft/10',
            style: theme.textTheme.labelMedium?.copyWith(
              color: TautinColors.primaryIndigo,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _UrlPreview extends StatelessWidget {
  const _UrlPreview({required this.url, required this.domain});

  final String url;
  final String domain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.link_rounded, size: 18, color: TautinColors.primaryIndigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  domain,
                  style: theme.textTheme.labelLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  url,
                  style: theme.textTheme.bodySmall,
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
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? TautinColors.primaryIndigo.withValues(alpha: 0.14)
                : theme.colorScheme.surface,
            border: Border.all(
              color: selected
                  ? TautinColors.primaryIndigo
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.3) ??
                      Colors.grey,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 13,
              color: selected
                  ? TautinColors.primaryIndigo
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }
}
