import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../../shared/widgets/tauti_mascot.dart';
import '../../link_detail/presentation/link_detail_screen.dart';
import '../../share_intent/data/link_repository.dart';
import '../../share_intent/domain/dirty_url_parser.dart';
import '../../share_intent/presentation/quick_taut_bottom_sheet.dart';
import '../providers/collections_providers.dart';
import 'widgets/create_collection_sheet.dart';

/// Screen 7 (Isi Koleksi), Screen 8 (Bagikan Koleksi), Screen 34 (Koleksi Kosong).
class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
    this.initialCollection,
  });

  final int collectionId;
  final CollectionModel? initialCollection;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  late CollectionModel? _collection = widget.initialCollection;
  List<LinkModel> _links = <LinkModel>[];
  bool _isLoading = false;
  String _selectedFilter = 'Semua';
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _fetchCollectionLinks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCollectionLinks() async {
    setState(() => _isLoading = true);
    try {
      final PaginatedLinks paginated = await ref
          .read(linkRepositoryProvider)
          .fetchLinks(collectionId: widget.collectionId);

      // Also ensure we have latest collection metadata
      final List<CollectionModel> allCols =
          ref.read(collectionsProvider).value ?? <CollectionModel>[];
      final CollectionModel freshCol = allCols.firstWhere(
        (CollectionModel c) => c.id == widget.collectionId,
        orElse: () => _collection ?? const CollectionModel(id: 0, name: ''),
      );

      if (mounted) {
        setState(() {
          _links = paginated.links;
          if (freshCol.id != 0) {
            _collection = freshCol;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCollectionMenu() {
    final CollectionModel? col = _collection;
    if (col == null) return;

    showModalBottomSheet<void>(
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
            children: <Widget>[
              Text(
                col.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Ubah Nama & Tampilan'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final bool? updated =
                      await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateCollectionSheet(
                      initialCollection: col,
                    ),
                  );
                  if (updated == true) {
                    _fetchCollectionLinks();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Bagikan Koleksi'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showShareSheet();
                },
              ),
              ListTile(
                leading: Icon(
                  col.isPublic ? Icons.lock_outline : Icons.public_rounded,
                ),
                title: Text(col.isPublic
                    ? 'Ubah ke Privat'
                    : 'Jadikan Koleksi Publik'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref
                      .read(collectionsProvider.notifier)
                      .updateCollection(col.id, isPublic: !col.isPublic);
                  _fetchCollectionLinks();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: TautinColors.errorRed),
                title: const Text('Hapus Koleksi',
                    style: TextStyle(color: TautinColors.errorRed)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dCtx) => AlertDialog(
                      title: const Text('Hapus Koleksi?'),
                      content: const Text(
                        'Koleksi akan dihapus. Tautan di dalamnya akan tetap aman dan dipindah ke Tanpa Koleksi.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TautinColors.errorRed,
                          ),
                          onPressed: () => Navigator.of(dCtx).pop(true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await ref
                        .read(collectionsProvider.notifier)
                        .deleteCollection(col.id);
                    if (mounted) context.pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareSheet() {
    final CollectionModel? col = _collection;
    if (col == null) return;
    final String publicUrl = AppConfig.publicCollectionUrl(col.slug ?? '');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          decoration: BoxDecoration(
            color: isDark ? TautinColors.darkCard : TautinColors.creamBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
              const SizedBox(height: 16),
              Text(
                'Bagikan Koleksi',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                col.isPublic
                    ? 'Siapa saja yang memiliki tautan dapat melihat isi koleksi ini.'
                    : 'Koleksi saat ini berstatus privat. Jadikan publik untuk membagikannya.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? TautinColors.textSecondaryDark
                      : TautinColors.seamTeal,
                ),
              ),
              const SizedBox(height: 16),
              if (col.isPublic) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? TautinColors.darkBackground
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isDark
                        ? Border.all(color: TautinColors.darkBorder)
                        : null,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.link_rounded,
                        color: TautinColors.brandTeal,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          publicUrl,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? TautinColors.textPrimaryDark
                                : TautinColors.brandTeal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Lihat koleksi "${col.name}" di Tautin: $publicUrl',
                          subject: col.name,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text(
                      'Bagikan Tautan',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                  ),
                ),
              ] else ...<Widget>[
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref
                          .read(collectionsProvider.notifier)
                          .updateCollection(col.id, isPublic: true);
                      _fetchCollectionLinks();
                    },
                    icon: const Icon(Icons.public_rounded, size: 18),
                    label: const Text(
                      'Aktifkan Koleksi Publik',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openQuickAdd() async {
    final TextEditingController urlInput = TextEditingController();
    final bool? shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(ctx);
        final bool isDark = theme.brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
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
                  'Tambah Tautan ke ${_collection?.name ?? 'Koleksi'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlInput,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Tempel URL...',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Simpan ke Tautin'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSave == true && mounted && urlInput.text.trim().isNotEmpty) {
      final String raw = urlInput.text.trim();
      final ParsedShareInput? parsed = DirtyUrlParser.parse(raw);
      if (parsed != null) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext ctx) => QuickTautBottomSheet(
            sharedText: raw,
          ),
        );
        _fetchCollectionLinks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final CollectionModel? col = _collection;

    final Color circBg = isDark ? TautinColors.darkCard : Colors.white;
    final Border? circBorder =
        isDark ? Border.all(color: TautinColors.darkBorder) : null;
    final Color circIconColor =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;

    final Color headBg = isDark
        ? TautinColors.darkCard
        : colorFromHex(col?.color, fallback: TautinColors.mintAccent);

    final List<LinkModel> filteredLinks = _links.where((LinkModel l) {
      if (_searchQuery.isNotEmpty) {
        final String q = _searchQuery.toLowerCase();
        final bool matchesTitle = l.title?.toLowerCase().contains(q) ?? false;
        final bool matchesUrl = l.url.toLowerCase().contains(q);
        final bool matchesAi = l.aiSummary?.toLowerCase().contains(q) ?? false;
        if (!matchesTitle && !matchesUrl && !matchesAi) return false;
      }
      switch (_selectedFilter) {
        case 'Video':
          return l.sourceType == 'video';
        case 'Artikel':
          return l.sourceType == 'article';
        case 'Belum Dibaca':
          return !l.isRead;
        case 'Semua':
        default:
          return true;
      }
    }).toList();

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
        actions: <Widget>[
          // Search button
          Center(
            child: InkWell(
              onTap: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _searchController.clear();
                });
              },
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
                child: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                  size: 20,
                  color: circIconColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // More options button (dots)
          Center(
            child: InkWell(
              onTap: _showCollectionMenu,
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
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: circIconColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCollectionLinks,
        child: CustomScrollView(
          slivers: <Widget>[
            // Search Input Row
            if (_showSearch)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(
                      color: isDark
                          ? TautinColors.textPrimaryDark
                          : TautinColors.brandTeal,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari di koleksi...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor:
                          isDark ? TautinColors.darkCard : Colors.white,
                    ),
                  ),
                ),
              ),

            // Hero Header Card (.chead matching Screen 7 & Screen 34)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: headBg,
                    borderRadius: BorderRadius.circular(28),
                    border: isDark
                        ? Border.all(color: TautinColors.darkBorder)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? TautinColors.darkBackground
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              iconDataForName(col?.icon),
                              size: 24,
                              color: isDark
                                  ? TautinColors.mintAccent
                                  : TautinColors.brandTeal,
                            ),
                          ),
                          if (col?.isPublic == true)
                            Container(
                              height: 26,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: TautinColors.brandTeal,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.public_rounded,
                                    size: 12,
                                    color: TautinColors.creamBackground,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Publik',
                                    style: TextStyle(
                                      color: TautinColors.creamBackground,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        col?.name ?? 'Koleksi',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                          letterSpacing: -0.03,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_links.length} tautan · ${col?.isDefault == true ? 'koleksi bawaan' : 'koleksi kustom'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _showShareSheet,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.share_rounded,
                                size: 16,
                                color: isDark
                                    ? TautinColors.brandTeal
                                    : TautinColors.creamBackground,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Bagikan koleksi',
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isDark
                                      ? TautinColors.brandTeal
                                      : TautinColors.creamBackground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filter chips row: Semua, Video, Artikel, Belum Dibaca
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: <Widget>[
                    for (final String filter in <String>[
                      'Semua',
                      'Video',
                      'Artikel',
                      'Belum Dibaca',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedFilter = filter),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedFilter == filter
                                  ? (isDark
                                      ? TautinColors.mintAccent
                                      : TautinColors.brandTeal)
                                  : circBg,
                              borderRadius: BorderRadius.circular(20),
                              border: isDark && _selectedFilter != filter
                                  ? circBorder
                                  : null,
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _selectedFilter == filter
                                    ? (isDark
                                        ? TautinColors.brandTeal
                                        : TautinColors.creamBackground)
                                    : (isDark
                                        ? TautinColors.textSecondaryDark
                                        : TautinColors.brandTeal),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Empty state (Screen 34)
            if (!_isLoading && filteredLinks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: <Widget>[
                      const TautiMascot(
                        mood: TautiMood.idle,
                        width: 96,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Koleksi ini masih kosong',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Simpan tautan pertamamu lewat tombol + atau bagikan tautan dari aplikasi lain ke Tautin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.seamTeal,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _openQuickAdd,
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
                            'Tambah tautan',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _showShareSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? TautinColors.textPrimaryDark
                                : TautinColors.brandTeal,
                            side: BorderSide(
                              color: isDark
                                  ? TautinColors.darkBorder
                                  : TautinColors.brandTeal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text(
                            'Bagikan koleksi',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Links list (.list matching Screen 7)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext ctx, int index) {
                      final LinkModel link = filteredLinks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => LinkDetailScreen(
                                  linkId: link.id,
                                  initialLink: link,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: circBg,
                              borderRadius: BorderRadius.circular(20),
                              border: circBorder,
                            ),
                            child: Row(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? TautinColors.darkBackground
                                          : TautinColors.iceBlue,
                                    ),
                                    child: link.thumbnailUrl != null &&
                                            link.thumbnailUrl!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: link.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.link_rounded),
                                          )
                                        : Icon(
                                            link.sourceType == 'video'
                                                ? Icons.play_arrow_rounded
                                                : Icons.article_outlined,
                                            color: TautinColors.brandTeal,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        link.title ?? link.url,
                                        style: TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: isDark
                                              ? TautinColors.textPrimaryDark
                                              : TautinColors.brandTeal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${link.domain} · ${formatRelativeTime(link.updatedAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? TautinColors.textSecondaryDark
                                              : TautinColors.seamTeal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!link.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: TautinColors.mintAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredLinks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
