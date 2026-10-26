import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/collection_model.dart';
import '../../../shared/models/user_model.dart';
import '../../home_feed/presentation/home_screen.dart';
import '../../home_feed/providers/feed_providers.dart';
import '../providers/collections_providers.dart';

class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;
  String _filter = '';

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

    // Free tier max 3 collections limit
    if (!isPro && current.length >= 3) {
      context.push(AppRoutes.paywall);
      return;
    }

    final TextEditingController nameController = TextEditingController();
    bool isPublic = false;

    final bool? created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final ThemeData theme = Theme.of(ctx);
        final bool isDark = theme.brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                      'Buat Koleksi Baru',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Nama koleksi (mis. Belanja, Resep)...',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Koleksi Publik'),
                      subtitle: const Text('Dapat dibagikan dan dilihat siapa saja lewat tautan'),
                      value: isPublic,
                      activeThumbColor: TautinColors.brandTeal,
                      onChanged: (bool val) {
                        setModalState(() => isPublic = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty) {
                          Navigator.of(ctx).pop(true);
                        }
                      },
                      child: const Text('Buat Koleksi'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (created == true && nameController.text.trim().isNotEmpty && mounted) {
      await ref.read(collectionsProvider.notifier).createCollection(
            name: nameController.text.trim(),
            isPublic: isPublic,
          );
    }
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
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.public_rounded),
                title: Text(col.isPublic ? 'Ubah ke Privat' : 'Jadikan Koleksi Publik'),
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
                    final String url = AppConfig.publicCollectionUrl(col.slug ?? '');
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Lihat koleksi "${col.name}" di Tautin: $url',
                        subject: col.name,
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Ubah Nama Koleksi'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  _editCollectionName(col);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: TautinColors.errorRed),
                title: const Text('Hapus Koleksi', style: TextStyle(color: TautinColors.errorRed)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref.read(collectionsProvider.notifier).deleteCollection(col.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editCollectionName(CollectionModel col) async {
    final TextEditingController controller =
        TextEditingController(text: col.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Ubah Nama Koleksi'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nama baru...'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && mounted) {
      await ref
          .read(collectionsProvider.notifier)
          .updateCollection(col.id, name: newName);
    }
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
          // Header: "Koleksimu"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 54,
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
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? TautinColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _showSearch
                                ? Icons.close_rounded
                                : Icons.search_rounded,
                          ),
                          color: TautinColors.brandTeal,
                          onPressed: () {
                            setState(() {
                              _showSearch = !_showSearch;
                              if (!_showSearch) {
                                _searchController.clear();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? TautinColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded),
                          color: TautinColors.brandTeal,
                          onPressed: _openCreateDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Cari koleksi...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),

          // Quota Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: _buildQuotaBanner(
                context,
                collections.where((CollectionModel c) => !c.isDefault).length,
                isPro,
              ),
            ),
          ),

          // Grid of Collections
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
                mainAxisExtent: 152,
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

  Widget _buildQuotaBanner(BuildContext context, int count, bool isPro) {
    if (isPro) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TautinColors.brandTeal,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.star_rounded, color: TautinColors.mintAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '👑 PRO Aktif',
                    style: TextStyle(
                      color: TautinColors.creamBackground,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Koleksi tanpa batas & bagikan publik tanpa kuota.',
                    style: TextStyle(
                      color: TautinColors.mistTeal,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bool isExhausted = count >= 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TautinColors.brandTeal,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '$count/10',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                  color: TautinColors.mintAccent,
                  letterSpacing: -0.03,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isExhausted
                          ? 'Batas 10 koleksi gratis sudah penuh'
                          : 'Koleksi akun gratis tersisa ${10 - count}',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: TautinColors.creamBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Upgrade ke Pro untuk koleksi tanpa batas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TautinColors.mistTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => context.push(AppRoutes.paywall),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: TautinColors.mintAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Lihat Tautin Pro',
                    style: TextStyle(
                      color: TautinColors.brandTeal,
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: TautinColors.brandTeal,
                  ),
                ],
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
    final List<Color> colors = <Color>[
      TautinColors.iceBlue,
      TautinColors.mintAccent,
      const Color(0xFFE3F5A4),
      const Color(0xFFD2E8C9),
      const Color(0xFF86C2D1),
    ];
    final Color bgColor = colors[index % colors.length];

    return InkWell(
      onTap: () {
        // Filter feed to this collection and switch to Home
        ref.read(activeFilterProvider.notifier).setFilter(FeedFilter.all);
        ref.read(activeTabProvider.notifier).setTab(MainTab.home);
      },
      onLongPress: () => _showCollectionOptions(col),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 152,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: TautinColors.brandTeal,
                    size: 22,
                  ),
                ),
                if (col.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: TautinColors.brandTeal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.public_rounded,
                          size: 11,
                          color: TautinColors.creamBackground,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Publik',
                          style: TextStyle(
                            color: TautinColors.creamBackground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  col.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: TautinColors.brandTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${col.linksCount} tautan',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: TautinColors.brandTeal,
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
        height: 152,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: TautinColors.brandTeal,
            width: 2,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: TautinColors.brandTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: TautinColors.mintAccent,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat Koleksi',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
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
