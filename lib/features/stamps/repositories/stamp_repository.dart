import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../models/stamp_model.dart';
import '../../../core/services/cloudinary_service.dart';

class StampRepository {
  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;

  StampRepository({
    FirebaseFirestore? db,
    required CloudinaryService cloudinary,
  })  : _db = db ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary;

  // ── Capture a paper stamp ──────────────────────────────────────────────────

  Future<PaperStamp> createPaperStamp({
    required String uid,
    required File imageFile,
    required StampShape shape,
    double? latitude,
    double? longitude,
  }) async {
    final stampId = const Uuid().v4();

    final imageUrl = await _cloudinary.uploadFile(
      imageFile,
      folder: CloudinaryFolder.stamps,
      publicId: '$uid/$stampId',
    );
    final thumbUrl = _cloudinary.thumbnailUrl(imageUrl, size: 400);

    final stamp = PaperStamp(
      id: stampId,
      ownerId: uid,
      imageUrl: imageUrl,
      thumbnailUrl: thumbUrl,
      shape: shape,
      capturedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    await _db.collection('stamps').doc(stampId).set(stamp.toFirestore());
    await _incrementDailyCount(uid);

    return stamp;
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Unplaced paper stamps in the collection
  Stream<List<PaperStamp>> paperStampsStream(String uid) {
    return _db
        .collection('stamps')
        .where('ownerId', isEqualTo: uid)
        .where('isPlaced', isEqualTo: false)
        .orderBy('capturedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PaperStamp.fromFirestore).toList());
  }

  /// Rubber stamps unlocked by this user
  Stream<List<RubberStamp>> rubberStampsStream(String uid) {
    return _db
        .collection('rubberStamps')
        .where('ownerId', isEqualTo: uid)
        .orderBy('unlockedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(RubberStamp.fromFirestore).toList());
  }

  // ── Capture from bytes (cropped image) ────────────────────────────────────

  Future<PaperStamp> createPaperStampFromBytes({
    required String uid,
    required List<int> imageBytes,
    required StampShape shape,
    double? latitude,
    double? longitude,
  }) async {
    final stampId = const Uuid().v4();

    final imageUrl = await _cloudinary.uploadBytes(
      imageBytes,
      'stamp_$stampId.png',
      folder: CloudinaryFolder.stamps,
      publicId: '$uid/$stampId',
    );
    final thumbUrl = _cloudinary.thumbnailUrl(imageUrl, size: 400);

    final stamp = PaperStamp(
      id: stampId,
      ownerId: uid,
      imageUrl: imageUrl,
      thumbnailUrl: thumbUrl,
      shape: shape,
      capturedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    await _db.collection('stamps').doc(stampId).set(stamp.toFirestore());
    await _incrementDailyCount(uid);
    return stamp;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deletePaperStamp(String stampId) async {
    await _db.collection('stamps').doc(stampId).delete();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _incrementDailyCount(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final now = DateTime.now();

    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data()!;

      final lastDate = (data['lastStampDate'] as Timestamp?)?.toDate();
      final isToday = lastDate != null &&
          lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day;

      tx.update(ref, {
        'dailyStampCount': isToday ? (data['dailyStampCount'] ?? 0) + 1 : 1,
        'lastStampDate': Timestamp.fromDate(now),
      });
    });
  }

  /// Check if user can still stamp today (returns remaining count or -1 for unlimited)
  Future<int> remainingStampsToday(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data()!;
    final isPremium = data['isPremium'] ?? false;
    if (isPremium) return -1;

    final lastDate = (data['lastStampDate'] as Timestamp?)?.toDate();
    final count = (data['dailyStampCount'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    final isToday = lastDate != null &&
        lastDate.year == now.year &&
        lastDate.month == now.month &&
        lastDate.day == now.day;

    if (!isToday) return 3;
    return (3 - count).clamp(0, 3);
  }
}
