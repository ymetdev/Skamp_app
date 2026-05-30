import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/stamp_model.dart';
import '../../camera/widgets/stamp_shape_clipper.dart';
import '../providers/stamp_provider.dart';
import '../repositories/stamp_repository.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _selected = <String>{};
  bool _isSelecting = false;

  static const _mockStamps = [
    (flag: '🇨🇭', value: '1\nCHF',  color: Color(0xFF7B9EC0)),
    (flag: '🇨🇭', value: '1\nCHF',  color: Color(0xFFC4A882)),
    (flag: '🇯🇵', value: '¥\n82',   color: Color(0xFF8BC4A8)),
    (flag: '🇹🇭', value: '๑\nบาท',  color: Color(0xFFC4A87B)),
    (flag: '🇫🇷', value: '€\n1',    color: Color(0xFFA87BC4)),
    (flag: '🇬🇧', value: '£\n1',    color: Color(0xFF7BC4C4)),
  ];

  void _enterSelect(String id) {
    HapticFeedback.mediumImpact();
    setState(() { _isSelecting = true; _selected.add(id); });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _isSelecting = false;
      } else {
        _selected.add(id);
      }
    });
  }

  void _cancelSelect() => setState(() { _isSelecting = false; _selected.clear(); });

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count == 1
                    ? 'Are you sure you want to\ndelete this stamp?'
                    : 'Are you sure you want to\ndelete $count stamps?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w500, color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('No', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Yes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final ids = Set<String>.from(_selected);
    setState(() { _isSelecting = false; _selected.clear(); });
    for (final id in ids) {
      await ref.read(stampRepositoryProvider).deletePaperStamp(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stamps = ref.watch(myPaperStampsProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (bottom > 0 ? bottom : 16.0);

    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  // Left: "Delete" label or spacer
                  SizedBox(
                    width: 72,
                    child: _isSelecting
                        ? GestureDetector(
                            onTap: _cancelSelect,
                            child: const Text('Delete',
                              style: TextStyle(color: Colors.white54, fontSize: 16)),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Center: title
                  const Expanded(
                    child: Center(
                      child: Text('Collection', style: TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700,
                      )),
                    ),
                  ),
                  // Right: confirm delete button
                  SizedBox(
                    width: 72,
                    child: _isSelecting && _selected.isNotEmpty
                        ? Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _deleteSelected,
                              child: Container(
                                width: 44, height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 24),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          // Grid
          Expanded(
            child: stamps.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => _buildGrid(navH, useMock: true, realStamps: []),
              data: (list) => _buildGrid(navH, useMock: list.isEmpty, realStamps: list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(double navH, {required bool useMock, required List<PaperStamp> realStamps}) {
    final count = useMock ? _mockStamps.length : realStamps.length;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, navH + 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: kStampAspect,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (useMock) {
          final s = _mockStamps[i];
          return _StampGridCard(
            imageColor: s.color,
            flagEmoji: s.flag,
            valueText: s.value,
          );
        }
        final stamp = realStamps[i];
        final isSelected = _selected.contains(stamp.id);
        return _RealStampCard(
          stamp: stamp,
          isSelecting: _isSelecting,
          isSelected: isSelected,
          onLongPress: () => _enterSelect(stamp.id),
          onTap: () => _isSelecting ? _toggleSelect(stamp.id) : null,
        );
      },
    );
  }
}

// ─── Mock stamp card ───────────────────────────────────────────────────────────

class _StampGridCard extends StatelessWidget {
  final Color imageColor;
  final String flagEmoji;
  final String valueText;

  const _StampGridCard({
    required this.imageColor,
    required this.flagEmoji,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final pad = constraints.maxWidth * 0.09;
      return ClipPath(
        clipper: const StampClipper(StampShape.perforated),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFF5EED8)),
            Positioned(
              top: pad, left: pad, right: pad, bottom: pad,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: imageColor),
                    Positioned(
                      top: 6, right: 8,
                      child: Text(valueText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w900, height: 1.1,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, left: 8,
                      child: Text(flagEmoji,
                        style: const TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─── Real stamp card ───────────────────────────────────────────────────────────

class _RealStampCard extends StatelessWidget {
  final PaperStamp stamp;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  const _RealStampCard({
    required this.stamp,
    required this.isSelecting,
    required this.isSelected,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: LayoutBuilder(builder: (context, constraints) {
        final pad = constraints.maxWidth * 0.09;
        return Stack(
          children: [
            // Stamp image
            ClipPath(
              clipper: StampClipper(stamp.shape),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFF5EED8)),
                  Positioned(
                    top: pad, left: pad, right: pad, bottom: pad,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        stamp.thumbnailUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : Container(color: const Color(0xFFCCC5B5)),
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFFCCC5B5)),
                      ),
                    ),
                  ),
                  if (stamp.countryCode != null)
                    Positioned(
                      bottom: pad + 8, left: pad + 8,
                      child: Text(stamp.countryCode!, style: const TextStyle(fontSize: 18)),
                    ),
                ],
              ),
            ),
            // Selection overlay — dark when not selected, clear when selected
            if (isSelecting && !isSelected)
              Positioned.fill(
                child: ClipPath(
                  clipper: StampClipper(stamp.shape),
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              ),
            // Checkmark badge
            if (isSelected)
              Positioned(
                bottom: pad + 4, right: pad + 4,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                ),
              ),
          ],
        );
      }),
    );
  }
}
