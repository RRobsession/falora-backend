import 'package:falora/config/avatar_catalog.dart';
import 'package:falora/theme/falora_theme.dart';
import 'package:falora/widgets/user_avatar_image.dart';
import 'package:flutter/material.dart';

/// Erkek/Kadın sekmeli hazır avatar seçici — onboarding ve profil ortak.
class PresetAvatarPicker extends StatefulWidget {
  const PresetAvatarPicker({
    super.key,
    this.initialAsset,
    this.showSkip = false,
    this.confirmLabel = 'Bu avatarı kullan',
    this.onConfirm,
    this.onSkip,
    this.enabled = true,
  });

  final String? initialAsset;
  final bool showSkip;
  final String confirmLabel;
  final ValueChanged<String>? onConfirm;
  final VoidCallback? onSkip;
  final bool enabled;

  @override
  State<PresetAvatarPicker> createState() => _PresetAvatarPickerState();
}

class _PresetAvatarPickerState extends State<PresetAvatarPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedAsset;

  static const _tileSize = 80.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _selectedAsset = _resolveInitial(widget.initialAsset);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PresetAvatarPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAsset != widget.initialAsset) {
      _selectedAsset = _resolveInitial(widget.initialAsset);
    }
  }

  String? _resolveInitial(String? asset) {
    if (asset == null || asset.trim().isEmpty) return null;
    if (isCustomAvatarAsset(asset)) return null;
    final normalized = normalizeStoredAvatarAsset(asset);
    if (avatarOptionByAsset(normalized) != null) return normalized;
    return null;
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  List<AvatarOption> _optionsFor(AvatarGender gender) =>
      presetAvatars.where((a) => a.gender == gender).toList();

  int _crossAxisCount(double width) {
    if (width >= 400) return 4;
    if (width >= 320) return 3;
    return 3;
  }

  void _confirm() {
    if (!widget.enabled) return;
    final asset = _selectedAsset;
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir avatar seçin')),
      );
      return;
    }
    widget.onConfirm?.call(asset);
  }

  @override
  Widget build(BuildContext context) {
    final gender =
        _tabController.index == 0 ? AvatarGender.male : AvatarGender.female;
    final options = _optionsFor(gender);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _crossAxisCount(constraints.maxWidth);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedAsset != null) ...[
              Center(
                child: PresetAvatarThumbnail(
                  assetPath: _selectedAsset!,
                  size: 88,
                  selected: true,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              decoration: BoxDecoration(
                color: faloraParchmentRaised,
                borderRadius: BorderRadius.circular(FaloraRadius.lg),
                border: Border.all(color: faloraBronze.withValues(alpha: 0.2)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: faloraGoldDark,
                labelColor: faloraInkHeading,
                unselectedLabelColor: faloraInkSoft,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'Erkek'),
                  Tab(text: 'Kadın'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AvatarGrid(
              options: options,
              selectedAsset: _selectedAsset,
              crossAxisCount: crossAxisCount,
              tileSize: _tileSize,
              enabled: widget.enabled,
              onSelect: (path) => setState(() => _selectedAsset = path),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.enabled ? _confirm : null,
                  borderRadius: BorderRadius.circular(FaloraRadius.lg),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8D5A0), Color(0xFFD4AF37)],
                      ),
                      borderRadius: BorderRadius.circular(FaloraRadius.lg),
                      border: Border.all(color: faloraGoldDark),
                    ),
                    child: Center(
                      child: Text(
                        widget.confirmLabel,
                        style: const TextStyle(
                          color: faloraInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showSkip) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: widget.enabled ? widget.onSkip : null,
                  child: const Text('Atla'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _AvatarGrid extends StatelessWidget {
  const _AvatarGrid({
    required this.options,
    required this.selectedAsset,
    required this.crossAxisCount,
    required this.tileSize,
    required this.enabled,
    required this.onSelect,
  });

  final List<AvatarOption> options;
  final String? selectedAsset;
  final int crossAxisCount;
  final double tileSize;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Avatarlar yükleniyor…',
            style: TextStyle(color: faloraInkSoft, fontSize: 13),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: options.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selectedAsset == option.assetPath;
        return Center(
          child: _AvatarTile(
            assetPath: option.assetPath,
            size: tileSize,
            selected: isSelected,
            enabled: enabled,
            onTap: () => onSelect(option.assetPath),
          ),
        );
      },
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.assetPath,
    required this.size,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String assetPath;
  final double size;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.22;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(radius),
          child: PresetAvatarThumbnail(
            assetPath: assetPath,
            size: size,
            selected: selected,
          ),
        ),
      ),
    );
  }
}

/// Tam ekran avatar seçim sayfası.
class PresetAvatarPickerPage extends StatelessWidget {
  const PresetAvatarPickerPage({
    super.key,
    this.initialAsset,
    this.showSkip = false,
  });

  final String? initialAsset;
  final bool showSkip;

  static Future<String?> open(
    BuildContext context, {
    String? initialAsset,
    bool showSkip = false,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PresetAvatarPickerPage(
          initialAsset: initialAsset,
          showSkip: showSkip,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: faloraParchmentMid,
      appBar: AppBar(
        backgroundColor: faloraParchmentMid,
        elevation: 0,
        title: const Text(
          'Avatar Seç',
          style: TextStyle(color: faloraInkHeading, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: faloraInkHeading),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: PresetAvatarPicker(
            initialAsset: initialAsset,
            showSkip: showSkip,
            onConfirm: (asset) => Navigator.pop(context, asset),
            onSkip: showSkip ? () => Navigator.pop(context) : null,
          ),
        ),
      ),
    );
  }
}
