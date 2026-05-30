import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/stamp_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../camera/widgets/stamp_shape_clipper.dart';
import '../providers/stamp_provider.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamps = ref.watch(myPaperStampsProvider);
    final user = ref.watch(userProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My stamps',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _DailyLimitBadge(user: user),
          ),
        ],
      ),
      body: stamps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: AppColors.error))),
        data: (list) {
          if (list.isEmpty) return _buildEmpty(context);
          return _buildGrid(context, list);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.inkBlack,
        foregroundColor: AppColors.cream,
        onPressed: () => context.push('/camera'),
        child: const Icon(Icons.camera_alt_outlined),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<PaperStamp> stamps) {
    // Group by date
    final grouped = <String, List<PaperStamp>>{};
    for (final s in stamps) {
      final key = _dateKey(s.capturedAt);
      (grouped[key] ??= []).add(s);
    }

    final sections = grouped.entries.toList();

    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                section.key,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _StampCard(stamp: section.value[i]),
                childCount: section.value.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: kStampAspect, // 22:30
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(72, 98),
            painter: StampShapePainter(
              shape: StampShape.rounded,
              strokeColor: AppColors.stampBorder,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No stamps yet',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capture your first stamp with the camera.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/camera'),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Open camera'),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }
}

// ─── Single stamp card ─────────────────────────────────────────────────────────

class _StampCard extends StatelessWidget {
  final PaperStamp stamp;

  const _StampCard({required this.stamp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Hero(
        tag: 'stamp_${stamp.id}',
        child: Stack(
          children: [
            SizedBox.expand(
              child: StampShapePath.clip(
                shape: stamp.shape,
                child: Image.network(
                  stamp.thumbnailUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(color: AppColors.paper),
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.stampBorder,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.textSecondary, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            // Shape border overlay
            SizedBox.expand(
              child: CustomPaint(
                painter: StampShapePainter(
                  shape: stamp.shape,
                  strokeColor: AppColors.stampBorder.withOpacity(0.6),
                  strokeWidth: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _StampDetailSheet(stamp: stamp),
    );
  }
}

// ─── Detail bottom sheet ───────────────────────────────────────────────────────

class _StampDetailSheet extends StatelessWidget {
  final PaperStamp stamp;

  const _StampDetailSheet({required this.stamp});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width * 0.50;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 12 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.stampBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Stamp preview
          Hero(
            tag: 'stamp_${stamp.id}',
            child: SizedBox(
              width: w,
              height: w / kStampAspect,
              child: ClipPath(
                clipper: StampClipper(stamp.shape),
                child: Image.network(stamp.imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Metadata
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MetaChip(
                icon: Icons.schedule_outlined,
                label: _formatDate(stamp.capturedAt),
              ),
              if (stamp.countryCode != null) ...[
                const SizedBox(width: 8),
                _MetaChip(icon: Icons.location_on_outlined, label: stamp.countryCode!),
              ],
              const SizedBox(width: 8),
              _MetaChip(icon: Icons.crop_free, label: stamp.shape.label),
            ],
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                  label: const Text('Gift'),
                  onPressed: () {}, // TODO: gift flow
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.book_outlined, size: 18),
                  label: const Text('Place in journal'),
                  onPressed: () {}, // TODO: journal picker
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stampBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─── Daily limit badge ─────────────────────────────────────────────────────────

class _DailyLimitBadge extends StatelessWidget {
  final UserModel? user;

  const _DailyLimitBadge({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null || user!.isPremium) return const SizedBox.shrink();

    final now = DateTime.now();
    final isToday = user!.lastStampDate != null &&
        user!.lastStampDate!.year == now.year &&
        user!.lastStampDate!.month == now.month &&
        user!.lastStampDate!.day == now.day;
    final used = isToday ? user!.dailyStampCount : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stampBorder),
      ),
      child: Text(
        '${(3 - used).clamp(0, 3)}/3 today',
        style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}
