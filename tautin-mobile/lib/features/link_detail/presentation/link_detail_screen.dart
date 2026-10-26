import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../collections/providers/collections_providers.dart';
import '../../home_feed/providers/feed_providers.dart';
import '../../share_intent/data/link_repository.dart';

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
                ),
              ),
              const SizedBox(height: 12),
              for (final col in collections)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(col.name),
                  trailing: current.collectionId == col.id
                      ? const Icon(Icons.check_rounded, color: TautinColors.brandTeal)
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
    final UserModel? user = ref.watch(currentUserProvider).value;
    final bool isPro = user?.isPro ?? false;

    if (_isLoading && _link == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tautan')),
        body: const Center(
          child: CircularProgressIndicator(color: TautinColors.brandTeal),
        ),
      );
    }

    final LinkModel? link = _link;
    if (link == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Tautan')),
        body: const Center(child: Text('Tautan tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? TautinColors.darkCard : Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: Text(
          'Detail Tautan',
          style: TautinTheme.jakartaHeading(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark
                ? TautinColors.textPrimaryDark
                : TautinColors.brandTeal,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            icon: Icon(
              link.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: TautinColors.brandTeal,
            ),
            onPressed: _togglePinned,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: TautinColors.brandTeal),
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text: '${link.title ?? ''}\n${link.url}',
                  subject: link.title,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: TautinColors.errorRed),
            onPressed: _deleteLink,
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Thumbnail / Video Hero Preview
                if (link.thumbnailUrl != null &&
                    link.thumbnailUrl!.trim().isNotEmpty) ...<Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: CachedNetworkImage(
                            imageUrl: link.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: TautinColors.iceBlue,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: TautinColors.iceBlue,
                              child: const Icon(Icons.broken_image_rounded, size: 36),
                            ),
                          ),
                        ),
                        if (link.sourceType == 'video')
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: TautinColors.creamBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: TautinColors.brandTeal,
                              size: 32,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: TautinColors.brandTeal,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '${link.sourceType} · ${link.domain}',
                              style: const TextStyle(
                                color: TautinColors.creamBackground,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Title row with Edit Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        link.title?.trim().isNotEmpty == true
                            ? link.title!
                            : link.url,
                        style: TautinTheme.jakartaHeading(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.02,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _editTitle,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? TautinColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: TautinColors.brandTeal,
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
                            ? TautinColors.successGreen
                            : TautinColors.brandTeal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Disimpan ${formatRelativeTime(link.updatedAt)} · ${link.isRead ? 'sudah dibaca' : 'belum dibaca'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : const Color(0xFF3B5E6C),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // AI Summary Box (Soft Mint Card)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TautinColors.mintAccent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          const Row(
                            children: <Widget>[
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: TautinColors.brandTeal,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'RINGKASAN AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.06,
                                  color: TautinColors.brandTeal,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _regenerateAi,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: TautinColors.brandTeal,
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
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          color: TautinColors.brandTeal,
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
                          color: TautinColors.iceBlue,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.folder_outlined,
                              size: 16,
                              color: TautinColors.brandTeal,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              link.collection?.name ?? 'Pilih Koleksi',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: TautinColors.brandTeal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: TautinColors.brandTeal,
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
                          color: isDark ? TautinColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '#${tag.name}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? TautinColors.textPrimaryDark
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
                    color: isDark ? TautinColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.06,
                              color: isDark
                                  ? TautinColors.textSecondaryDark
                                  : const Color(0xFF3B5E6C),
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
                                    : const Color(0xFF3B5E6C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isSavingNotes ? 'Menyimpan...' : 'Tersimpan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? TautinColors.textSecondaryDark
                                      : const Color(0xFF3B5E6C),
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
                          fontSize: 15,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Tambah catatan pribadi...',
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

                // Reminder (Pro) Card
                InkWell(
                  onTap: () {
                    if (!isPro) {
                      context.push(AppRoutes.paywall);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pengingat telah disetel.')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: TautinColors.iceBlue,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: TautinColors.brandTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
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
                                  color: TautinColors.brandTeal,
                                ),
                              ),
                              Text(
                                'Ingatkan aku nanti malam atau besok pagi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: TautinColors.brandTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isPro)
                          Container(
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: TautinColors.brandTeal,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(
                                  Icons.lock_rounded,
                                  size: 12,
                                  color: TautinColors.mintAccent,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: TautinColors.mintAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
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
                  color: TautinColors.brandTeal,
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: TautinColors.brandTeal.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Buka Tautan Asli',
                      style: TextStyle(
                        color: TautinColors.creamBackground,
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: TautinColors.mintAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_outward_rounded,
                        color: TautinColors.brandTeal,
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
