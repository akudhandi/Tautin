import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../collections/presentation/collections_screen.dart';
import '../../gamification/domain/gamification_summary.dart';
import '../../gamification/presentation/widgets/missions_modal_sheet.dart';
import '../../gamification/presentation/widgets/tauti_mascot_card.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../share_intent/domain/dirty_url_parser.dart';
import '../../share_intent/presentation/quick_taut_bottom_sheet.dart';
import '../providers/feed_providers.dart';

/// Active main navigation tab for the bottom dock.
enum MainTab { home, collections, settings }

class TabNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.home;

  void setTab(MainTab tab) => state = tab;
}

final NotifierProvider<TabNotifier, MainTab> activeTabProvider =
    NotifierProvider<TabNotifier, MainTab>(TabNotifier.new);

/// Editorial Home Screen matching Screen 3 from mockup design.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      ref.read(feedProvider.notifier).loadNextPage();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchQueryProvider.notifier).setQuery(query.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).setQuery('');
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Tempel Tautan Baru',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlInput,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (urlInput.text.trim().isNotEmpty) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
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
        ref.invalidate(feedProvider);
        ref.invalidate(resurfaceLinksProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MainTab currentTab = ref.watch(activeTabProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          IndexedStack(
            index: currentTab.index,
            children: <Widget>[
              _buildFeedBody(context),
              const CollectionsScreen(),
              const SettingsScreen(),
            ],
          ),
          _buildFloatingDock(context, currentTab),
        ],
      ),
    );
  }

  Widget _buildFeedBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final AsyncValue<List<LinkModel>> resurfaceAsync =
        ref.watch(resurfaceLinksProvider);
    final List<LinkModel> resurfaceLinks = resurfaceAsync.value ?? <LinkModel>[];

    final FeedFilter activeFilter = ref.watch(activeFilterProvider);
    final AsyncValue<FeedState> feedAsync = ref.watch(feedProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedProvider);
        ref.invalidate(resurfaceLinksProvider);
        ref.invalidate(gamificationSummaryProvider);
        await ref.read(currentUserProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          // App Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 54,
                bottom: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  // Wordmark Header
                  const TautinBrandHeader(iconSize: 36, fontSize: 22),

                  // Profile shortcut button
                  Tooltip(
                    message: 'Profil & Pengaturan',
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(activeTabProvider.notifier)
                            .setTab(MainTab.settings);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? TautinColors.darkCard : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: TautinColors.brandTeal
                                  .withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tauti Mascot Card (.mcard: level pill, title, bubble, XP bar, Misi chip)
          SliverToBoxAdapter(
            child: Consumer(
              builder: (BuildContext ctx, WidgetRef ref, _) {
                final GamificationSummary summary = ref
                    .watch(gamificationSummaryProvider)
                    .value ??
                    GamificationSummary.initial();

                return TautiMascotCard(
                  summary: summary,
                  onMisiTap: () => MissionsModalSheet.show(
                    ctx,
                    summary: summary,
                  ),
                );
              },
            ),
          ),

          // Search Field
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? TautinColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: TautinColors.brandTeal.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: false,
                    hintText: 'Cari barang, resep, topik, atau #tag...',
                    hintStyle: TextStyle(
                      fontSize: 14.5,
                      color: isDark
                          ? TautinColors.textSecondaryDark
                          : const Color(0xFF5A7580),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: TautinColors.brandTeal,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // Resurfacing Carousel (Gated: min 3 unread links)
          if (resurfaceLinks.length >= 3) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Belum Dibaca Minggu Ini',
                      style: TautinTheme.jakartaHeading(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        ref.read(activeFilterProvider.notifier).setFilter(
                              FeedFilter.unread,
                            );
                      },
                      child: Text(
                        'Lihat semua',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.seamTeal,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 146,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: resurfaceLinks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (BuildContext ctx, int index) {
                    final LinkModel item = resurfaceLinks[index];
                    return _buildResurfaceCard(ctx, item, index, isDark);
                  },
                ),
              ),
            ),
          ],

          // Filter Chips Row
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: FeedFilter.values.map((FeedFilter f) {
                  final bool isSelected = activeFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      showCheckmark: false,
                      label: Text(f.label),
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark ? TautinColors.darkTeal : TautinColors.creamBackground)
                            : (isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal),
                      ),
                      backgroundColor:
                          isDark ? TautinColors.darkCard : Colors.white,
                      selectedColor:
                          isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                  ? TautinColors.darkBackground
                                  : TautinColors.mistTeal.withValues(alpha: 0.8)),
                        ),
                      ),
                      onSelected: (_) {
                        ref.read(activeFilterProvider.notifier).setFilter(f);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Feed Content / Infinite List
          feedAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(color: TautinColors.brandTeal),
              ),
            ),
            error: (Object err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.cloud_off_rounded, size: 48, color: TautinColors.errorRed),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat feed.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(feedProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (FeedState state) {
              if (state.links.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Text('🌾', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada tautan',
                            style: TautinTheme.jakartaHeading(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bagikan tautan dari TikTok, Shopee, atau Chrome ke Tautin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: isDark
                                  ? TautinColors.textSecondaryDark
                                  : TautinColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext ctx, int index) {
                    if (index == state.links.length) {
                      return state.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: TautinColors.brandTeal,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const SizedBox(height: 110);
                    }

                    final LinkModel link = state.links[index];
                    return SmartLinkCard(
                      link: link,
                      onTap: () {
                        context.push('${AppRoutes.home}/detail/${link.id}', extra: link);
                      },
                      onQuotaBannerTap: () {
                        context.push(AppRoutes.paywall);
                      },
                    );
                  },
                  childCount: state.links.length + 1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResurfaceCard(
    BuildContext context,
    LinkModel link,
    int index,
    bool isDark,
  ) {
    // Alternating palette: Ice Blue, Mint, Card White
    final List<Color> colors = <Color>[
      TautinColors.iceBlue,
      TautinColors.mintAccent,
      isDark ? TautinColors.darkCard : Colors.white,
    ];
    final Color bgColor = colors[index % colors.length];

    return InkWell(
      onTap: () {
        context.push('${AppRoutes.home}/detail/${link.id}', extra: link);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 228,
        height: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatRelativeTime(link.updatedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TautinColors.brandTeal,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        link.title?.trim().isNotEmpty == true
                            ? link.title!
                            : link.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.25,
                          color: TautinColors.brandTeal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        link.domain,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: TautinColors.brandTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: TautinColors.brandTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: TautinColors.mintAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingDock(BuildContext context, MainTab currentTab) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          // Pill Bar
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: TautinColors.brandTeal,
              borderRadius: BorderRadius.circular(32),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: TautinColors.brandTeal.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Left 2 items: Home & Collections
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _dockButton(
                      activeIcon: Icons.home_rounded,
                      inactiveIcon: Icons.home_outlined,
                      label: 'Beranda',
                      isActive: currentTab == MainTab.home,
                      onTap: () {
                        ref.read(activeTabProvider.notifier).setTab(
                              MainTab.home,
                            );
                      },
                    ),
                    const SizedBox(width: 4),
                    _dockButton(
                      activeIcon: Icons.folder_rounded,
                      inactiveIcon: Icons.folder_outlined,
                      label: 'Koleksi',
                      isActive: currentTab == MainTab.collections,
                      onTap: () {
                        ref.read(activeTabProvider.notifier).setTab(
                              MainTab.collections,
                            );
                      },
                    ),
                  ],
                ),

                // Right 2 items: Settings & Paywall Pro
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _dockButton(
                      activeIcon: Icons.person_rounded,
                      inactiveIcon: Icons.person_outline_rounded,
                      label: 'Profil',
                      isActive: currentTab == MainTab.settings,
                      onTap: () {
                        ref.read(activeTabProvider.notifier).setTab(
                              MainTab.settings,
                            );
                      },
                    ),
                    const SizedBox(width: 4),
                    _dockButton(
                      activeIcon: Icons.workspace_premium_rounded,
                      inactiveIcon: Icons.workspace_premium_outlined,
                      label: 'Pro',
                      isActive: false,
                      isPro: true,
                      onTap: () {
                        context.push(AppRoutes.paywall);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Center Raised Add (+) Button
          Positioned(
            top: -22,
            child: Tooltip(
              message: 'Tempel Tautan Baru (+)',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _openQuickAdd();
                },
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: TautinColors.mintAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TautinColors.creamBackground,
                      width: 5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: TautinColors.brandTeal.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: TautinColors.brandTeal,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dockButton({
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool isPro = false,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 12 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isActive ? TautinColors.mintAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isActive ? activeIcon : inactiveIcon,
                size: 22,
                color: isActive
                    ? TautinColors.brandTeal
                    : (isPro
                        ? TautinColors.mintAccent
                        : TautinColors.creamBackground.withValues(alpha: 0.8)),
              ),
              if (isActive) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: TautinColors.brandTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
