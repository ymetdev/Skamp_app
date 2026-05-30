import 'package:flutter/material.dart';
import '../../../models/stamp_model.dart';

// Stamp aspect ratio: W22 × H30mm  →  0.7333
const double kStampAspect = 22.0 / 30.0;

// ─── CustomClipper ────────────────────────────────────────────────────────────

class StampClipper extends CustomClipper<Path> {
  final StampShape shape;
  const StampClipper(this.shape);

  @override
  Path getClip(Size size) => StampShapePath.build(shape, size);

  @override
  bool shouldReclip(StampClipper old) => old.shape != shape;
}

// ─── Camera overlay painter ───────────────────────────────────────────────────

class StampOverlayPainter extends CustomPainter {
  final StampShape shape;
  final Rect stampRect;

  const StampOverlayPainter({required this.shape, required this.stampRect});

  @override
  void paint(Canvas canvas, Size size) {
    final stampPath = StampShapePath.build(
      shape,
      Size(stampRect.width, stampRect.height),
    ).shift(stampRect.topLeft);

    final fullRect = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlay = Path.combine(PathOperation.difference, fullRect, stampPath);

    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0xAA000000),
    );

    // White stamp border
    canvas.drawPath(
      stampPath,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(StampOverlayPainter old) =>
      old.shape != shape || old.stampRect != stampRect;
}

// ─── Shape thumbnail painter (for the shape selector UI) ─────────────────────

class StampShapePainter extends CustomPainter {
  final StampShape shape;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;

