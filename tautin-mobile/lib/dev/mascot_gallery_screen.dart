import 'package:flutter/material.dart';

import '../core/theme/tautin_theme.dart';
import '../shared/widgets/tauti_badge.dart';
import '../shared/widgets/tauti_mascot.dart';

/// TEMPORARY developer screen: renders every [TautiMood], every [TautiOutfit]
/// and the badge so the mascot can be previewed on a device. Route:
/// `/dev/mascot`.
///
/// Delete this file (and its route in `app_router.dart`) once the mascot is
/// wired into the real screens.
class MascotGalleryScreen extends StatefulWidget {
  const MascotGalleryScreen({super.key});

  static const Map<TautiMood, String> moodLabels = <TautiMood, String>{
    TautiMood.idle: 'idle — menyapa',
    TautiMood.happy: 'happy — simpan sukses',
    TautiMood.think: 'think — AI merangkum',
    TautiMood.read: 'read — sedang membaca',
    TautiMood.cheer: 'cheer — naik level',
    TautiMood.sleep: 'sleep — tidak ada aktivitas',
    TautiMood.poke: 'poke — disentuh',
  };

  static const Map<TautiOutfit, String> outfitLabels = <TautiOutfit, String>{
    TautiOutfit.none: 'Tauti polos (Lv 1)',
    TautiOutfit.curator: 'Kurator Cilik (Lv 5)',
    TautiOutfit.master: 'Master Tautan (Lv 10)',
    TautiOutfit.legend: 'Legenda Tautin (Lv 20)',
  };

  @override
  State<MascotGalleryScreen> createState() => _MascotGalleryScreenState();
}

class _MascotGalleryScreenState extends State<MascotGalleryScreen> {
  TautiMood _outfitMood = TautiMood.idle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TautinColors.creamBackground,
      appBar: AppBar(
        title: const Text('Galeri Maskot Tauti (dev)'),
        backgroundColor: TautinColors.brandTeal,
        foregroundColor: TautinColors.mintAccent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TautiBadge(size: 56),
                SizedBox(width: 20),
                TautiBadge(size: 56, inverted: true),
              ],
            ),
            _section('Palet terang & gelap (B0.2)'),
            const _PalettePreview(),
            _section('Kostum per level × ekspresi'),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: <Widget>[
                for (final TautiMood mood in TautiMood.values)
                  ChoiceChip(
                    label: Text(mood.name),
                    selected: _outfitMood == mood,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _outfitMood = mood);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 0.66,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: <Widget>[
                for (final MapEntry<TautiOutfit, String> entry
                    in MascotGalleryScreen.outfitLabels.entries)
                  _Card(
                    label: entry.value,
                    child: TautiMascot(
                      mood: _outfitMood,
                      outfit: entry.key,
                      width: 116,
                    ),
                  ),
              ],
            ),
            _section('Semua ekspresi'),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 0.66,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: <Widget>[
                for (final MapEntry<TautiMood, String> entry
                    in MascotGalleryScreen.moodLabels.entries)
                  _Card(
                    label: entry.value,
                    child: TautiMascot(mood: entry.key, width: 116),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: TautinColors.brandTeal,
          ),
        ),
      );
}

class _PalettePreview extends StatelessWidget {
  const _PalettePreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _mock(isDark: false)),
        const SizedBox(width: 10),
        Expanded(child: _mock(isDark: true)),
      ],
    );
  }

  Widget _mock({required bool isDark}) {
    final Color bg =
        isDark ? TautinColors.darkBackground : TautinColors.lightBackground;
    final Color card = isDark ? TautinColors.darkCard : TautinColors.lightCard;
    final Color ring = isDark ? TautinColors.darkBorder : TautinColors.softBorder;
    final Color primary =
        isDark ? TautinColors.textPrimaryDark : TautinColors.textPrimaryLight;
    final Color secondary = isDark
        ? TautinColors.textSecondaryDark
        : TautinColors.textSecondaryLight;
    final Color tertiary =
        isDark ? TautinColors.textTertiaryDark : TautinColors.textTertiaryLight;
    final Color aiBox =
        isDark ? TautinColors.aiSummaryBoxDark : TautinColors.aiSummaryBoxLight;
    final Color aiHead =
        isDark ? TautinColors.mintAccent : TautinColors.brandTeal;
    final Color aiBody = isDark
        ? TautinColors.aiSummaryBodyDark
        : TautinColors.aiSummaryBodyLight;
    final Color chip = isDark ? TautinColors.mossAltDark : TautinColors.iceBlue;
    final Color chipFg = isDark ? TautinColors.iceBlue : TautinColors.brandTeal;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isDark ? 'Gelap (#16323D)' : 'Terang (#F7F9E1)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ring),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('tiktok.com',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: secondary)),
                const SizedBox(height: 4),
                Text('Ayam Bawang Putih Crispy',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: aiBox,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Ringkasan AI',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: aiHead)),
                      const SizedBox(height: 3),
                      Text('Ayam goreng renyah dengan bawang putih.',
                          style: TextStyle(
                              fontSize: 10.5, height: 1.35, color: aiBody)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: chip,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('Belanja',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: chipFg)),
                    ),
                    const SizedBox(width: 6),
                    Text('#resep',
                        style: TextStyle(fontSize: 10, color: tertiary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _swatch(isDark ? 'card #1E3B47' : 'card #FFFFFF', card, secondary),
          _swatch(isDark ? 'ring #2E5563' : 'ring #B9CDB0', ring, secondary),
          _swatch(isDark ? 'AI #25452F' : 'AI #CAFFA6', aiBox, secondary),
          _swatch(isDark ? 'chip #1B3541' : 'chip #A9E0F1', chip, secondary),
          _swatch(isDark ? 'muted #7F9BA5' : 'muted #3B5E6C', tertiary, secondary),
        ],
      ),
    );
  }

  Widget _swatch(String label, Color color, Color labelColor) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: labelColor)),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TautinColors.softBorder),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(child: Center(child: child)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TautinColors.brandTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
