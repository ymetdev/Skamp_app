import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/journal_model.dart';

class JournalRepository {
  final FirebaseFirestore _db;

  JournalRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _journals =>
      _db.collection('journals');

  // ── Journals ──────────────────────────────────────────────────────────────

  Stream<List<Journal>> journalsStream(String uid) => _journals
      .where('ownerId', isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Journal.fromFirestore).toList());

  Future<Journal> createJournal({
    required String uid,
    required String title,
    required PaperStyle paperStyle,
    required String coverColor,
  }) async {
    final now = DateTime.now();
    final ref = await _journals.add({
      'ownerId': uid,
      'title': title,
      'paperStyle': paperStyle.name,
      'coverColor': coverColor,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'pageCount': 0,
    });
    return Journal.fromFirestore(await ref.get());
  }

  Future<void> deleteJournal(String journalId) async {
    final pages = await _journals.doc(journalId).collection('pages').get();
    final batch = _db.batch();
    for (final p in pages.docs) {
      batch.delete(p.reference);
    }
    batch.delete(_journals.doc(journalId));
    await batch.commit();
  }

  // ── Pages ─────────────────────────────────────────────────────────────────

  Stream<List<JournalPage>> pagesStream(String journalId) => _journals
      .doc(journalId)
      .collection('pages')
      .orderBy('pageNumber')
      .snapshots()
      .map((s) => s.docs.map(JournalPage.fromFirestore).toList());

  Future<JournalPage> addPage(String journalId) async {
    final lastSnap = await _journals
        .doc(journalId)
        .collection('pages')
        .orderBy('pageNumber', descending: true)
        .limit(1)
        .get();

    final nextNum = lastSnap.docs.isEmpty
        ? 1
        : ((lastSnap.docs.first.data()['pageNumber'] as num?)?.toInt() ?? 0) + 1;

    final batch = _db.batch();
    final pageRef = _journals.doc(journalId).collection('pages').doc();
    final now = DateTime.now();

    batch.set(pageRef, {
      'journalId': journalId,
      'pageNumber': nextNum,
      'createdAt': Timestamp.fromDate(now),
      'stamps': <dynamic>[],
    });
    batch.update(_journals.doc(journalId), {
      'pageCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return JournalPage(
      id: pageRef.id,
      journalId: journalId,
      pageNumber: nextNum,
      createdAt: now,
    );
  }

  Future<void> deletePage(String journalId, String pageId) async {
    final batch = _db.batch();
    batch.delete(_journals.doc(journalId).collection('pages').doc(pageId));
    batch.update(_journals.doc(journalId), {
      'pageCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> savePageStamps(
    String journalId,
    String pageId,
    List<PlacedStamp> stamps, {
    String? consumePaperStampId,
  }) async {
    final batch = _db.batch();

    batch.update(
      _journals.doc(journalId).collection('pages').doc(pageId),
      {'stamps': stamps.map((s) => s.toMap()).toList()},
    );

    if (consumePaperStampId != null) {
      batch.update(_db.collection('stamps').doc(consumePaperStampId), {
        'isPlaced': true,
        'journalId': journalId,
        'pageId': pageId,
      });
    }

    batch.update(_journals.doc(journalId), {
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> restorePaperStamp(String stampId) async {
    await _db.collection('stamps').doc(stampId).update({
      'isPlaced': false,
      'journalId': FieldValue.delete(),
      'pageId': FieldValue.delete(),
    });
  }
}