  const StampShapePainter({
    required this.shape,
    this.fillColor = Colors.transparent,
    this.strokeColor = Colors.black,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = StampShapePath.build(shape, size);

    if (fillColor != Colors.transparent) {
      canvas.drawPath(path, Paint()..color = fillColor);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(StampShapePainter old) =>
      old.shape != shape ||
      old.fillColor != fillColor ||
      old.strokeColor != strokeColor;
}

// ─── Path builder for all 8 shapes ───────────────────────────────────────────

class StampShapePath {
  StampShapePath._();

  static Path build(StampShape shape, Size size) {
    switch (shape) {
      case StampShape.rectangle:
        return _rect(size);
      case StampShape.rounded:
        return _rounded(size);
      case StampShape.zigzag:
        return _toothEdge(size, depth: size.width * 0.06, fine: false);
      case StampShape.serrated:
        return _toothEdge(size, depth: size.width * 0.04, fine: true);
      case StampShape.perforated:
        return _perforated(size);
      case StampShape.ticket:
        return _ticket(size);
      case StampShape.wave:
        return _wave(size);
      case StampShape.scalloped:
        return _scalloped(size);
    }
  }

  // ── Rectangle ──────────────────────────────────────────────────────────────

  static Path _rect(Size s) =>
      Path()..addRect(Rect.fromLTWH(0, 0, s.width, s.height));

  // ── Rounded ────────────────────────────────────────────────────────────────

  static Path _rounded(Size s) => Path()
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Radius.circular(s.width * 0.15),
    ));

  // ── Zigzag + Serrated (shared logic, different depth/pitch) ───────────────
  //
  // The "valley" base-line is inset by `d` from each edge.
  // Corner anchors: (d,d), (w-d,d), (w-d,h-d), (d,h-d).
  // Teeth peaks touch the widget boundary.

  static Path _toothEdge(Size s, {required double depth, required bool fine}) {
    final pitch = fine ? depth * 1.2 : depth * 1.8; // distance between valleys

    // steps = how many teeth fit between corner anchors
    final stepsW = ((s.width - 2 * depth) / pitch).round().clamp(4, 20);
    final stepsH = ((s.height - 2 * depth) / pitch).round().clamp(5, 28);

    final sw = (s.width - 2 * depth) / stepsW;
    final sh = (s.height - 2 * depth) / stepsH;

    final p = Path();
    p.moveTo(depth, depth); // top-left corner anchor

    // Top edge
    for (int i = 0; i < stepsW; i++) {
      final x0 = depth + i * sw;
      p.lineTo(x0 + sw / 2, 0); // peak
      p.lineTo(x0 + sw, depth); // valley
    }

    // Right edge
    for (int i = 0; i < stepsH; i++) {
      final y0 = depth + i * sh;
      p.lineTo(s.width, y0 + sh / 2); // peak
      p.lineTo(s.width - depth, y0 + sh); // valley
    }

    // Bottom edge
    for (int i = stepsW - 1; i >= 0; i--) {
      final x0 = depth + i * sw;
      p.lineTo(x0 + sw / 2, s.height); // peak
      p.lineTo(x0, s.height - depth); // valley
    }

    // Left edge
    for (int i = stepsH - 1; i >= 0; i--) {
      final y0 = depth + i * sh;
      p.lineTo(0, y0 + sh / 2); // peak
      p.lineTo(depth, y0); // valley
    }

    p.close();
    return p;
  }

  // ── Perforated ─────────────────────────────────────────────────────────────
  //
  // Classic postage-stamp: rectangle minus circles along each edge.

  static Path _perforated(Size s) {
    final r = (s.width * 0.028).clamp(3.0, 8.0);
    final step = r * 3.2;

    final base = Path()..addRect(Rect.fromLTWH(0, 0, s.width, s.height));
    final holes = Path();

    void addEdgeHoles(
        double fromX, double toX, double fromY, double toY, bool horizontal) {
      final len = horizontal ? (toX - fromX) : (toY - fromY);
      final count = (len / step).floor();
      final gap = len / count;
      for (int i = 1; i < count; i++) {
        final cx = horizontal ? fromX + i * gap : fromX;
        final cy = horizontal ? fromY : fromY + i * gap;
        holes.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      }
    }

    addEdgeHoles(0, s.width, 0, 0, true); // top
    addEdgeHoles(s.width, s.width, 0, s.height, false); // right
    addEdgeHoles(0, s.width, s.height, s.height, true); // bottom
    addEdgeHoles(0, 0, 0, s.height, false); // left

    return Path.combine(PathOperation.difference, base, holes);
  }

  // ── Ticket ─────────────────────────────────────────────────────────────────
  //
  // Rectangle with a semicircle notch cut from each long side (left & right).

  static Path _ticket(Size s) {
    final r = s.width * 0.12;
    final mid = s.height / 2;

    final p = Path();
    p.moveTo(0, 0);
    p.lineTo(s.width, 0);
    p.lineTo(s.width, mid - r);
    p.arcToPoint(Offset(s.width, mid + r),
        radius: Radius.circular(r), clockwise: false);
    p.lineTo(s.width, s.height);
    p.lineTo(0, s.height);
    p.lineTo(0, mid + r);
    p.arcToPoint(Offset(0, mid - r),
        radius: Radius.circular(r), clockwise: false);
    p.close();
    return p;
  }

  // ── Wave ───────────────────────────────────────────────────────────────────
  //
  // Sinusoidal edges via quadratic beziers, alternating peaks in/out.

  static Path _wave(Size s) {
    final d = (s.width * 0.042).clamp(4.0, 11.0);
    const stepsW = 7;
    const stepsH = 9;

    final sw = (s.width - 2 * d) / stepsW;
    final sh = (s.height - 2 * d) / stepsH;

    final p = Path();
    p.moveTo(d, d);

    // Top
    for (int i = 0; i < stepsW; i++) {
      final x0 = d + i * sw;
      final peak = i.isEven ? 0.0 : d * 2;
      p.quadraticBezierTo(x0 + sw * 0.5, peak, x0 + sw, d);
    }

    // Right
    for (int i = 0; i < stepsH; i++) {
      final y0 = d + i * sh;
      final peak = i.isEven ? s.width : s.width - d * 2;
      p.quadraticBezierTo(peak, y0 + sh * 0.5, s.width - d, y0 + sh);
    }

    // Bottom (reversed)
    for (int i = stepsW - 1; i >= 0; i--) {
      final x0 = d + i * sw;
      final peak = i.isEven ? s.height : s.height - d * 2;
      p.quadraticBezierTo(x0 + sw * 0.5, peak, x0, s.height - d);
    }

    // Left (reversed)
    for (int i = stepsH - 1; i >= 0; i--) {
      final y0 = d + i * sh;
      final peak = i.isEven ? 0.0 : d * 2;
      p.quadraticBezierTo(peak, y0 + sh * 0.5, d, y0);
    }

    p.close();
    return p;
  }

  // ── Scalloped ──────────────────────────────────────────────────────────────
  //
  // Arc-based scallops pointing outward from an inset base.

  static Path _scalloped(Size s) {
    // Scallop radius — peak touches widget edge from inset base
    final r = (s.width / 9.0).clamp(8.0, 20.0);

    // Steps along each edge (inset area = s - 2r per side)
    final nW = ((s.width - 2 * r) / (r * 2)).round().clamp(3, 9);
    final nH = ((s.height - 2 * r) / (r * 2)).round().clamp(4, 13);

    final sw = (s.width - 2 * r) / nW; // actual step width
    final sh = (s.height - 2 * r) / nH; // actual step height

    final p = Path();
    p.moveTo(r, r); // top-left corner (inset)

    // Top edge → scallops pointing up
    for (int i = 0; i < nW; i++) {
      final x0 = r + i * sw;
      p.arcToPoint(
        Offset(x0 + sw, r),
        radius: Radius.circular(sw / 2),
        clockwise: false,
      );
    }

    // Right edge ↓ scallops pointing right
    for (int i = 0; i < nH; i++) {
      final y0 = r + i * sh;
      p.arcToPoint(
        Offset(s.width - r, y0 + sh),
        radius: Radius.circular(sh / 2),
        clockwise: false,
      );
    }

    // Bottom edge ← scallops pointing down
    for (int i = nW - 1; i >= 0; i--) {
      final x0 = r + i * sw;
      p.arcToPoint(
        Offset(x0, s.height - r),
        radius: Radius.circular(sw / 2),
        clockwise: false,
      );
    }

    // Left edge ↑ scallops pointing left
    for (int i = nH - 1; i >= 0; i--) {
      final y0 = r + i * sh;
      p.arcToPoint(
        Offset(r, y0),
        radius: Radius.circular(sh / 2),
        clockwise: false,
      );
    }

    p.close();
    return p;
  }

  // ── Stamp thumbnail widget helper ──────────────────────────────────────────

  static Widget thumbnail(
    StampShape shape, {
    double size = 44,
    Color fill = Colors.transparent,
    Color stroke = Colors.black87,
    double strokeWidth = 1.5,
  }) {
    final w = size * kStampAspect;
    final h = size;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: StampShapePainter(
          shape: shape,
          fillColor: fill,
          strokeColor: stroke,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }

  // ── ClipPath widget wrapper ────────────────────────────────────────────────

  static Widget clip({
    required StampShape shape,
    required Widget child,
  }) {
    return ClipPath(
      clipper: StampClipper(shape),
      child: child,
    );
  }

  // ── Stamp-shaped image widget ──────────────────────────────────────────────

  static Widget image({
    required StampShape shape,
    required String url,
    required double width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final h = height ?? width / kStampAspect;
    return SizedBox(
      width: width,
      height: h,
      child: ClipPath(
        clipper: StampClipper(shape),
        child: Image.network(
          url,
          width: width,
          height: h,
          fit: fit,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : Container(
                  width: width,
                  height: h,
                  color: const Color(0xFFEDE8DC),
                ),
          errorBuilder: (_, __, ___) => Container(
            width: width,
            height: h,
            color: const Color(0xFFCCC5B5),
            child: const Icon(Icons.image_not_supported_outlined,
                color: Color(0xFF6B6459), size: 20),
          ),
        ),
      ),
    );
  }
}

// ─── Shape selector widget ────────────────────────────────────────────────────

class StampShapeSelector extends StatelessWidget {
  final StampShape selected;
  final ValueChanged<StampShape> onSelected;

  const StampShapeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: StampShape.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final shape = StampShape.values[i];
          final isSelected = shape == selected;
          return GestureDetector(
            onTap: () => onSelected(shape),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StampShapePath.thumbnail(
                    shape,
                    size: 28,
                    stroke: Colors.white,
                    strokeWidth: isSelected ? 1.8 : 1.2,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    shape.label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(isSelected ? 1 : 0.7),
                      fontSize: 9,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Stamp border decoration (used in journal / collection) ───────────────────

class StampBorderWidget extends StatelessWidget {
  final StampShape shape;
  final Widget child;
  final double borderWidth;
  final Color borderColor;

  const StampBorderWidget({
    super.key,
    required this.shape,
    required this.child,
    this.borderWidth = 2,
    this.borderColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: StampClipper(shape),
          child: child,
        ),
        // Border overlay
        CustomPaint(
          painter: _BorderPainter(
            shape: shape,
            color: borderColor,
            width: borderWidth,
          ),
          child: ClipPath(
            clipper: StampClipper(shape),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _BorderPainter extends CustomPainter {
  final StampShape shape;
  final Color color;
  final double width;

  const _BorderPainter(
      {required this.shape, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      StampShapePath.build(shape, size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.shape != shape || old.color != color || old.width != width;
}

