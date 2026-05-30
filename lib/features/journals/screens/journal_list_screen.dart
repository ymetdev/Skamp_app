import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/journal_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../repositories/journal_repository.dart';

const Map<String, Color> kCoverColors = {
  'cream': Color(0xFFF0E8D0),
  'tan':   Color(0xFFD4C4A8),
  'blue':  Color(0xFFBDD4E8),
  'sage':  Color(0xFFB5C4B5),
  'rose':  Color(0xFFD4B8B8),
  'dark':  Color(0xFF3A3530),
};

Color coverColorValue(String key) => kCoverColors[key] ?? kCoverColors['cream']!;
bool coverIsDark(String key) => key == 'dark';

class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(myJournalsProvider);
    final user = ref.watch(userProvider).value;
    final maxJournals = (user?.isPremium ?? false) ? 999 : 3;
    final bottom = MediaQuery.of(context).padding.bottom;
    final navH = 8.0 + 64.0 + (bottom > 0 ? bottom : 16.0);

    return ColoredBox(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Journals', style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700,
                )),
              ),
            ),
          ),
          Expanded(
            child: journals.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white54)),
              error: (_, __) => _buildGrid(context, ref, [], maxJournals, navH),
              data: (list) => _buildGrid(context, ref, list, maxJournals, navH),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref,
      List<Journal> list, int maxJournals, double navH) {
    final canAdd = list.length < maxJournals;
    final count = list.length + (canAdd ? 1 : 0);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, navH + 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 10 / 14,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == list.length) {
          return _AddCard(onTap: () => _showCreateDialog(context, ref));
        }
        return _JournalCover(
          journal: list[i],
          onTap: () => context.push('/journal/${list[i].id}'),
          onLongPress: () => _confirmDelete(context, ref, list[i]),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => const _CreateDialog());
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Journal journal) async {
    final ok = await showDialog<bool>(
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
              Text('"${journal.title}"\nwill be permanently deleted.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('No', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('Yes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await ref.read(journalRepositoryProvider).deleteJournal(journal.id);
    }
  }
}

// ─── Journal cover card ────────────────────────────────────────────────────────

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
    final lineColor = (isDark ? Colors.white : Colors.black).withOpacity(0.18);
    final textColor = isDark ? Colors.white70 : const Color(0xFF888070);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Left binding line
            Positioned(
              left: 20, top: 20, bottom: 20,
              child: Container(width: 1, color: lineColor),
            ),
            // Top-right tab lines
            Positioned(
              top: 18, right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(width: 28, height: 3.5,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 5),
                  Container(width: 20, height: 3.5,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
            // Title bottom-right
            Positioned(
              bottom: 14, right: 14, left: 28,
              child: Text(
                journal.title,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add card ──────────────────────────────────────────────────────────────────

class _AddCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6B6459),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 44, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── Create dialog ─────────────────────────────────────────────────────────────

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
  void dispose() { _titleCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Journal', style: TextStyle(fontWeight: FontWeight.w700)),
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
            const Text('Cover', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: kCoverColors.entries.map((e) {
                final selected = _color == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _color = e.key),
                  child: Container(
                    width: 32, height: 32,
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
            const Text('Paper', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: PaperStyle.values.map((s) {
                final sel = _style == s;
                return ChoiceChip(
                  label: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                  selected: sel,
                  onSelected: (_) => setState(() => _style = s),
                  selectedColor: AppColors.inkBlack,
                  labelStyle: TextStyle(
                    color: sel ? AppColors.cream : AppColors.inkBlack, fontSize: 12),
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
          child: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cream))
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
