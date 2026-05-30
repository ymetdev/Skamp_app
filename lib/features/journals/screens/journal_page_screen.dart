import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/journal_model.dart';
import '../../../models/stamp_model.dart';
import '../../camera/widgets/stamp_shape_clipper.dart';
import '../../stamps/providers/stamp_provider.dart';
import '../providers/journal_provider.dart';
import '../repositories/journal_repository.dart';

class JournalPageScreen extends ConsumerStatefulWidget {
  final String journalId;
  final String pageId;
  const JournalPageScreen(
      {super.key, required this.journalId, required this.pageId});

  @override
  ConsumerState<JournalPageScreen> createState() => _JournalPageScreenState();
}

class _JournalPageScreenState extends ConsumerState<JournalPageScreen> {
  List<PlacedStamp>? _stamps;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(journalPagesProvider(widget.journalId));

    // Initialize stamps from stream on first load
    ref.listen(journalPagesProvider(widget.journalId), (_, next) {
      if (_stamps == null && next.value != null) {
        JournalPage? found;
        for (final p in next.value!) {
          if (p.id == widget.pageId) {
            found = p;
            break;
          }
        }
        if (found != null && mounted) {
          setState(() => _stamps = List.from(found!.stamps));
        }
      }
    });

    // Sync from current value if already loaded
    if (_stamps == null && pagesAsync.value != null) {
      for (final p in pagesAsync.value!) {
        if (p.id == widget.pageId) {
          _stamps = List.from(p.stamps);
          break;
        }
      }
    }

