import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/link_model.dart';
import '../../../shared/widgets/smart_link_card.dart';
import '../../../shared/widgets/tauti_mascot.dart';
import '../../home_feed/providers/feed_providers.dart';

/// Full search results screen - mockup Screen 6 (light), 29 (dark),
/// 33 (empty results).
///
/// Search hits title, AI summary, personal notes, and tags on the backend
/// (`GET /api/v1/links?search=`), so the result card highlights the matched
/// text and labels where the match was found.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  FeedFilter _filter = FeedFilter.all;
  bool _submitted = false;
  Timer? _debounce;

  static const List<String> _suggestions = <String>[
    'resep ayam',
    'rendang sapi',
    'masakan mudah',
  ];

  static const List<String> _tryTags = <String>[
    '#resep-ayam',
    '#menu-harian',
    '#masakan-mudah',
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _submitted = widget.initialQuery.trim().isNotEmpty;
    _scrollController.addListener(_onScroll);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    if (_submitted) {
      // Seed the shared query so the feed provider filters immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(searchQueryProvider.notifier)
              .setQuery(widget.initialQuery.trim());
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      ref.read(feedProvider.notifier).loadNextPage();
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _submit);
  }

  void _submit() {
    final String query = _controller.text.trim();
    setState(() => _submitted = query.isNotEmpty);
    ref.read(activeFilterProvider.notifier).setFilter(_filter);
    ref.read(searchQueryProvider.notifier).setQuery(query);
  }

  void _clearQuery() {
    _controller.clear();
    setState(() => _submitted = false);
    ref.read(searchQueryProvider.notifier).setQuery('');
    _focusNode.requestFocus();
  }

  /// Where the query matched, for the mockup's "Cocok di ..." chip.
  ///
  /// The mockup only surfaces AI summary and personal note matches, so other
  /// fields intentionally produce no chip.
  String? _matchSource(LinkModel link, String query) {
    final String q = query.toLowerCase();
    if (link.aiSummary?.toLowerCase().contains(q) == true) {
      return 'ringkasan AI';
    }
    if (link.userNotes?.toLowerCase().contains(q) == true) {
      return 'catatan pribadi';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AsyncValue<FeedState> feedAsync = ref.watch(feedProvider);
    final FeedState? feed = feedAsync.value;
    final String query = _controller.text.trim();
    final List<LinkModel> results = feed?.links ?? <LinkModel>[];
    final bool showResults = _submitted && query.isNotEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
      body: CustomScrollView(
          controller: _scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + 14,
                  20,
                  0,
                ),
                child: Row(
                  children: <Widget>[
                    _buildBackButton(isDark),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSearchField(isDark)),
                  ],
                ),
              ),
            ),
            if (showResults) ...<Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _buildFilterChips(isDark),
                ),
              ),
              feedAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 56),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: TautinColors.brandTeal,
                      ),
                    ),
                  ),
                ),
                error: (Object error, StackTrace stack) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56),
                    child: Column(
                      children: <Widget>[
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 44,
                          color: TautinColors.errorRed,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => ref.invalidate(feedProvider),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (FeedState state) => state.links.isEmpty
                    ? SliverToBoxAdapter(
                        child: _buildEmptyResults(query, isDark),
                      )
                    : SliverToBoxAdapter(
                        child: _buildFoundRow(state.links.length, isDark),
                      ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext ctx, int index) {
                      if (index == results.length) {
                        return (feed?.isLoadingMore ?? false)
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: TautinColors.brandTeal,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox(height: 8);
                      }
                      return _buildResultCard(
                        context,
                        results[index],
                        query,
                        isDark,
                      );
                    },
                    childCount: results.length + 1,
                  ),
                ),
              ),
              if (results.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      'Coba juga',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                      ),
                    ),
                  ),
                ),
              if (results.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tryTags.map((String tag) {
                          return _buildSuggestionPill(
                            tag,
                            isDark,
                            onTap: () {
                              _controller.text = tag.replaceFirst('#', '');
                              _submit();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return InkWell(
      onTap: () {
        ref.read(searchQueryProvider.notifier).setQuery('');
        context.pop();
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? TautinColors.darkCard : Colors.white,
          border: isDark ? Border.all(color: TautinColors.darkBorder) : null,
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 17,
          color:
              isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal,
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: isDark ? 46 : 48,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: isDark ? TautinColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(isDark ? 23 : 24),
        border: Border.all(
          color: isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
          width: isDark ? 1.5 : 2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: isDark ? 18 : 19,
            color: isDark
                ? TautinColors.textSecondaryDark
                : TautinColors.brandTeal,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: isDark ? 13.5 : 15,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? TautinColors.textPrimaryDark
                    : TautinColors.brandTeal,
              ),
              decoration: InputDecoration(
                hintText: 'Cari tautan, catatan, atau #tag...',
                hintStyle: TextStyle(
                  fontSize: isDark ? 13.5 : 14.5,
                  color: isDark
                      ? TautinColors.textSecondaryDark
                      : const Color(0xFF5A7580),
                ),
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            InkWell(
              onTap: _clearQuery,
              customBorder: const CircleBorder(),
              child: Container(
                width: isDark ? 30 : 34,
                height: isDark ? 30 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? TautinColors.darkTeal
                      : TautinColors.creamBackground,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: isDark ? 14 : 16,
                  color: isDark
                      ? TautinColors.textSecondaryDark
                      : TautinColors.brandTeal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: FeedFilter.values
            .where((FeedFilter f) => f != FeedFilter.unassigned)
            .map((FeedFilter f) {
          final bool selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _filter = f);
                ref.read(activeFilterProvider.notifier).setFilter(f);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: isDark ? 34 : 40,
                padding: EdgeInsets.symmetric(horizontal: isDark ? 14 : 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? (selected
                          ? TautinColors.mintAccent
                          : TautinColors.darkCard)
                      : (selected ? TautinColors.brandTeal : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: isDark && !selected
                      ? Border.all(color: TautinColors.darkBorder)
                      : null,
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isDark ? 12.5 : 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: isDark
                        ? (selected
                            ? TautinColors.brandTeal
                            : TautinColors.textSecondaryDark)
                        : (selected
                            ? TautinColors.creamBackground
                            : TautinColors.brandTeal),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoundRow(int count, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: <Widget>[
          TautiMascot(
            mood: TautiMood.think,
            width: 54,
            animate: false,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$count tautan ditemukan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: isDark
                        ? TautinColors.textPrimaryDark
                        : TautinColors.brandTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dicari di judul, ringkasan AI, catatan, dan tag',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
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

  Widget _buildResultCard(
    BuildContext context,
    LinkModel link,
    String query,
    bool isDark,
  ) {
    final String? source = _matchSource(link, query);
    final String summary = (link.aiSummary?.trim().isNotEmpty ?? false)
        ? link.aiSummary!.trim()
        : (link.userNotes?.trim().isNotEmpty ?? false)
            ? 'Catatanmu: ${link.userNotes!.trim()}'
            : (link.rawDescription?.trim() ?? '');

    final Color tileColor = _tileColorFor(link, isDark);
    final Color titleColor =
        isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal;
    final Color metaColor =
        isDark ? TautinColors.textSecondaryDark : TautinColors.seamTeal;
    final Color summaryColor =
        isDark ? TautinColors.mistTeal : TautinColors.brandTeal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push(
          '${AppRoutes.home}/detail/${link.id}',
          extra: link,
        ),
        borderRadius: BorderRadius.circular(isDark ? 20 : 24),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? TautinColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(isDark ? 20 : 24),
            border:
                isDark ? Border.all(color: TautinColors.darkBorder) : null,
            boxShadow: isDark
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: TautinColors.brandTeal.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: isDark ? 54 : 58,
                height: isDark ? 54 : 58,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(isDark ? 16 : 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      (link.title?.trim().isNotEmpty ?? false)
                          ? link.title!.trim()
                          : link.url,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: isDark ? 14.5 : 15.5,
                        height: 1.25,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(link),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDark ? 11.5 : 12.5,
                        color: metaColor,
                      ),
                    ),
                    if (summary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      _HighlightedText(
                        text: summary,
                        query: query,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: isDark ? 12 : 13,
                          height: isDark ? 1.4 : 1.45,
                          color: summaryColor,
                        ),
                        highlightColor: isDark
                            ? TautinColors.mossDark
                            : TautinColors.mintAccent,
                        highlightTextColor: isDark
                            ? TautinColors.mintAccent
                            : TautinColors.brandTeal,
                      ),
                    ],
                    if (source != null) ...<Widget>[
                      const SizedBox(height: 8),
                      _buildMatchChip(source, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaLine(LinkModel link) {
    final String relative = formatRelativeTime(link.createdAt);
    return relative.isEmpty ? link.domain : '${link.domain} \u00B7 $relative';
  }

  Color _tileColorFor(LinkModel link, bool isDark) {
    if (isDark) {
      switch (link.sourceType) {
        case 'video':
          return TautinColors.mossDark;
        case 'ecommerce':
          return TautinColors.mossAltDark;
        case 'article':
          return const Color(0xFF2A4A3A);
        default:
          return TautinColors.darkBorder;
      }
    }
    switch (link.sourceType) {
      case 'video':
        return TautinColors.mintAccent;
      case 'ecommerce':
        return TautinColors.iceBlue;
      case 'article':
        return const Color(0xFFE3F5A4);
      default:
        return TautinColors.mistTeal;
    }
  }

  Widget _buildMatchChip(String source, bool isDark) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? TautinColors.mossAltDark : TautinColors.iceBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            source == 'catatan pribadi'
                ? Icons.edit_outlined
                : Icons.auto_awesome,
            size: 12,
            color: isDark ? TautinColors.mistTeal : TautinColors.brandTeal,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Cocok di $source',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? TautinColors.mistTeal : TautinColors.brandTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionPill(
    String label,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? TautinColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isDark ? Border.all(color: TautinColors.darkBorder) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark
                ? TautinColors.textSecondaryDark
                : TautinColors.brandTeal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResults(String query, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 22, 34, 0),
      child: Column(
        children: <Widget>[
          TautiMascot(
            mood: TautiMood.think,
            width: 148,
            animate: false,
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada yang cocok',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.w800,
              fontSize: 23,
              height: 1.15,
              letterSpacing: -0.02,
              color:
                  isDark ? TautinColors.textPrimaryDark : TautinColors.brandTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tauti belum menemukan tautan untuk \u201C$query\u201D. Coba kata kunci lain atau simpan tautan barunya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? TautinColors.textSecondaryDark : TautinColors.seamTeal,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions.map((String s) {
              return InkWell(
                onTap: () {
                  _controller.text = s;
                  _submit();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? TautinColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isDark
                        ? Border.all(color: TautinColors.darkBorder)
                        : null,
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 14,
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
            height: 56,
            child: FilledButton(
              onPressed: () => context.push(AppRoutes.quickShare),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
                foregroundColor: isDark
                    ? TautinColors.brandTeal
                    : TautinColors.creamBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: const Text(
                'Simpan tautan baru',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders [text] with every case-insensitive occurrence of [query] highlighted
/// inside a rounded mint `<mark>`-style background.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    required this.highlightTextColor,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;
  final Color highlightTextColor;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final String needle = query.trim();
    if (needle.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final String lowerText = text.toLowerCase();
    final String lowerNeedle = needle.toLowerCase();
    final List<TextSpan> spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final int index = lowerText.indexOf(lowerNeedle, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: TextStyle(
            backgroundColor: highlightColor,
            color: highlightTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = index + needle.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
