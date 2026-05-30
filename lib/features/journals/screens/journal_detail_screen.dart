import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/journal_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/widgets/stamp_shape_clipper.dart';
import '../providers/journal_provider.dart';
import '../repositories/journal_repository.dart';

class JournalDetailScreen extends ConsumerWidget {
  final String journalId;
  const JournalDetailScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(journalPagesProvider(journalId));
    final user = ref.watch(userProvider).value;
    final maxPages = (user?.isPremium ?? false) ? 32 : 24;

    Journal? journal;
    for (final j in ref.watch(myJournalsProvider).value ?? []) {
      if (j.id == journalId) {
        journal = j;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          journal?.title ?? 'Journal',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: pagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error', style: TextStyle(color: AppColors.error))),
        data: (pages) {
          final canAdd = pages.length < maxPages;
          return Column(
            children: [
              if (!canAdd)
                Container(
                  width: double.infinity,
                  color: AppColors.inkBlue.withOpacity(0.08),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Text(
                    '$maxPages page limit reached${maxPages == 24 ? ' — upgrade for more' : ''}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 10 / 14,
                  ),
                  itemCount: pages.length + (canAdd ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == pages.length) {
                      return _AddPageCard(
                        onTap: () =>
                            _addPage(context, ref, pages.length, maxPages),
                      );
                    }
                    return _PageThumbnail(
                      page: pages[i],
                      paperStyle:
                          journal?.paperStyle ?? PaperStyle.blank,
                      onTap: () => context
                          .push('/journal/$journalId/page/${pages[i].id}'),
                      onLongPress: () =>
                          _confirmDeletePage(context, ref, pages[i]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addPage(
    BuildContext context,
    WidgetRef ref,
    int current,
    int maxPages,
  ) async {
    if (current >= maxPages) return;
    try {
      final page =
          await ref.read(journalRepositoryProvider).addPage(journalId);
      if (context.mounted) {
        context.push('/journal/$journalId/page/${page.id}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDeletePage(
    BuildContext context,
    WidgetRef ref,
    JournalPage page,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text('Page ${page.pageNumber} will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(journalRepositoryProvider)
          .deletePage(journalId, page.id);
    }
  }
}

// ── Page thumbnail ────────────────────────────────────────────────────────────

class _PageThumbnail extends StatelessWidget {
  final JournalPage page;
  final PaperStyle paperStyle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PageThumbnail({
    required this.page,
    required this.paperStyle,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stampBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PaperPainter(paperStyle)),
              ),
              ...page.stamps.map((s) => _MiniStamp(stamp: s)),
              Positioned(
                right: 6,
                bottom: 5,
                child: Text(
                  '${page.pageNumber}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStamp extends StatelessWidget {
  final PlacedStamp stamp;
  const _MiniStamp({required this.stamp});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final pw = constraints.maxWidth;
      final ph = constraints.maxHeight;
      final sw = pw * 0.28 * stamp.scale;
      final sh = sw / kStampAspect;
      final left = stamp.x * pw - sw / 2;
      final top = stamp.y * ph - sh / 2;

      return Positioned(
        left: left,
        top: top,
        width: sw,
        height: sh,
        child: ClipPath(
          clipper: StampClipper(stamp.shape),
          child: Image.network(
            stamp.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: AppColors.stampBorder),
          ),
        ),
      );
    });
  }
}

// ── Add page card ─────────────────────────────────────────────────────────────

class _AddPageCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPageCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.stampBorder, width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 28, color: AppColors.textSecondary),
              SizedBox(height: 4),
              Text(
                'Add page',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
