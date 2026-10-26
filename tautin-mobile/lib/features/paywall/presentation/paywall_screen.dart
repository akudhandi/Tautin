import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/theme/tautin_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../home_feed/providers/feed_providers.dart';
import '../data/billing_repository.dart';

enum ProPlan { monthly, yearly, lifetime }

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProPlan _selectedPlan = ProPlan.yearly;
  bool _isLoading = false;

  String get _productId {
    switch (_selectedPlan) {
      case ProPlan.monthly:
        return 'tautin_pro_monthly';
      case ProPlan.yearly:
        return 'tautin_pro_yearly';
      case ProPlan.lifetime:
        return 'tautin_pro_lifetime';
    }
  }

  Future<void> _subscribe() async {
    setState(() => _isLoading = true);
    try {
      // In mobile environment with in_app_purchase
      final InAppPurchase iap = InAppPurchase.instance;
      final bool available = await iap.isAvailable();

      if (!available) {
        // Fallback / mock purchase for sandbox test environment
        final UserModel updated =
            await ref.read(billingRepositoryProvider).verifyPurchase(
                  productId: _productId,
                  purchaseToken: 'test-sandbox-token-${DateTime.now().millisecondsSinceEpoch}',
                );
        ref.read(currentUserProvider.notifier).updateLocal(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Selamat! Akunmu telah ditingkatkan ke Tautin Pro!')),
          );
          context.pop();
        }
        return;
      }

      // Query products
      final ProductDetailsResponse response =
          await iap.queryProductDetails(<String>{_productId});
      if (response.productDetails.isNotEmpty) {
        final ProductDetails product = response.productDetails.first;
        final PurchaseParam param = PurchaseParam(productDetails: product);
        if (_selectedPlan == ProPlan.lifetime) {
          await iap.buyNonConsumable(purchaseParam: param);
        } else {
          await iap.buyConsumable(purchaseParam: param);
        }
      } else {
        // Fallback for emulator / unconfigured play console ID
        final UserModel updated =
            await ref.read(billingRepositoryProvider).verifyPurchase(
                  productId: _productId,
                  purchaseToken: 'test-sandbox-token-${DateTime.now().millisecondsSinceEpoch}',
                );
        ref.read(currentUserProvider.notifier).updateLocal(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Selamat! Akunmu telah ditingkatkan ke Tautin Pro!')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses langganan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      final UserModel updated =
          await ref.read(billingRepositoryProvider).restorePurchases();
      ref.read(currentUserProvider.notifier).updateLocal(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status langganan berhasil dipulihkan!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada pembelian aktif yang ditemukan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TautinColors.brandTeal,
      body: Stack(
        children: <Widget>[
          // Background Flower Watermark
          const Positioned(
            right: -60,
            top: -30,
            child: Opacity(
              opacity: 0.18,
              child: TautinLogoIcon(size: 240),
            ),
          ),

          // Close Button
          Positioned(
            left: 20,
            top: 52,
            child: InkWell(
              onTap: () => context.pop(),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TautinColors.creamBackground.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: TautinColors.creamBackground,
                  size: 20,
                ),
              ),
            ),
          ),

          // Header Headline
          Positioned(
            left: 24,
            top: 112,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: TautinColors.mintAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.auto_awesome, size: 12, color: TautinColors.brandTeal),
                      SizedBox(width: 5),
                      Text(
                        'Tautin Pro',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: TautinColors.brandTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rapikan semua tautanmu,',
                  style: TautinTheme.jakartaHeading(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: TautinColors.creamBackground,
                    letterSpacing: -0.03,
                  ),
                ),
                Text(
                  'tanpa batas.',
                  style: TautinTheme.editorialSerif(
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    color: TautinColors.mintAccent,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Sheet with Benefits & Plans
          Positioned(
            left: 0,
            right: 0,
            top: 270,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 22),
              decoration: const BoxDecoration(
                color: TautinColors.creamBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    // 4 Benefits
                    _buildBenefitRow(
                      iconBg: TautinColors.mintAccent,
                      icon: Icons.auto_awesome,
                      text: 'Ringkasan, folder, dan tag AI tanpa batas',
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitRow(
                      iconBg: TautinColors.iceBlue,
                      icon: Icons.folder_outlined,
                      text: 'Koleksi tanpa batas',
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitRow(
                      iconBg: TautinColors.mintAccent,
                      icon: Icons.notifications_none_rounded,
                      text: 'Pengingat per tautan, tepat waktu',
                    ),
                    const SizedBox(height: 10),
                    _buildBenefitRow(
                      iconBg: TautinColors.iceBlue,
                      icon: Icons.public_rounded,
                      text: 'Bagikan koleksi publik tanpa batas',
                    ),
                    const SizedBox(height: 20),

                    // Plans
                    _buildPlanCard(
                      plan: ProPlan.monthly,
                      title: 'Bulanan',
                      subtitle: 'Batalkan kapan saja',
                      price: 'Rp29.000',
                      period: 'per bulan',
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      plan: ProPlan.yearly,
                      title: 'Tahunan',
                      subtitle: 'Hemat 28% · Rp20.750/bln',
                      price: 'Rp249.000',
                      period: 'per tahun',
                      badge: 'Paling Hemat',
                    ),
                    const SizedBox(height: 12),
                    _buildPlanCard(
                      plan: ProPlan.lifetime,
                      title: 'Selamanya',
                      subtitle: 'Sekali bayar, seumur hidup',
                      price: 'Rp349.000',
                      period: 'sekali beli',
                      badge: 'Early Bird',
                    ),
                    const SizedBox(height: 18),

                    // CTA Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: TautinColors.brandTeal,
                        foregroundColor: TautinColors.creamBackground,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: _isLoading ? null : _subscribe,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: TautinColors.mintAccent,
                              ),
                            )
                          : const Text(
                              'Mulai Tautin Pro',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),

                    // Restore Purchases
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        TextButton(
                          onPressed: _isLoading ? null : _restore,
                          child: const Text(
                            'Pulihkan Pembelian',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: TautinColors.brandTeal,
                            ),
                          ),
                        ),
                        const Text(' · ', style: TextStyle(color: Color(0xFF3B5E6C))),
                        const Text(
                          'Batalkan kapan saja di Google Play',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF3B5E6C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required Color iconBg,
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: TautinColors.brandTeal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: TautinColors.brandTeal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required ProPlan plan,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    String? badge,
  }) {
    final bool isSelected = _selectedPlan == plan;

    return InkWell(
      onTap: () => setState(() => _selectedPlan = plan),
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? TautinColors.mintAccent : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? TautinColors.brandTeal : TautinColors.softBorder,
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TautinColors.brandTeal,
                      width: 2,
                    ),
                    color: isSelected ? TautinColors.brandTeal : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: TautinColors.mintAccent,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: TautinColors.brandTeal,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B5E6C),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      price,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: TautinColors.brandTeal,
                      ),
                    ),
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF3B5E6C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              right: 16,
              top: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badge == 'Paling Hemat'
                      ? TautinColors.brandTeal
                      : TautinColors.iceBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badge == 'Paling Hemat'
                        ? TautinColors.mintAccent
                        : TautinColors.brandTeal,
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
