import 'package:flutter/material.dart';
import '../../../models/stamp_model.dart';
import 'stamp_shape_clipper.dart';

// ─── Machine configs: 4 machines → 4 stamp shapes ────────────────────────────

class _Machine {
  final String asset;
  final StampShape shape;
  const _Machine(this.asset, this.shape);
}

const _kMachines = [
  _Machine('assets/machine_perforated.png', StampShape.perforated),
  _Machine('assets/machine_serrated.png', StampShape.serrated),
  _Machine('assets/machine_rounded.png', StampShape.rounded),
  _Machine('assets/machine_rect.png', StampShape.rectangle),
];

// ─── Main overlay ─────────────────────────────────────────────────────────────

class StampMachineOverlay extends StatefulWidget {
  final StampShape shape;
  final bool isCapturing;
  final VoidCallback onCapture;
  final ValueChanged<StampShape> onShapeSelected;

  const StampMachineOverlay({
    super.key,
    required this.shape,
    required this.isCapturing,
    required this.onCapture,
    required this.onShapeSelected,
  });

  @override
  State<StampMachineOverlay> createState() => _StampMachineOverlayState();
}

class _StampMachineOverlayState extends State<StampMachineOverlay> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final idx = _kMachines.indexWhere((m) => m.shape == widget.shape);
    _pageController = PageController(initialPage: idx >= 0 ? idx : 0);
  }

  @override
  void didUpdateWidget(StampMachineOverlay old) {
    super.didUpdateWidget(old);
    if (old.shape != widget.shape && _pageController.hasClients) {
      final idx = _kMachines.indexWhere((m) => m.shape == widget.shape);
      if (idx >= 0) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * .8;

    return PageView.builder(
      controller: _pageController,
      clipBehavior: Clip.none,
      itemCount: _kMachines.length,
      onPageChanged: (i) => widget.onShapeSelected(_kMachines[i].shape),
      itemBuilder: (context, i) {
        final machine = _kMachines[i];
        return OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.isCapturing ? null : widget.onCapture,
            child: SizedBox(
              width: w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(machine.asset, width: w, fit: BoxFit.contain),
                  if (widget.isCapturing)
                    const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}



// ─── Machine shape selector (4 machines) ─────────────────────────────────────

class MachineSelector extends StatelessWidget {
  final StampShape selected;
  final ValueChanged<StampShape> onSelected;

  const MachineSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_kMachines.length, (i) {
          final machine = _kMachines[i];
          final active = machine.shape == selected;
          return GestureDetector(
            onTap: () => onSelected(machine.shape),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(active ? 1.0 : 0.3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Helpers re-exported for camera screen ────────────────────────────────────

List<StampShape> get machineShapes => _kMachines.map((m) => m.shape).toList();

// ─── Circle icon button ───────────────────────────────────────────────────────

class MachineCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const MachineCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0x80FFFFFF),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

// ─── Camera bottom nav pill ───────────────────────────────────────────────────

class CameraBottomNav extends StatelessWidget {
  final List<CameraNavItem> items;
  const CameraBottomNav({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) => _NavIcon(item: item)).toList(),
      ),
    );
  }
}

class CameraNavItem {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const CameraNavItem({required this.icon, this.active = false, required this.onTap});
}

class _NavIcon extends StatelessWidget {
  final CameraNavItem item;
  const _NavIcon({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 40,
        decoration: BoxDecoration(
          color: item.active ? Colors.white.withOpacity(0.88) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(item.icon, color: item.active ? Colors.black : Colors.white, size: 22),
      ),
    );
  }
}
