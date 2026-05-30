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
  _Machine('assets/x1.png', StampShape.perforated),
  _Machine('assets/x2.png', StampShape.serrated),
  _Machine('assets/x3.png', StampShape.rounded),
  _Machine('assets/x4.png', StampShape.rectangle),
];

// ─── Main overlay ─────────────────────────────────────────────────────────────

class StampMachineOverlay extends StatelessWidget {
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

  int get _machineIndex {
    final idx = _kMachines.indexWhere((m) => m.shape == shape);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width * 0.82;
    final machine = _kMachines[_machineIndex];

    return Center(
      child: SizedBox(
        width: w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Machine PNG — transparent viewfinder lets camera show through
            Image.asset(
              machine.asset,
              width: w,
              fit: BoxFit.contain,
            ),

            // Invisible capture button over the slot area (bottom ~18% of machine)
            Positioned(
              bottom: 0,
              left: w * 0.08,
              right: w * 0.08,
              height: w * 0.20,
              child: GestureDetector(
                onTap: isCapturing ? null : onCapture,
                child: isCapturing
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_kMachines.length, (i) {
        final machine = _kMachines[i];
        final active = machine.shape == selected;
        return GestureDetector(
          onTap: () => onSelected(machine.shape),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 9 : 5,
            height: active ? 9 : 5,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? Colors.white : Colors.white38,
            ),
          ),
        );
      }),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
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
