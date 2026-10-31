import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../collections/providers/collections_providers.dart';
import '../../home_feed/providers/feed_providers.dart';
import '../../share_intent/data/link_repository.dart';

/// Screen 3 (Light) & Screen 27 (Dark) — Detail Tautan.
class LinkDetailScreen extends ConsumerStatefulWidget {
  const LinkDetailScreen({
    super.key,
    required this.linkId,
    this.initialLink,
  });

  final int linkId;
  final LinkModel? initialLink;

  @override
  ConsumerState<LinkDetailScreen> createState() => _LinkDetailScreenState();
}

class _LinkDetailScreenState extends ConsumerState<LinkDetailScreen> {
  late LinkModel? _link = widget.initialLink;
  bool _isLoading = false;
  bool _isSavingNotes = false;
  late final TextEditingController _notesController;
  Timer? _notesDebounceTimer;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: _link?.userNotes ?? '');
    if (_link == null) {
      _fetchLink();
    }
  }

  @override
  void dispose() {
    _notesDebounceTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchLink() async {
    setState(() => _isLoading = true);
    try {
      final LinkModel fresh =
          await ref.read(linkRepositoryProvider).fetchLink(widget.linkId);
      if (mounted) {
        setState(() {
          _link = fresh;
          _notesController.text = fresh.userNotes ?? '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePinned() async {
    final LinkModel? current = _link;
    if (current == null) return;
    HapticFeedback.lightImpact();
    final bool newPinned = !current.isPinned;
    setState(() {
      _link = current.copyWith(isPinned: newPinned);
    });
    try {
      final LinkModel updated = await ref
          .read(linkRepositoryProvider)
          .updateLink(current.id, isPinned: newPinned);
      if (mounted) {
        setState(() => _link = updated);
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
      }
    } catch (_) {
      if (mounted) setState(() => _link = current);
    }
  }

  Future<void> _toggleRead() async {
    final LinkModel? current = _link;
    if (current == null) return;
    HapticFeedback.lightImpact();
    final bool newRead = !current.isRead;
    setState(() {
      _link = current.copyWith(isRead: newRead);
    });
    try {
      final LinkModel updated = await ref
          .read(linkRepositoryProvider)
          .updateLink(current.id, isRead: newRead);
      if (mounted) {
        setState(() => _link = updated);
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
      }
    } catch (_) {
      if (mounted) setState(() => _link = current);
    }
  }

  void _onNotesChanged(String text) {
    _notesDebounceTimer?.cancel();
    setState(() => _isSavingNotes = true);
    _notesDebounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final LinkModel? current = _link;
      if (current == null) return;
      try {
        final LinkModel updated = await ref
            .read(linkRepositoryProvider)
            .updateLink(current.id, userNotes: text.trim());
        if (mounted) {
          setState(() {
            _link = updated;
            _isSavingNotes = false;
          });
          ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
        }
      } catch (_) {
        if (mounted) setState(() => _isSavingNotes = false);
      }
    });
  }

  Future<void> _editTitle() async {
    final LinkModel? current = _link;
    if (current == null) return;
    final TextEditingController titleController =
        TextEditingController(text: current.title ?? '');

    final String? newTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Edit Judul Tautan'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Judul baru...'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(titleController.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      try {
        final LinkModel updated = await ref
            .read(linkRepositoryProvider)
            .updateLink(current.id, title: newTitle);
        setState(() => _link = updated);
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
      } catch (_) {}
    }
  }

  Future<void> _changeCollection() async {
    final LinkModel? current = _link;
    if (current == null) return;

    final List<CollectionModel> collections =
        ref.read(collectionsProvider).value ?? <CollectionModel>[];

    final CollectionModel? selected =
        await showModalBottomSheet<CollectionModel?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(ctx);
        final bool isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? TautinColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Pilih Koleksi',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                ),
              ),
              const SizedBox(height: 12),
              for (final col in collections)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(col.name),
                  trailing: current.collectionId == col.id
                      ? const Icon(Icons.check_rounded,
                          color: TautinColors.brandTeal)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(col),
                ),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Tanpa Koleksi'),
                onTap: () => Navigator.of(ctx).pop(
                  const CollectionModel(id: -1, userId: 0, name: '', slug: ''),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      final int? newColId = selected.id == -1 ? null : selected.id;
      try {
        final LinkModel updated = await ref
            .read(linkRepositoryProvider)
            .updateLink(current.id, collectionId: newColId);
        setState(() => _link = updated);
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
      } catch (_) {}
    }
  }

  Future<void> _regenerateAi() async {
    final LinkModel? current = _link;
    if (current == null) return;
    setState(() => _isLoading = true);
    try {
      final LinkModel updated =
          await ref.read(linkRepositoryProvider).regenerateAi(current.id);
      if (mounted) {
        setState(() {
          _link = updated;
          _isLoading = false;
        });
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
        ref.read(currentUserProvider.notifier).refresh();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setReminder() async {
    final LinkModel? current = _link;
    if (current == null) return;

    final DateTime now = DateTime.now();
    final DateTime tonight =
        DateTime(now.year, now.month, now.day, 20, 0);
    final DateTime tomorrowMorning =
        DateTime(now.year, now.month, now.day + 1, 9, 0);

    final DateTime? chosen = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? TautinColors.darkCard : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Pasang Pengingat',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.nightlight_round,
                    color: TautinColors.brandTeal),
                title: const Text('Nanti malam (20:00)'),
                onTap: () => Navigator.of(ctx).pop(tonight),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_rounded,
                    color: TautinColors.warningAmber),
                title: const Text('Besok pagi (09:00)'),
                onTap: () => Navigator.of(ctx).pop(tomorrowMorning),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded,
                    color: TautinColors.brandTeal),
                title: const Text('Pilih tanggal & waktu...'),
                onTap: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: ctx,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (pickedDate != null && ctx.mounted) {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null && ctx.mounted) {
                      Navigator.of(ctx).pop(DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      ));
                      return;
                    }
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(null);
                },
              ),
              if (current.remindAt != null)
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined,
                      color: TautinColors.errorRed),
                  title: const Text('Hapus Pengingat',
                      style: TextStyle(color: TautinColors.errorRed)),
                  onTap: () => Navigator.of(ctx).pop(DateTime(1970)),
                ),
            ],
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      final DateTime? targetDate =
          chosen.year == 1970 ? null : chosen;
      try {
        final LinkModel updated = await ref
            .read(linkRepositoryProvider)
            .updateLink(current.id, remindAt: targetDate);
        setState(() => _link = updated);
        ref.read(feedProvider.notifier).updateLinkOptimistically(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(targetDate != null
                  ? 'Pengingat disetel untuk ${DateFormat.yMMMd().add_jm().format(targetDate)}'
                  : 'Pengingat dihapus.'),
            ),
          );
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteLink() async {
    final LinkModel? current = _link;
    if (current == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Hapus Tautan?'),
        content: const Text(
          'Tautan ini akan dihapus permanen dari akun Tautin Anda.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: TautinColors.errorRed,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(linkRepositoryProvider).deleteLink(current.id);
        ref.read(feedProvider.notifier).removeLinkOptimistically(current.id);
        if (mounted) {
          context.pop();
        }
      } catch (_) {}
    }
  }

  Future<void> _openOriginalUrl() async {
    final LinkModel? current = _link;
    if (current == null) return;
    final Uri uri = Uri.parse(current.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (_isLoading && _link == null) {
      return Scaffold(
        backgroundColor:
            isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
        body: const Center(
          child: CircularProgressIndicator(color: TautinColors.brandTeal),
        ),
      );
    }

    final LinkModel? link = _link;
    if (link == null) {
      return Scaffold(
        backgroundColor:
            isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
        appBar: AppBar(title: const Text('Detail Tautan')),
        body: const Center(child: Text('Tautan tidak ditemukan')),
      );
    }

    final Color circBg = isDark ? TautinColors.darkCard : Colors.white;
    final Border? circBorder =
        isDark ? Border.all(color: TautinColors.darkBorder) : null;
    final Color circIconColor =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;

    return Scaffold(
      backgroundColor:
          isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: circBg,
                  shape: BoxShape.circle,
                  border: circBorder,
                  boxShadow: isDark
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color:
                                TautinColors.brandTeal.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: circIconColor,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Detail Tautan',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: isDark ? 14 : 15,
            fontWeight: FontWeight.w700,
            color: isDark
                ? TautinColors.textSecondaryDark
                : TautinColors.brandTeal,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          // Pinned toggle
          Center(
            child: InkWell(
              onTap: _togglePinned,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: link.isPinned
                      ? (isDark
                          ? TautinColors.mintAccent
                          : TautinColors.brandTeal)
                      : circBg,
                  shape: BoxShape.circle,
                  border: circBorder,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: link.isPinned
                      ? (isDark
                          ? TautinColors.brandTeal
                          : TautinColors.creamBackground)
                      : circIconColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Share button (.circ / .dkcirc)
          Center(
            child: InkWell(
              onTap: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: '${link.title ?? ''}\n${link.url}',
                    subject: link.title,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: circBg,
                  shape: BoxShape.circle,
                  border: circBorder,
                  boxShadow: isDark
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color:
                                TautinColors.brandTeal.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.share_outlined,
                  size: 19,
                  color: circIconColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete option
          Center(
            child: InkWell(
              onTap: _deleteLink,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: circBg,
                  shape: BoxShape.circle,
                  border: circBorder,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: TautinColors.errorRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: 110,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Hero Thumbnail (.dkthumb or light hero banner)
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.darkCard
                          : TautinColors.iceBlue,
                      borderRadius: BorderRadius.circular(28),
                      border: isDark
                          ? Border.all(color: TautinColors.darkBorder)
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        if (link.thumbnailUrl != null &&
                            link.thumbnailUrl!.trim().isNotEmpty)
                          Positioned.fill(
                            child: CachedNetworkImage(
                              imageUrl: link.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        if (link.sourceType == 'video')
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: TautinColors.creamBackground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: TautinColors.brandTeal,
                              size: 28,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xAA16323D)
                                  : TautinColors.brandTeal,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${link.sourceType} · ${link.domain}',
                              style: const TextStyle(
                                color: TautinColors.creamBackground,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row with Edit Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        link.title?.trim().isNotEmpty == true
                            ? link.title!
                            : link.url,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: isDark ? 23 : 25,
                          fontWeight: FontWeight.w800,
                          height: 1.16,
                          letterSpacing: -0.02,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _editTitle,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: circBg,
                          shape: BoxShape.circle,
                          border: circBorder,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Read Status & Relative Time
                InkWell(
                  onTap: _toggleRead,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        link.isRead
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: link.isRead
                            ? TautinColors.mintAccent
                            : (isDark
                                ? TautinColors.textSecondaryDark
                                : TautinColors.seamTeal),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Disimpan ${formatRelativeTime(link.updatedAt)} · ${link.isRead ? 'sudah dibaca' : 'belum dibaca'}',
                        style: TextStyle(
                          fontSize: isDark ? 12 : 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.seamTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // AI Summary Box (.dkai / light ai box)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? TautinColors.mossDark
                        : TautinColors.mintAccent,
                    borderRadius: BorderRadius.circular(isDark ? 20 : 24),
                    border: isDark
                        ? Border.all(color: TautinColors.mossAltDark)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              const SizedBox(width: 6),
                              Text(
                                'RINGKASAN AI',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.06,
                                  color: isDark
                                      ? TautinColors.mintAccent
                                      : TautinColors.brandTeal,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _regenerateAi,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: isDark
                                    ? TautinColors.mintAccent
                                    : TautinColors.brandTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        link.aiSummary != null && link.aiSummary!.isNotEmpty
                            ? link.aiSummary!
                            : 'Ringkasan AI belum dibuat atau kuota AI habis.',
                        style: TextStyle(
                          fontSize: isDark ? 13.5 : 14.5,
                          height: 1.5,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Collection Picker & Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    InkWell(
                      onTap: _changeCollection,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? TautinColors.mossAltDark
                              : TautinColors.iceBlue,
                          borderRadius: BorderRadius.circular(18),
                          border: isDark
                              ? Border.all(color: TautinColors.darkBorder)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.folder_outlined,
                              size: 16,
                              color: isDark
                                  ? TautinColors.iceBlue
                                  : TautinColors.brandTeal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              link.collection?.name ?? 'Pilih Koleksi',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? TautinColors.iceBlue
                                    : TautinColors.brandTeal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: isDark
                                  ? TautinColors.iceBlue
                                  : TautinColors.brandTeal,
                            ),
                          ],
                        ),
                      ),
                    ),
                    for (final tag in link.tags)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: circBg,
                          borderRadius: BorderRadius.circular(18),
                          border: circBorder,
                        ),
                        child: Text(
                          '#${tag.name}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? TautinColors.textSecondaryDark
                                : TautinColors.brandTeal,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Private Notes Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: circBg,
                    borderRadius: BorderRadius.circular(isDark ? 20 : 22),
                    border: circBorder,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'CATATAN PRIBADI',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.06,
                              color: isDark
                                  ? TautinColors.textSecondaryDark
                                  : TautinColors.seamTeal,
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Icon(
                                _isSavingNotes
                                    ? Icons.sync
                                    : Icons.check_circle_outline_rounded,
                                size: 14,
                                color: isDark
                                    ? TautinColors.textSecondaryDark
                                    : TautinColors.seamTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isSavingNotes ? 'Menyimpan...' : 'Tersimpan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? TautinColors.textSecondaryDark
                                      : TautinColors.seamTeal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        onChanged: _onNotesChanged,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: isDark ? 13.5 : 15,
                          height: 1.45,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tambah catatan pribadi...',
                          hintStyle: TextStyle(
                            color: isDark
                                ? TautinColors.textSecondaryDark
                                : TautinColors.seamTeal,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Reminder Card (Free Tier)
                InkWell(
                  onTap: _setReminder,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.darkCard
                          : TautinColors.iceBlue,
                      borderRadius: BorderRadius.circular(22),
                      border: circBorder,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? TautinColors.darkBackground
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            link.remindAt != null
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            color: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Pasang Pengingat',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: isDark
                                      ? TautinColors.textPrimaryDark
                                      : TautinColors.brandTeal,
                                ),
                              ),
                              Text(
                                link.remindAt != null
                                    ? 'Aktif · ${DateFormat.MMMd().add_jm().format(DateTime.tryParse(link.remindAt!) ?? DateTime.now())}'
                                    : 'Ingatkan aku nanti malam atau besok pagi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? TautinColors.textSecondaryDark
                                      : TautinColors.brandTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (link.remindAt != null)
                          Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? TautinColors.mintAccent
                                  : TautinColors.brandTeal,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Aktif',
                              style: TextStyle(
                                color: isDark
                                    ? TautinColors.brandTeal
                                    : TautinColors.mintAccent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Primary Bottom Action ("Buka Tautan Asli")
          Positioned(
            left: 20,
            right: 20,
            bottom: 26,
            child: InkWell(
              onTap: _openOriginalUrl,
              borderRadius: BorderRadius.circular(29),
              child: Container(
                height: 58,
                padding: const EdgeInsets.only(left: 24, right: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? TautinColors.mintAccent
                      : TautinColors.brandTeal,
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : TautinColors.brandTeal.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Buka Tautan Asli',
                      style: TextStyle(
                        color: isDark
                            ? TautinColors.brandTeal
                            : TautinColors.creamBackground,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? TautinColors.brandTeal
                            : TautinColors.mintAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        color: isDark
                            ? TautinColors.mintAccent
                            : TautinColors.brandTeal,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
