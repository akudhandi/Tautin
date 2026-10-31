import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/user_model.dart';
import '../../home_feed/providers/feed_providers.dart';
import '../providers/collections_providers.dart';
import 'collection_detail_screen.dart';
import 'widgets/create_collection_sheet.dart';

/// Screen 4 (Light) & Screen 28 (Dark) — Koleksimu.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  String _filter = '';

  static const List<Color> _kPastelColors = <Color>[
    Color(0xFFA9E0F1),
    Color(0xFFCAFFA6),
    Color(0xFFE3F5A4),
    Color(0xFFD2E8C9),
    Color(0xFF86C2D1),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final UserModel? user = ref.read(currentUserProvider).value;
    final List<CollectionModel> current =
        ref.read(collectionsProvider).value ?? <CollectionModel>[];
    final bool isPro = user?.isPro ?? false;
    final int customCount =
        current.where((CollectionModel c) => !c.isDefault).length;

    if (!isPro && customCount >= 10) {
      context.push(AppRoutes.paywall);
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateCollectionSheet(),
    );
  }

  void _showCollectionOptions(CollectionModel col) {
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
                  await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateCollectionSheet(
                      initialCollection: col,
                    ),
                  );
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
                  await ref.read(collectionsProvider.notifier).updateCollection(
                        col.id,
                        isPublic: !col.isPublic,
                      );
                },
              ),
              if (col.isPublic)
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Bagikan Tautan Publik'),
                  subtitle: Text(AppConfig.publicCollectionUrl(col.slug ?? '')),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final String url =
                        AppConfig.publicCollectionUrl(col.slug ?? '');
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Lihat koleksi "${col.name}" di Tautin: $url',
                        subject: col.name,
                      ),
                    );
                  },
                ),
              if (!col.isDefault)
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
                          'Koleksi akan dihapus permanen. Tautan di dalamnya akan tetap tersimpan di Tanpa Koleksi.',
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
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final UserModel? user = ref.watch(currentUserProvider).value;
    final bool isPro = user?.isPro ?? false;

    final AsyncValue<List<CollectionModel>> collectionsAsync =
        ref.watch(collectionsProvider);
    final List<CollectionModel> collections =
        collectionsAsync.value ?? <CollectionModel>[];

    final int customCount =
        collections.where((CollectionModel c) => !c.isDefault).length;

    final List<CollectionModel> filtered = _filter.isEmpty
        ? collections
        : collections
            .where((CollectionModel c) =>
                c.name.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(collectionsProvider.notifier).refresh();
      },
      child: CustomScrollView(
        slivers: <Widget>[
          // Header: "Koleksimu" + 44px Search button (.hd / .dkhd)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 52,
                bottom: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  RichText(
                    text: TextSpan(
                      text: 'Koleksi',
                      style: TautinTheme.jakartaHeading(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                        letterSpacing: -0.03,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: 'mu',
                          style: TautinTheme.editorialSerif(
                            fontSize: 42,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? TautinColors.darkCard : Colors.white,
                      shape: BoxShape.circle,
                      border: isDark
                          ? Border.all(color: TautinColors.darkBorder)
                          : null,
                      boxShadow: isDark
                          ? null
                          : <BoxShadow>[
                              BoxShadow(
                                color: TautinColors.brandTeal
                                    .withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: IconButton(
                      icon: Icon(
                        _showSearch
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        size: 20,
                      ),
                      color: isDark
                          ? TautinColors.textPrimaryDark
                          : TautinColors.brandTeal,
                      onPressed: () {
                        setState(() {
                          _showSearch = !_showSearch;
                          if (!_showSearch) _searchController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari koleksi...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: isDark ? TautinColors.darkCard : Colors.white,
                  ),
                ),
              ),
            ),

          // 48px Quota Banner Pill matching Screen 4 & Screen 28
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                height: 48,
                padding: EdgeInsets.only(
                  left: 16,
                  right: isDark ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark ? TautinColors.darkCard : TautinColors.brandTeal,
                  borderRadius: BorderRadius.circular(24),
                  border: isDark
                      ? Border.all(color: TautinColors.darkBorder)
                      : null,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      isPro ? '👑 PRO' : '$customCount/10',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: TautinColors.mintAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isPro
                            ? 'koleksi tanpa batas'
                            : 'koleksi gratis terpakai',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.creamBackground,
                        ),
                      ),
                    ),
                    if (!isPro)
                      FilledButton(
                        onPressed: () => context.push(AppRoutes.paywall),
                        style: FilledButton.styleFrom(
                          backgroundColor: TautinColors.mintAccent,
                          foregroundColor: TautinColors.brandTeal,
                          minimumSize: Size(0, isDark ? 38 : 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        child: const Text('Upgrade'),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Grid of Collections (Screen 4 & 28)
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: 120,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 148,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext ctx, int index) {
                  // Last slot is the "+ Buat Koleksi" dashed card
                  if (index == filtered.length) {
                    return _buildCreateCard(context, isDark);
                  }

                  final CollectionModel col = filtered[index];
                  return _buildCollectionCard(ctx, col, index, isDark);
                },
                childCount: filtered.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(
    BuildContext context,
    CollectionModel col,
    int index,
    bool isDark,
  ) {
    final Color lightBg = colorFromHex(
      col.color,
      fallback: _kPastelColors[index % _kPastelColors.length],
    );

    // Dark mode alternating .ci / .alt .ci
    final bool isAlt = index.isOdd;
    final Color darkCiBg =
        isAlt ? const Color(0xFF1B3541) : const Color(0xFF25452F);
    final Color darkCiColor =
        isAlt ? TautinColors.iceBlue : TautinColors.mintAccent;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionDetailScreen(
              collectionId: col.id,
              initialCollection: col,
            ),
          ),
        );
      },
      onLongPress: () => _showCollectionOptions(col),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? TautinColors.darkCard : lightBg,
          borderRadius: BorderRadius.circular(28),
          border: isDark
              ? Border.all(color: TautinColors.darkBorder)
              : null,
          boxShadow: isDark
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: TautinColors.brandTeal.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Top row: circle icon + optional public badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  width: isDark ? 42 : 44,
                  height: isDark ? 42 : 44,
                  decoration: BoxDecoration(
                    color: isDark ? darkCiBg : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    iconDataForName(col.icon),
                    color: isDark ? darkCiColor : TautinColors.brandTeal,
                    size: isDark ? 20 : 22,
                  ),
                ),
                if (col.isPublic)
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.darkBackground
                          : TautinColors.brandTeal,
                      borderRadius: BorderRadius.circular(13),
                      border: isDark
                          ? Border.all(color: TautinColors.darkBorder)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.public_rounded,
                          size: 11,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.creamBackground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Publik',
                          style: TextStyle(
                            color: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.creamBackground,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Bottom info: title + link count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  col.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: isDark ? 15 : 16,
                    height: 1.2,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${col.linksCount} tautan',
                  style: TextStyle(
                    fontSize: isDark ? 12.5 : 13,
                    color: isDark
                        ? TautinColors.textSecondaryDark
                        : TautinColors.brandTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context, bool isDark) {
    return InkWell(
      onTap: _openCreateDialog,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 148,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? TautinColors.darkBorder : TautinColors.brandTeal,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? TautinColors.mintAccent
                    : TautinColors.brandTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark
                    ? TautinColors.brandTeal
                    : TautinColors.mintAccent,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat Koleksi',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: isDark ? 14 : 15,
                color: isDark
                    ? TautinColors.textPrimaryDark
                    : TautinColors.brandTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
