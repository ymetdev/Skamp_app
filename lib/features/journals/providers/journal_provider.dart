import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/journal_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/journal_repository.dart';

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(),
);

final myJournalsProvider = StreamProvider<List<Journal>>((ref) {
  final uid = ref.watch(userProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(journalRepositoryProvider).journalsStream(uid);
});

final journalPagesProvider =
    StreamProvider.family<List<JournalPage>, String>((ref, journalId) {
  return ref.watch(journalRepositoryProvider).pagesStream(journalId);
});
