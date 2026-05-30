import 'package:flutter/material.dart';
import '../../../models/stamp_model.dart';
import 'stamp_shape_clipper.dart';

const _kBody = Color(0xFFDDD5C4);
const _kWing = Color(0xFFB5ACA0);
const _kBorder = Color(0xFFBFB7A7);
const _kFrame = Color(0xFF3A3530);
const _kSlot = Color(0xFFCCC4B4);
const _kBodyDark = Color(0xFFC5BDB0);
const _kTick = Color(0xFF887A6E);
const _kRed = Color(0xFFCC3333);
const _kIconBg = Color(0x58000000);

const _kHeaderH = 72.0;
const _kFooterH = 36.0;
const _kFramePad = 15.0;
const _kWingW = 13.0;
const _kSlotH = 48.0;
const _kRadius = 18.0;

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

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final machineW = sw * 0.78;
    final vfW = machineW * 0.70;
    final vfH = vfW * (30 / 22);
    final frameW = vfW + _kFramePad * 2;
    final frameH = vfH + _kFramePad * 2;
    final bodyH = _kHeaderH + frameH + _kFooterH;
    final sidePad = (machineW - frameW) / 2;
    final vfRect = Rect.fromLTWH(sidePad, _kHeaderH, frameW, frameH);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Body + Wings ────────────────────────────────────────
          SizedBox(
            width: machineW + _kWingW * 2,
            height: bodyH,
            child: Stack(
              children: [
                // Left wing
                Positioned(
                  left: 0, width: _kWingW, top: 16, bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _kWing,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(-2, 4))],
                    ),
                  ),
                ),
                // Right wing
                Positioned(
                  right: 0, width: _kWingW, top: 16, bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _kWing,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 4))],
                    ),
                  ),
                ),
                // Main body
                Positioned(
                  left: _kWingW, right: _kWingW, top: 0, bottom: 0,
                  child: _MachineBody(
                    vfRect: vfRect,
                    headerH: _kHeaderH,
                    frameW: frameW,
                    frameH: frameH,
                    footerH: _kFooterH,
                    sidePad: sidePad,
                    vfW: vfW,
                    vfH: vfH,
                    shape: shape,
                  ),
                ),
              ],
            ),
          ),

          // ── Capture slot ────────────────────────────────────────
          GestureDetector(
            onTap: isCapturing ? null : onCapture,
            child: Container(
              width: machineW - 18,
              height: _kSlotH,
              decoration: BoxDecoration(
                color: isCapturing ? _kBody : _kSlot,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                border: const Border(
                  left: BorderSide(color: _kBorder, width: 1.5),
                  right: BorderSide(color: _kBorder, width: 1.5),
                  bottom: BorderSide(color: _kBorder, width: 1.5),
                ),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 6))],
              ),
              child: isCapturing
                  ? const Center(
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _kTick),
                      ),
                    )
                  : CustomPaint(painter: _SlotPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Machine body ──────────────────────────────────────────────────────────────

class _MachineBody extends StatelessWidget {
  final Rect vfRect;
  final double headerH, frameW, frameH, footerH, sidePad, vfW, vfH;
  final StampShape shape;

  const _MachineBody({
    required this.vfRect,
    required this.headerH,
    required this.frameW,
    required this.frameH,
    required this.footerH,
    required this.sidePad,
    required this.vfW,
    required this.vfH,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // ── Beige body with transparent viewfinder hole ─────────
          Positioned.fill(
            child: CustomPaint(
              painter: _MachinePainter(vfRect: vfRect),
              isComplex: true,
            ),
          ),

          // ── Header (wordmark only — dots moved to top bar) ──────
          Positioned(
            top: 0, left: 0, right: 0, height: headerH,
            child: Center(child: Image.asset('assets/4.png', height: 24)),
          ),

          // ── Viewfinder frame + overlays ──────────────────────────
          Positioned(
            left: sidePad, top: headerH, width: frameW, height: frameH,
            child: _ViewfinderFrame(
              vfW: vfW, vfH: vfH, framePad: _kFramePad, shape: shape,
            ),
          ),

          // ── Footer ALIGN label ───────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0, height: footerH,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, size: 13, color: _kTick),
                SizedBox(width: 4),
                Text('ALIGN', style: TextStyle(fontSize: 8, color: _kTick, letterSpacing: 2.5, fontWeight: FontWeight.w600)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 13, color: _kTick),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Viewfinder frame (dark border + ruler + stamp outline) ────────────────────

class _ViewfinderFrame extends StatelessWidget {
  final double vfW, vfH, framePad;
  final StampShape shape;

  const _ViewfinderFrame({
    required this.vfW,
    required this.vfH,
    required this.framePad,
    required this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final fw = vfW + framePad * 2;
    final fh = vfH + framePad * 2;
    return SizedBox(
      width: fw,
      height: fh,
      child: Stack(
        children: [
          // Dark frame (leaves center transparent)
          Positioned.fill(
            child: CustomPaint(
              painter: _FramePainter(vfW: vfW, vfH: vfH, framePad: framePad),
            ),
          ),
          // Ruler ticks
          Positioned.fill(
            child: CustomPaint(
              painter: _RulerPainter(vfW: vfW, vfH: vfH, framePad: framePad),
            ),
          ),
          // Stamp border outline
          Positioned(
            left: framePad, top: framePad, width: vfW, height: vfH,
            child: CustomPaint(
              painter: StampShapePainter(
                shape: shape,
                strokeColor: Colors.white.withOpacity(0.6),
                strokeWidth: 1.5,
              ),
            ),
          ),
          // Top center crosshair
          Positioned(
            left: fw / 2 - 0.5, top: 3,
            child: Container(width: 1, height: framePad - 4, color: _kTick),
          ),
          // Bottom center crosshair
          Positioned(
            left: fw / 2 - 0.5, bottom: 3,
            child: Container(width: 1, height: framePad - 4, color: _kTick),
          ),
        ],
      ),
    );
  }
}

// ── Shape dots selector ───────────────────────────────────────────────────────

class _ShapeDots extends StatelessWidget {
  final StampShape selected;
  final ValueChanged<StampShape> onSelected;

  const _ShapeDots({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: StampShape.values.map((s) {
        final active = s == selected;
        return GestureDetector(
          onTap: () => onSelected(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 9 : 5,
            height: active ? 9 : 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _kRed : _kTick.withOpacity(0.4),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// Draws beige rounded body with a rectangular hole for the viewfinder.
/// Uses Path.difference (geometry) — no blend modes, works with CameraPreview platform view.
class _MachinePainter extends CustomPainter {
  final Rect vfRect;
  const _MachinePainter({required this.vfRect});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);
    const r = Radius.circular(_kRadius);

    // Machine body = rounded rect MINUS viewfinder rect (pure geometry, no blendmode)
    final body = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromRectAndRadius(bounds, r)),
      Path()..addRect(vfRect),
    );
    canvas.drawPath(body, Paint()..color = _kBody);

    // Border stroke
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, r),
      Paint()..color = _kBorder..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Subtle inner highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(1), const Radius.circular(_kRadius - 1)),
      Paint()..color = Colors.white.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _MachinePainter old) => old.vfRect != vfRect;
}

/// Draws dark frame around the transparent viewfinder area.
class _FramePainter extends CustomPainter {
  final double vfW, vfH, framePad;
  const _FramePainter({required this.vfW, required this.vfH, required this.framePad});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _kFrame;
    canvas.save();
    canvas.clipRRect(RRect.fromLTRBR(0, 0, size.width, size.height, const Radius.circular(8)));
    final l = framePad, t = framePad;
    final r = size.width - framePad, b = size.height - framePad;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, t), p);
    canvas.drawRect(Rect.fromLTRB(0, b, size.width, size.height), p);
    canvas.drawRect(Rect.fromLTRB(0, t, l, b), p);
    canvas.drawRect(Rect.fromLTRB(r, t, size.width, b), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => false;
}

/// Draws ruler tick marks on the dark frame.
class _RulerPainter extends CustomPainter {
  final double vfW, vfH, framePad;
  const _RulerPainter({required this.vfW, required this.vfH, required this.framePad});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _kTick..strokeWidth = 0.7;
    final lx = framePad, rx = framePad + vfW;
    const n = 22;
    for (var i = 0; i <= n; i++) {
      final y = framePad + vfH * i / n;
      final len = i % 11 == 0 ? 5.0 : (i % 2 == 0 ? 3.0 : 1.5);
      canvas.drawLine(Offset(lx, y), Offset(lx - len, y), p);
      canvas.drawLine(Offset(rx, y), Offset(rx + len, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => false;
}

/// Draws horizontal ridges on the capture slot.
class _SlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _kBodyDark.withOpacity(0.5)..strokeWidth = 1.4;
    const n = 7;
    final sp = size.height / (n + 1);
    final mx = size.width * 0.12;
    for (var i = 1; i <= n; i++) {
      canvas.drawLine(Offset(mx, sp * i), Offset(size.width - mx, sp * i), p);
    }
  }

  @override
  bool shouldRepaint(covariant _SlotPainter old) => false;
}

// ── Circle icon button ────────────────────────────────────────────────────────

class MachineCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const MachineCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: const BoxDecoration(color: _kIconBg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Camera bottom nav (dark pill) ─────────────────────────────────────────────

class CameraBottomNav extends StatelessWidget {
  final List<CameraNavItem> items;

  const CameraBottomNav({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(
          item.icon,
          color: item.active ? Colors.white : Colors.white54,
          size: 22,
        ),
      ),
    );
  }
}
