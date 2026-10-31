import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../../shared/widgets/tauti_mascot.dart';
import '../../collections/presentation/collections_screen.dart';
import '../../gamification/domain/gamification_summary.dart';
import '../../gamification/presentation/widgets/missions_modal_sheet.dart';
import '../../gamification/presentation/widgets/tauti_mascot_card.dart';
import '../../gamification/providers/gamification_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../share_intent/data/link_repository.dart';
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

  void _submitSearch(String query) {
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).setQuery(query.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).setQuery('');
  }

  Future<void> _pasteFromClipboardAndOpen() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      final ParsedShareInput? parsed = DirtyUrlParser.parse(text);
      if (parsed != null && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext ctx) => QuickTautBottomSheet(
            sharedText: text,
          ),
        );
        ref.invalidate(feedProvider);
        ref.invalidate(resurfaceLinksProvider);
        return;
      }
    }
    await _openQuickAdd(initialText: text);
  }

  Future<void> _openQuickAdd({String? initialText}) async {
    final TextEditingController urlInput =
        TextEditingController(text: initialText ?? '');
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

          // Search Field (.search / .dksearch)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: isDark ? 48 : 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? TautinColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(isDark ? 24 : 26),
                  border: isDark
                      ? Border.all(color: TautinColors.darkBorder)
                      : null,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : TautinColors.brandTeal.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? TautinColors.textSecondaryDark
                          : const Color(0xFF3B5E6C),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: _submitSearch,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(
                          fontSize: isDark ? 13.5 : 14.5,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari barang, resep, topik, atau #tag...',
                          hintStyle: TextStyle(
                            fontSize: isDark ? 13.5 : 14.5,
                            color: isDark
                                ? TautinColors.textSecondaryDark
                                : const Color(0xFF5A7580),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: _clearSearch,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
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
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                        letterSpacing: -0.02,
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.brandTeal,
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

          // Filter Chips Row (.chips / .dkchips)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: FeedFilter.values.map((FeedFilter f) {
                  final bool isSelected = activeFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(f, isSelected, isDark),
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
                      const Icon(Icons.cloud_off_rounded,
                          size: 48, color: TautinColors.errorRed),
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
                if (_searchController.text.trim().isNotEmpty) {
                  return _buildEmptySearchResults(context, isDark);
                }
                return _buildEmptyFeedSteps(context, isDark);
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
                        context.push(
                          '${AppRoutes.home}/detail/${link.id}',
                          extra: link,
                        );
                      },
                      onOpen: () {
                        context.push(
                          '${AppRoutes.home}/detail/${link.id}',
                          extra: link,
                        );
                      },
                      onPinToggle: () async {
                        HapticFeedback.lightImpact();
                        final bool newPin = !link.isPinned;
                        final LinkModel updated =
                            link.copyWith(isPinned: newPin);
                        ref
                            .read(feedProvider.notifier)
                            .updateLinkOptimistically(updated);
                        try {
                          await ref
                              .read(linkRepositoryProvider)
                              .updateLink(link.id, isPinned: newPin);
                        } catch (_) {}
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

  Widget _buildFilterChip(FeedFilter filter, bool isSelected, bool isDark) {
    final Color bgColor;
    final Color textColor;
    Border? border;

    if (isDark) {
      if (isSelected) {
        bgColor = TautinColors.mintAccent;
        textColor = TautinColors.brandTeal;
        border = null;
      } else {
        bgColor = TautinColors.darkCard;
        textColor = TautinColors.textSecondaryDark;
        border = Border.all(color: TautinColors.darkBorder);
      }
    } else {
      if (isSelected) {
        bgColor = TautinColors.brandTeal;
        textColor = TautinColors.creamBackground;
        border = null;
      } else {
        bgColor = Colors.white;
        textColor = TautinColors.brandTeal;
        border = null;
      }
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(activeFilterProvider.notifier).setFilter(filter);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: isDark ? 36 : 40,
        padding: EdgeInsets.symmetric(horizontal: isDark ? 16 : 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: border,
          boxShadow: (!isDark && !isSelected)
              ? <BoxShadow>[
                  BoxShadow(
                    color: TautinColors.brandTeal.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          filter.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: isDark ? 13 : 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults(BuildContext context, bool isDark) {
    final String query = _searchController.text.trim();
    final List<String> suggestions = <String>[
      'resep ayam',
      'rendang sapi',
      'masakan mudah',
    ];

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.only(top: 24, left: 28, right: 28, bottom: 96),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const TautiMascot(
                mood: TautiMood.think,
                width: 130,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum ada yang cocok',
                style: TautinTheme.jakartaHeading(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? TautinColors.textPrimaryDark
                      : TautinColors.brandTeal,
                  letterSpacing: -0.02,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tauti belum menemukan tautan untuk “$query”. Coba kata kunci lain atau simpan tautan barunya.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark
                      ? TautinColors.textSecondaryDark
                      : TautinColors.seamTeal,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: suggestions.map((String s) {
                  return InkWell(
                    onTap: () {
                      _searchController.text = s;
                      _submitSearch(s);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? TautinColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: isDark
                            ? Border.all(color: TautinColors.darkBorder)
                            : null,
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? TautinColors.textPrimaryDark
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                    'Simpan tautan baru',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFeedSteps(BuildContext context, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding:
            const EdgeInsets.only(top: 14, left: 20, right: 20, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Simpan dalam 3 langkah',
              style: TautinTheme.jakartaHeading(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? TautinColors.textPrimaryDark
                    : TautinColors.brandTeal,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 12),
            _buildStepCard(
              number: '1',
              title: 'Buka aplikasi apa saja',
              subtitle: 'TikTok, Shopee, Instagram, atau Chrome',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildStepCard(
              number: '2',
              title: 'Tekan tombol Bagikan',
              subtitle: 'Ikon share di tautan yang kamu suka',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildStepCard(
              number: '3',
              title: 'Pilih Tautin',
              subtitle: 'AI merangkum dan merapikannya untukmu',
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pasteFromClipboardAndOpen,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isDark
                        ? TautinColors.darkBorder
                        : TautinColors.brandTeal,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.content_paste_rounded,
                      size: 18,
                      color: isDark
                          ? TautinColors.textPrimaryDark
                          : TautinColors.brandTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tempel tautan dari clipboard',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? TautinColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: TautinColors.darkBorder) : null,
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: TautinColors.brandTeal.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: TautinColors.mintAccent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: TautinColors.brandTeal,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? TautinColors.textSecondaryDark
                        : TautinColors.seamTeal,
                  ),
                ),
              ],
            ),
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
    final List<Color> lightColors = <Color>[
      TautinColors.iceBlue,
      TautinColors.mintAccent,
      Colors.white,
    ];
    final Color bgColor =
        isDark ? TautinColors.darkCard : lightColors[index % lightColors.length];

    final Color primaryText =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;
    final Color secondaryText =
        isDark ? TautinColors.textSecondaryDark : TautinColors.brandTeal;

    final Color pillBg = isDark
        ? TautinColors.mossAltDark
        : (bgColor == Colors.white
            ? TautinColors.creamBackground
            : Colors.white.withValues(alpha: 0.65));

    final Color pillText =
        isDark ? TautinColors.textSecondaryDark : TautinColors.brandTeal;

    return InkWell(
      onTap: () {
        context.push('${AppRoutes.home}/detail/${link.id}', extra: link);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 224,
        height: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: isDark
              ? Border.all(color: TautinColors.darkBorder)
              : (bgColor == Colors.white
                  ? Border.all(color: TautinColors.softBorder)
                  : null),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatRelativeTime(link.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pillText,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        link.title?.trim().isNotEmpty == true
                            ? link.title!
                            : link.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.25,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        link.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: secondaryText,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? TautinColors.mossDark : TautinColors.brandTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_outward_rounded,
                  size: 16,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dockBg =
        isDark ? TautinColors.darkCard : TautinColors.brandTeal;
    final Color iconInactive =
        isDark ? TautinColors.textSecondaryDark : TautinColors.creamBackground;
    final Color iconActive =
        isDark ? TautinColors.mintAccent : TautinColors.creamBackground;
    final Color activeBg = isDark
        ? TautinColors.mintAccent.withValues(alpha: 0.16)
        : TautinColors.creamBackground.withValues(alpha: 0.18);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: Center(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: dockBg,
            borderRadius: BorderRadius.circular(32),
            border: isDark ? Border.all(color: TautinColors.darkBorder) : null,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : TautinColors.brandTeal.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 1. Beranda
              _dockIconButton(
                icon: Icons.home_rounded,
                tooltip: 'Beranda',
                isActive: currentTab == MainTab.home,
                activeBg: activeBg,
                iconColor:
                    currentTab == MainTab.home ? iconActive : iconInactive,
                onTap: () =>
                    ref.read(activeTabProvider.notifier).setTab(MainTab.home),
              ),
              const SizedBox(width: 6),

              // 2. Koleksi
              _dockIconButton(
                icon: Icons.folder_rounded,
                tooltip: 'Koleksi',
                isActive: currentTab == MainTab.collections,
                activeBg: activeBg,
                iconColor: currentTab == MainTab.collections
                    ? iconActive
                    : iconInactive,
                onTap: () => ref
                    .read(activeTabProvider.notifier)
                    .setTab(MainTab.collections),
              ),
              const SizedBox(width: 6),

              // 3. Center FAB (Simpan tautan baru)
              _fabButton(),
              const SizedBox(width: 6),

              // 4. Profil
              _dockIconButton(
                icon: Icons.person_rounded,
                tooltip: 'Profil',
                isActive: currentTab == MainTab.settings,
                activeBg: activeBg,
                iconColor: currentTab == MainTab.settings
                    ? iconActive
                    : iconInactive,
                onTap: () => ref
                    .read(activeTabProvider.notifier)
                    .setTab(MainTab.settings),
              ),
              const SizedBox(width: 6),

              // 5. Tautin Pro
              _dockIconButton(
                icon: Icons.auto_awesome,
                tooltip: 'Tautin Pro',
                isActive: false,
                activeBg: activeBg,
                iconColor: TautinColors.mintAccent,
                onTap: () => context.push(AppRoutes.paywall),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fabButton() {
    return Tooltip(
      message: 'Simpan tautan baru',
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          _openQuickAdd();
        },
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: TautinColors.mintAccent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.add_rounded,
            color: TautinColors.brandTeal,
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _dockIconButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required Color activeBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
