import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/journal_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../repositories/journal_repository.dart';

const Map<String, Color> kCoverColors = {
  'cream': Color(0xFFF0E8D0),
  'tan': Color(0xFFD4C4A8),
  'blue': Color(0xFFB8C5D6),
  'sage': Color(0xFFB5C4B5),
  'rose': Color(0xFFD4B8B8),
  'dark': Color(0xFF3A3530),
};

Color coverColorValue(String key) =>
    kCoverColors[key] ?? kCoverColors['cream']!;

bool coverIsDark(String key) => key == 'dark';

class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(myJournalsProvider);
    final user = ref.watch(userProvider).value;
    final maxJournals = (user?.isPremium ?? false) ? 999 : 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journals',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: journals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error loading journals',
                style: TextStyle(color: AppColors.error))),
        data: (list) {
          final canAdd = list.length < maxJournals;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 10 / 14,
            ),
            itemCount: list.length + (canAdd ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == list.length) {
                return _AddCard(
                  onTap: () => _showCreateDialog(context, ref),
                );
              }
              return _JournalCover(
                journal: list[i],
                onTap: () => context.push('/journal/${list[i].id}'),
                onLongPress: () => _confirmDelete(context, ref, list[i]),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => const _CreateDialog(),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Journal journal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete journal?'),
        content: Text(
            '"${journal.title}" and all its pages will be permanently deleted.'),
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
      await ref.read(journalRepositoryProvider).deleteJournal(journal.id);
    }
  }
}

// ── Journal cover card ────────────────────────────────────────────────────────

class _JournalCover extends StatelessWidget {
  final Journal journal;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _JournalCover({
    required this.journal,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bg = coverColorValue(journal.coverColor);
    final isDark = coverIsDark(journal.coverColor);
    final textColor = isDark ? Colors.white : AppColors.inkBlack;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Spine
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Text(
                    journal.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${journal.pageCount} pages',
                    style: TextStyle(
                      color: textColor.withOpacity(0.55),
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add card ──────────────────────────────────────────────────────────────────

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});

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
              Icon(Icons.add, size: 32, color: AppColors.textSecondary),
              SizedBox(height: 4),
              Text(
                'New Journal',
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

// ── Create dialog ─────────────────────────────────────────────────────────────

class _CreateDialog extends ConsumerStatefulWidget {
  const _CreateDialog();

  @override
  ConsumerState<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends ConsumerState<_CreateDialog> {
  final _titleCtrl = TextEditingController();
  PaperStyle _style = PaperStyle.blank;
  String _color = 'cream';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Journal',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            const Text('Cover',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCoverColors.entries.map((e) {
                final selected = _color == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _color = e.key),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: e.value,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: AppColors.inkBlack, width: 2.5)
                          : Border.all(color: AppColors.stampBorder),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Paper',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: PaperStyle.values.map((s) {
                final sel = _style == s;
                final label =
                    s.name[0].toUpperCase() + s.name.substring(1);
                return ChoiceChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) => setState(() => _style = s),
                  selectedColor: AppColors.inkBlack,
                  labelStyle: TextStyle(
                    color: sel ? AppColors.cream : AppColors.inkBlack,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _create,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(80, 36),
            textStyle: const TextStyle(fontSize: 13),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.cream))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final uid = ref.read(userProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(journalRepositoryProvider).createJournal(
            uid: uid,
            title: _titleCtrl.text.trim(),
            paperStyle: _style,
            coverColor: _color,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
