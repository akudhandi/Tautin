import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tautin_theme.dart';
import '../../../../shared/models/collection_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../home_feed/providers/feed_providers.dart';
import '../../providers/collections_providers.dart';

/// Available icon options matching Screen 11.
const List<Map<String, dynamic>> kCollectionIconOptions = <Map<String, dynamic>>[
  <String, dynamic>{'key': 'shopping_bag', 'icon': Icons.shopping_bag_outlined, 'label': 'Belanja'},
  <String, dynamic>{'key': 'restaurant', 'icon': Icons.restaurant_outlined, 'label': 'Makanan'},
  <String, dynamic>{'key': 'school', 'icon': Icons.school_outlined, 'label': 'Belajar'},
  <String, dynamic>{'key': 'place', 'icon': Icons.place_outlined, 'label': 'Tempat'},
  <String, dynamic>{'key': 'play', 'icon': Icons.play_arrow_rounded, 'label': 'Tontonan'},
  <String, dynamic>{'key': 'favorite', 'icon': Icons.favorite_border_rounded, 'label': 'Favorit'},
  <String, dynamic>{'key': 'star', 'icon': Icons.star_border_rounded, 'label': 'Bintang'},
  <String, dynamic>{'key': 'music', 'icon': Icons.music_note_outlined, 'label': 'Musik'},
  <String, dynamic>{'key': 'work', 'icon': Icons.work_outline_rounded, 'label': 'Kerja'},
  <String, dynamic>{'key': 'flight', 'icon': Icons.flight_takeoff_rounded, 'label': 'Liburan'},
  <String, dynamic>{'key': 'lightbulb', 'icon': Icons.lightbulb_outline_rounded, 'label': 'Ide'},
  <String, dynamic>{'key': 'gift', 'icon': Icons.card_giftcard_rounded, 'label': 'Hadiah'},
];

/// 12 Swatches matching Screen 11 (.grid6).
const List<Map<String, dynamic>> kCollectionColorOptions = <Map<String, dynamic>>[
  <String, dynamic>{'hex': '#CAFFA6', 'color': Color(0xFFCAFFA6), 'label': 'Lime'},
  <String, dynamic>{'hex': '#A9E0F1', 'color': Color(0xFFA9E0F1), 'label': 'Biru muda'},
  <String, dynamic>{'hex': '#E3F5A4', 'color': Color(0xFFE3F5A4), 'label': 'Kuning hijau'},
  <String, dynamic>{'hex': '#86C2D1', 'color': Color(0xFF86C2D1), 'label': 'Biru'},
  <String, dynamic>{'hex': '#D2E8C9', 'color': Color(0xFFD2E8C9), 'label': 'Hijau pucat'},
  <String, dynamic>{'hex': '#B8E6D4', 'color': Color(0xFFB8E6D4), 'label': 'Mint'},
  <String, dynamic>{'hex': '#FFD9A8', 'color': Color(0xFFFFD9A8), 'label': 'Persik'},
  <String, dynamic>{'hex': '#FFC9D6', 'color': Color(0xFFFFC9D6), 'label': 'Merah muda'},
  <String, dynamic>{'hex': '#D8CCF5', 'color': Color(0xFFD8CCF5), 'label': 'Lavender'},
  <String, dynamic>{'hex': '#F5E6A3', 'color': Color(0xFFF5E6A3), 'label': 'Kuning'},
  <String, dynamic>{'hex': '#F7B6A5', 'color': Color(0xFFF7B6A5), 'label': 'Koral'},
  <String, dynamic>{'hex': '#204654', 'color': Color(0xFF204654), 'label': 'Teal gelap'},
];

IconData iconDataForName(String? name) {
  for (final option in kCollectionIconOptions) {
    if (option['key'] == name) return option['icon'] as IconData;
  }
  return Icons.folder_outlined;
}

Color colorFromHex(String? hex, {Color fallback = const Color(0xFFA9E0F1)}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return fallback;
  }
}

/// Screen 11 — Buat Koleksi bottom sheet.
class CreateCollectionSheet extends ConsumerStatefulWidget {
  const CreateCollectionSheet({
    super.key,
    this.initialCollection,
  });

  final CollectionModel? initialCollection;