    Journal? journal;
    for (final j in ref.watch(myJournalsProvider).value ?? []) {
      if (j.id == widget.journalId) {
        journal = j;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          journal != null ? 'Page' : 'Journal',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: _stamps == null
          ? const Center(child: CircularProgressIndicator())
          : _PageCanvas(
              stamps: _stamps!,
              paperStyle: journal?.paperStyle ?? PaperStyle.blank,
              onStampMoved: (id, x, y, scale) {
                setState(() {
                  _stamps = _stamps!
                      .map((s) => s.id == id ? s.copyWith(x: x, y: y, scale: scale) : s)
                      .toList();
                });
                _save();
              },
              onStampDeleted: (id, stampId, isRubber) {
                setState(() {
                  _stamps = _stamps!.where((s) => s.id != id).toList();
                });
                _saveWithRestore(isRubber ? null : stampId);
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'page-edit-fab',
        backgroundColor: AppColors.inkBlack,
        foregroundColor: AppColors.cream,
        onPressed: _pickStamp,
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  Future<void> _pickStamp() async {
    final result = await showModalBottomSheet<_StampSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _StampPickerSheet(),
    );
    if (result == null || !mounted) return;

    final newStamp = PlacedStamp(
      id: const Uuid().v4(),
      stampId: result.stampId,
      isRubber: result.isRubber,
      imageUrl: result.imageUrl,
      shape: result.shape,
      x: 0.5,
      y: 0.5,
    );

    setState(() => _stamps = [..._stamps!, newStamp]);
    await _save(consumePaperStampId: result.isRubber ? null : result.stampId);
  }

  Future<void> _save({String? consumePaperStampId}) async {
    if (_stamps == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(journalRepositoryProvider).savePageStamps(
            widget.journalId,
            widget.pageId,
            _stamps!,
            consumePaperStampId: consumePaperStampId,
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveWithRestore(String? restoreStampId) async {
    if (_stamps == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(journalRepositoryProvider).savePageStamps(
            widget.journalId,
            widget.pageId,
            _stamps!,
          );
      if (restoreStampId != null) {
        await ref
            .read(journalRepositoryProvider)
            .restorePaperStamp(restoreStampId);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Page canvas ───────────────────────────────────────────────────────────────

class _PageCanvas extends StatelessWidget {
  final List<PlacedStamp> stamps;
  final PaperStyle paperStyle;
  final void Function(String id, double x, double y, double scale) onStampMoved;
  final void Function(String id, String stampId, bool isRubber) onStampDeleted;

  const _PageCanvas({
    required this.stamps,
    required this.paperStyle,
    required this.onStampMoved,
    required this.onStampDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 10 / 14,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(2, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pw = constraints.maxWidth;
                  final ph = constraints.maxHeight;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _PaperPainter(paperStyle)),
                      ),
                      ...stamps.map((s) => _DraggableStamp(
                            key: ValueKey(s.id),
                            stamp: s,
                            pageWidth: pw,
                            pageHeight: ph,
                            onMoved: (x, y, scale) =>
                                onStampMoved(s.id, x, y, scale),
                            onDelete: () =>
                                onStampDeleted(s.id, s.stampId, s.isRubber),
                          )),
                      if (stamps.isEmpty)
                        const Center(
                          child: Text(
                            'Tap + to add stamps',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Draggable stamp ───────────────────────────────────────────────────────────

class _DraggableStamp extends StatefulWidget {
  final PlacedStamp stamp;
  final double pageWidth;
  final double pageHeight;
  final void Function(double x, double y, double scale) onMoved;
  final VoidCallback onDelete;

  const _DraggableStamp({
    super.key,
    required this.stamp,
    required this.pageWidth,
    required this.pageHeight,
    required this.onMoved,
    required this.onDelete,
  });

  @override
  State<_DraggableStamp> createState() => _DraggableStampState();
}

class _DraggableStampState extends State<_DraggableStamp> {
  late double _x;
  late double _y;
  late double _scale;
  bool _isDragging = false;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _x = widget.stamp.x;
    _y = widget.stamp.y;
    _scale = widget.stamp.scale;
  }

  @override
  void didUpdateWidget(_DraggableStamp old) {
    super.didUpdateWidget(old);
    if (!_isDragging) {
      _x = widget.stamp.x;
      _y = widget.stamp.y;
      _scale = widget.stamp.scale;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = widget.pageWidth * 0.28 * _scale;
    final sh = sw / kStampAspect;
    final left = _x * widget.pageWidth - sw / 2;
    final top = _y * widget.pageHeight - sh / 2;

    return Positioned(
      left: left,
      top: top,
      width: sw,
      height: sh,
      child: GestureDetector(
        onScaleStart: (_) {
          _baseScale = _scale;
          setState(() => _isDragging = true);
        },
        onScaleUpdate: (d) {
          setState(() {
            // Single-finger drag
            _x = (_x + d.focalPointDelta.dx / widget.pageWidth).clamp(0.05, 0.95);
            _y = (_y + d.focalPointDelta.dy / widget.pageHeight).clamp(0.05, 0.95);
            // Pinch-to-scale (2+ fingers)
            if (d.pointerCount >= 2) {
              _scale = (_baseScale * d.scale).clamp(0.4, 3.0);
            }
          });
        },
        onScaleEnd: (_) {
          setState(() => _isDragging = false);
          widget.onMoved(_x, _y, _scale);
        },
        onLongPress: () => _confirmDelete(context),
        child: ClipPath(
          clipper: StampClipper(widget.stamp.shape),
          child: Image.network(
            widget.stamp.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.stampBorder),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove stamp?'),
        content: widget.stamp.isRubber
            ? const Text('The rubber stamp will go back to your collection.')
            : const Text(
                'The paper stamp will be returned to your collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete();
  }
}

// ── Stamp picker bottom sheet ─────────────────────────────────────────────────

class _StampSelection {
  final String stampId;
  final bool isRubber;
  final String imageUrl;
  final StampShape shape;
  const _StampSelection({
    required this.stampId,
    required this.isRubber,
    required this.imageUrl,
    required this.shape,
  });
}

class _StampPickerSheet extends ConsumerStatefulWidget {
  const _StampPickerSheet();

  @override
  ConsumerState<_StampPickerSheet> createState() => _StampPickerSheetState();
}

class _StampPickerSheetState extends ConsumerState<_StampPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paperStamps = ref.watch(myPaperStampsProvider).value ?? [];
    final rubberStamps = ref.watch(myRubberStampsProvider).value ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.stampBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Add Stamp',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.inkBlack,
            labelColor: AppColors.inkBlack,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'Paper (${paperStamps.length})'),
              Tab(text: 'Rubber (${rubberStamps.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _StampGrid(
                  items: paperStamps
                      .map((s) => _StampItem(
                            id: s.id,
                            imageUrl: s.thumbnailUrl,
                            shape: s.shape,
                            isRubber: false,
                          ))
                      .toList(),
                  emptyMessage: 'No stamps in your collection.\nCapture one with the camera!',
                  onTap: (item) => Navigator.pop(
                    context,
                    _StampSelection(
                      stampId: item.id,
                      isRubber: false,
                      imageUrl: item.imageUrl,
                      shape: item.shape,
                    ),
                  ),
                ),
                _StampGrid(
                  items: rubberStamps
                      .map((s) => _StampItem(
                            id: s.id,
                            imageUrl: s.imageUrl,
                            shape: s.shape,
                            isRubber: true,
                          ))
                      .toList(),
                  emptyMessage: 'No rubber stamps yet.\nUnlock them by exploring countries!',
                  onTap: (item) => Navigator.pop(
                    context,
                    _StampSelection(
                      stampId: item.id,
                      isRubber: true,
                      imageUrl: item.imageUrl,
                      shape: item.shape,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StampItem {
  final String id;
  final String imageUrl;
  final StampShape shape;
  final bool isRubber;
  const _StampItem(
      {required this.id,
      required this.imageUrl,
      required this.shape,
      required this.isRubber});
}

class _StampGrid extends StatelessWidget {
  final List<_StampItem> items;
  final String emptyMessage;
  final void Function(_StampItem) onTap;

  const _StampGrid({
    required this.items,
    required this.emptyMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: kStampAspect,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return GestureDetector(
          onTap: () => onTap(item),
          child: ClipPath(
            clipper: StampClipper(item.shape),
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.stampBorder),
            ),
          ),
        );
      },
    );
  }
}

// ── Paper background painter ──────────────────────────────────────────────────

class _PaperPainter extends CustomPainter {
  final PaperStyle style;
  const _PaperPainter(this.style);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCC5B5).withOpacity(0.45)
      ..strokeWidth = 0.5;

    switch (style) {
      case PaperStyle.blank:
        break;
      case PaperStyle.lined:
        const spacing = 24.0;
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(
              Offset(12, y), Offset(size.width - 12, y), paint);
        }
        break;
      case PaperStyle.graph:
        const spacing = 18.0;
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case PaperStyle.dotted:
        final dotPaint = Paint()
          ..color = const Color(0xFFCCC5B5).withOpacity(0.7)
          ..strokeWidth = 1;
        const spacing = 18.0;
        for (double x = spacing; x < size.width; x += spacing) {
          for (double y = spacing; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 1, dotPaint);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.style != style;
}
