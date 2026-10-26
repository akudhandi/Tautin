import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../providers/auth_providers.dart';

/// Index/title/body triplet for each onboarding slide.
class _SlideData {
  const _SlideData(this.emoji, this.title, this.body, this.accent);

  final String emoji;
  final String title;
  final String body;
  final Color accent;
}

const List<_SlideData> _kSlides = <_SlideData>[
  _SlideData(
    '🔗',
    'Tinggal Share ke Tautin',
    'Buka TikTok, Shopee, Tokopedia, atau Chrome, tekan tombol Share, lalu '
        'pilih Tautin. Tautan langsung tersimpan tanpa berpindah aplikasi.',
    TautinColors.primaryIndigo,
  ),
  _SlideData(
    '✨',
    'AI Merangkum & Merapikan',
    'Tautin AI membuat ringkasan singkat, memilihkan folder terbaik, dan '
        'menambahkan tag otomatis pada setiap tautan tanpa perlu pikir apa nama foldernya.',
    TautinColors.aiViolet,
  ),
  _SlideData(
    '⏰',
    'Anti Lupa dengan Pengingat',
    'Tautan yang belum dibaca dibangkitkan kembali di beranda, dan kamu bisa '
        'memasang pengingat supaya hal penting tidak tenggelam lagi.',
    TautinColors.successGreen,
  ),
];

/// Onboarding + one-tap Google login entry point.
class OnboardingLoginScreen extends ConsumerStatefulWidget {
  const OnboardingLoginScreen({super.key});

  @override
  ConsumerState<OnboardingLoginScreen> createState() =>
      _OnboardingLoginScreenState();
}

class _OnboardingLoginScreenState extends ConsumerState<OnboardingLoginScreen> {
  final PageController _pageController = PageController();

  int _page = 0;

  bool get _isLastPage => _page == _kSlides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_isLastPage) {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
  }

  Future<void> _onGooglePressed() async {
    await _attemptGoogleSignIn();
  }

  Future<void> _attemptGoogleSignIn() async {
    ref.read(authFlowProvider.notifier).clearError();

    final bool onScreen = mounted;
    if (!onScreen) {
      return;
    }
    await ref.read(authFlowProvider.notifier).signInWithGoogle();

    final AuthFlowState state = ref.read(authFlowProvider);
    if (!state.completed) {
      final String? error = state.errorMessage;
      if (error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(error), duration: const Duration(seconds: 3)),
          );
      }
      return;
    }

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthFlowState flow = ref.watch(authFlowProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 4),
              child: TautinBrandHeader(iconSize: 40, fontSize: 24),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _kSlides.length,
                onPageChanged: _handlePageChanged,
                itemBuilder: (BuildContext context, int index) {
                  return _OnboardingSlide(
                    data: _kSlides[index],
                    index: index,
                  );
                },
              ),
            ),
            _PageDots(count: _kSlides.length, activeIndex: _page),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goToNextPage,
              child: Text(
                _isLastPage ? 'Mulai Sekarang' : 'Lanjutkan',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: <Widget>[
                  _GoogleButton(
                    isLoading: flow.isLoading,
                    onPressed: _onGooglePressed,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Dengan melanjutkan, kamu menyetujui Syarat & Ketentuan '
                        'serta Kebijakan Privasi Tautin.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.data,
    required this.index,
  });

  final _SlideData data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 12),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              data.emoji,
              style: const TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
              height: 1.45,
            ),
          ),
          if (index == 0) _buildShareTutorial(),
          if (index == 1) _buildAiSummaryTutorial(),
          if (index == 2) _buildReminderTutorial(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildShareTutorial() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TautinColors.softBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TautinColors.brandTeal.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.share_rounded, size: 14, color: TautinColors.brandTeal),
              SizedBox(width: 6),
              Text(
                'Menu "Bagikan ke" di HP kamu:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TautinColors.brandTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _tutorialAppItem(icon: Icons.chat_bubble_outline_rounded, label: 'Pesan', isTarget: false),
              _tutorialAppItem(icon: Icons.link_rounded, label: 'Salin', isTarget: false),
              _tutorialAppItem(icon: Icons.auto_awesome, label: 'Tautin', isTarget: true),
              _tutorialAppItem(icon: Icons.more_horiz_rounded, label: 'Lainnya', isTarget: false),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: TautinColors.mintAccent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '⚡ Otomatis tersimpan & dirangkum AI dalam 2 detik!',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TautinColors.brandTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutorialAppItem({
    required IconData icon,
    required String label,
    required bool isTarget,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isTarget ? TautinColors.mintAccent : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: isTarget
                ? Border.all(color: TautinColors.brandTeal, width: 2)
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isTarget ? TautinColors.brandTeal : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isTarget ? FontWeight.w800 : FontWeight.w500,
            color: isTarget ? TautinColors.brandTeal : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummaryTutorial() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TautinColors.mintAccent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TautinColors.mintAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome, size: 14, color: TautinColors.brandTeal),
              const SizedBox(width: 6),
              const Text(
                'Ringkasan Otomatis AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: TautinColors.brandTeal,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TautinColors.brandTeal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '10/bln Gratis',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: TautinColors.creamBackground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '"Resep ayam goreng renyah 3 bahan. Cukup marinasi bawang putih, lalu goreng keemasan."',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: TautinColors.brandTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTutorial() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TautinColors.iceBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TautinColors.iceBlue),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.notifications_active_rounded, size: 20, color: TautinColors.brandTeal),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pengingat & Resurfacing',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: TautinColors.brandTeal,
                  ),
                ),
                Text(
                  'Tautan lama dibangkitkan lagi di beranda agar tidak lupa dibaca.',
                  style: TextStyle(
                    fontSize: 11,
                    color: TautinColors.brandTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int index) {
        final bool active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? TautinColors.primaryIndigo
                : TautinColors.primaryIndigo.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: TautinColors.textPrimaryLight,
        elevation: 1,
        side: BorderSide(color: Colors.grey.shade300),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: TautinColors.primaryIndigo,
                ),
              ),
            ),
      label: Text(
        isLoading ? 'Menyambungkan akun...' : 'Lanjutkan dengan Google',
      ),
    );
  }
}
