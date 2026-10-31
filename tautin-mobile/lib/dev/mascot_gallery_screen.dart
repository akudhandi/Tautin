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