  @override
  ConsumerState<CreateCollectionSheet> createState() =>
      _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends ConsumerState<CreateCollectionSheet> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColorHex;
  late bool _isPublic;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final CollectionModel? initial = widget.initialCollection;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _selectedIcon = initial?.icon ?? 'shopping_bag';
    _selectedColorHex = initial?.color ?? '#A9E0F1';
    _isPublic = initial?.isPublic ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (widget.initialCollection != null) {
        await ref.read(collectionsProvider.notifier).updateCollection(
              widget.initialCollection!.id,
              name: name,
              icon: _selectedIcon,
              color: _selectedColorHex,
              isPublic: _isPublic,
            );
      } else {
        await ref.read(collectionsProvider.notifier).createCollection(
              name: name,
              icon: _selectedIcon,
              color: _selectedColorHex,
              isPublic: _isPublic,
            );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final UserModel? user = ref.watch(currentUserProvider).value;
    final bool isPro = user?.isPro ?? false;

    final List<CollectionModel> collections =
        ref.watch(collectionsProvider).value ?? <CollectionModel>[];
    final int customCount =
        collections.where((CollectionModel c) => !c.isDefault).length;

    final Color previewBg = colorFromHex(_selectedColorHex);
    final Color previewIconColor =
        previewBg.computeLuminance() > 0.4 ? TautinColors.brandTeal : Colors.white;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? TautinColors.darkCard : TautinColors.creamBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Grabber (.grab / .dkgrab)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? TautinColors.darkBorder
                          : TautinColors.mistTeal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header row: "Koleksi Baru" + Quota Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      widget.initialCollection != null
                          ? 'Ubah Koleksi'
                          : 'Koleksi Baru',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: isDark
                            ? TautinColors.textPrimaryDark
                            : TautinColors.brandTeal,
                      ),
                    ),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? TautinColors.darkBackground
                            : TautinColors.brandTeal,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isPro ? '👑 PRO' : '$customCount/10 terpakai',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: isDark
                              ? TautinColors.mintAccent
                              : TautinColors.creamBackground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name input row with preview icon circle (.namerow)
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? TautinColors.darkBackground : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: isDark
                        ? Border.all(color: TautinColors.darkBorder)
                        : null,
                    boxShadow: isDark
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: TautinColors.brandTeal.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: previewBg,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          iconDataForName(_selectedIcon),
                          size: 22,
                          color: previewIconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          autofocus: widget.initialCollection == null,
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: isDark
                                ? TautinColors.textPrimaryDark
                                : TautinColors.brandTeal,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nama koleksi (mis. Skripsi, Resep)...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: isDark
                                  ? TautinColors.textSecondaryDark
                                  : TautinColors.seamTeal,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Label Ikon
                Text(
                  'IKON',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: isDark
                        ? TautinColors.textSecondaryDark
                        : TautinColors.seamTeal,
                  ),
                ),
                const SizedBox(height: 8),

                // Icon picker (grid 6 columns)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: kCollectionIconOptions.length,
                  itemBuilder: (BuildContext ctx, int index) {
                    final Map<String, dynamic> item =
                        kCollectionIconOptions[index];
                    final String key = item['key'] as String;
                    final IconData icon = item['icon'] as IconData;
                    final bool isSelected = _selectedIcon == key;

                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = key),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? TautinColors.mintAccent
                                  : TautinColors.brandTeal)
                              : (isDark
                                  ? TautinColors.darkBackground
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: isDark && !isSelected
                              ? Border.all(color: TautinColors.darkBorder)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected
                              ? (isDark
                                  ? TautinColors.brandTeal
                                  : TautinColors.creamBackground)
                              : (isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Label Warna
                Text(
                  'WARNA',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: isDark
                        ? TautinColors.textSecondaryDark
                        : TautinColors.seamTeal,
                  ),
                ),
                const SizedBox(height: 8),

                // Color picker (grid 6 columns)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: kCollectionColorOptions.length,
                  itemBuilder: (BuildContext ctx, int index) {
                    final Map<String, dynamic> item =
                        kCollectionColorOptions[index];
                    final String hex = item['hex'] as String;
                    final Color color = item['color'] as Color;
                    final bool isSelected = _selectedColorHex == hex;

                    return InkWell(
                      onTap: () => setState(() => _selectedColorHex = hex),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: isDark
                                      ? Colors.white
                                      : TautinColors.brandTeal,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                        ),
                        alignment: Alignment.center,
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: color.computeLuminance() > 0.4
                                    ? TautinColors.brandTeal
                                    : Colors.white,
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // "Jadikan publik" setting row (.setrow)
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? TautinColors.darkBackground : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: isDark
                        ? Border.all(color: TautinColors.darkBorder)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.public_rounded,
                            size: 18,
                            color: isDark
                                ? TautinColors.mintAccent
                                : TautinColors.brandTeal,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Jadikan koleksi publik',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: isDark
                                  ? TautinColors.textPrimaryDark
                                  : TautinColors.brandTeal,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isPublic,
                        activeThumbColor: isDark
                            ? TautinColors.mintAccent
                            : TautinColors.brandTeal,
                        onChanged: (bool val) =>
                            setState(() => _isPublic = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Primary CTA button (.cta)
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? TautinColors.mintAccent
                          : TautinColors.brandTeal,
                      foregroundColor: isDark
                          ? TautinColors.brandTeal
                          : TautinColors.creamBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: TautinColors.brandTeal,
                            ),
                          )
                        : Text(
                            widget.initialCollection != null
                                ? 'Simpan Perubahan'
                                : 'Buat Koleksi',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
