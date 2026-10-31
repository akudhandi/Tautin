import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tautin_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../home_feed/providers/feed_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Anda dapat masuk kembali kapan saja dengan Google.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authRepositoryProvider).logout();
      if (mounted) {
        context.go(AppRoutes.onboarding);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final TextEditingController confirmationController =
        TextEditingController();
    bool canDelete = false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            return AlertDialog(
              title: const Text('Hapus Akun Permanen?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Perhatian: Tindakan ini permanen. Seluruh tautan, catatan, dan koleksi Anda akan dihapus selamanya.\n\nKetik kata "HAPUS" untuk konfirmasi:',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmationController,
                    autofocus: true,
                    onChanged: (String text) {
                      setStateModal(() {
                        canDelete = text.trim() == 'HAPUS';
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'HAPUS',
                    ),
                  ),
                ],
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
                  onPressed: canDelete
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: const Text('Hapus Selamanya'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount('HAPUS');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun Anda telah berhasil dihapus permanen.')),
          );
          context.go(AppRoutes.onboarding);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus akun: $e')),
          );
        }
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final UserModel? user = ref.watch(currentUserProvider).value;
    final ThemeMode currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor:
          isDark ? TautinColors.darkBackground : TautinColors.creamBackground,
      appBar: AppBar(
        title: Text(
          'Pengaturan',
          style: TautinTheme.jakartaHeading(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark
                ? TautinColors.textPrimaryDark
                : TautinColors.brandTeal,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
        children: <Widget>[
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? TautinColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: TautinColors.mintAccent,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name.substring(0, 1).toUpperCase()
                        : 'T',
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
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
                        user?.name ?? 'Pengguna Tautin',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Subscription & AI Quota Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? TautinColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: user?.isPro == true
                    ? TautinColors.mintAccent
                    : (isDark
                        ? TautinColors.darkBorder
                        : TautinColors.softBorder),
                width: user?.isPro == true ? 2 : 1,
              ),
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
                          user?.isPro == true
                              ? Icons.workspace_premium_rounded
                              : Icons.auto_awesome,
                          color: user?.isPro == true
                              ? TautinColors.mintAccent
                              : TautinColors.brandTeal,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user?.isPro == true
                              ? 'Tautin PRO'
                              : 'Paket Akun Gratis',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark
                                ? TautinColors.textPrimaryDark
                                : TautinColors.brandTeal,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user?.isPro == true
                            ? TautinColors.mintAccent
                            : TautinColors.iceBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user?.isPro == true ? '👑 UNLIMITED' : '10 / BULAN',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: TautinColors.brandTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (user?.isPro != true) ...<Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Sisa Kuota AI Bulan Ini',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? TautinColors.textSecondaryDark
                              : TautinColors.seamTeal,
                        ),
                      ),
                      Text(
                        '${user?.aiQuotaLeft ?? 10} dari 10',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.brandTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((user?.aiQuotaLeft ?? 10) / 10).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: isDark
                          ? TautinColors.creamBackground.withValues(alpha: 0.14)
                          : TautinColors.mistTeal.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? TautinColors.mintAccent : TautinColors.brandTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Reset otomatis 10 kuota ringkasan AI setiap awal bulan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? TautinColors.textSecondaryDark
                          : TautinColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: TautinColors.brandTeal,
                      foregroundColor: TautinColors.mintAccent,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    onPressed: () => context.push(AppRoutes.paywall),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.workspace_premium_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Upgrade ke Tautin Pro (Tanpa Batas)',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    'Kamu memiliki akses tanpa batas untuk ringkasan AI, folder otomatis, koleksi tak terbatas, dan pengingat.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? TautinColors.textSecondaryDark
                          : TautinColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tampilan / Theme Selector
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? TautinColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Tampilan',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('Sistem'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Terang'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Gelap'),
                    ),
                  ],
                  selected: <ThemeMode>{currentThemeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    ref.read(themeModeProvider.notifier).setMode(
                          newSelection.first,
                        );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Senggang Labs - Pilah Cross Promotion Banner
          InkWell(
            onTap: () => _openUrl('https://senggang.id/pilah'),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TautinColors.mintAccent.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: TautinColors.mintAccent,
                  width: 1.5,
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Text('🌱', style: TextStyle(fontSize: 32)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Kenalan dengan Pilah',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: TautinColors.brandTeal,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Aplikasi pintar kelola sampah dari Senggang Labs.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: TautinColors.brandTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: TautinColors.brandTeal,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Legal & Dukungan
          Container(
            decoration: BoxDecoration(
              color: isDark ? TautinColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Kebijakan Privasi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openUrl('https://tautin.app/privacy'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Syarat & Ketentuan'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openUrl('https://tautin.app/terms'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('Bantuan & Dukungan'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openUrl('mailto:halo@senggang.id'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sign Out & Danger Zone
          Container(
            decoration: BoxDecoration(
              color: isDark ? TautinColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Keluar dari Akun'),
                  onTap: _logout,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: TautinColors.errorRed),
                  title: const Text(
                    'Hapus Akun Permanen',
                    style: TextStyle(color: TautinColors.errorRed),
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
