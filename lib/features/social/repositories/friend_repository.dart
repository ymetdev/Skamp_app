import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_model.dart';

class FriendRepository {
  final FirebaseFirestore _db;

  FriendRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _friendsCol(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  // ── Streams ────────────────────────────────────────────────────────────────

  Stream<List<FriendProfile>> friendsStream(String uid) {
    return _friendsCol(uid)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FriendProfile.fromFirestore).toList());
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<bool> isFriend(String myUid, String friendUid) async {
    final doc = await _friendsCol(myUid).doc(friendUid).get();
    return doc.exists;
  }

  Future<int> friendCount(String uid) async {
    final snap = await _friendsCol(uid).count().get();
    return snap.count ?? 0;
  }

  // ── Add friend by username ────────────────────────────────────────────────
  // Returns error message or null on success

  Future<String?> addFriendByUsername({
    required String myUid,
    required String myUsername,
    required String targetUsername,
    required bool isPremium,
  }) async {
    final lower = targetUsername.trim().toLowerCase();

    if (lower == myUsername.toLowerCase()) {
      return 'You cannot add yourself';
    }

    // Look up uid from username index
    final usernameDoc =
        await _db.collection('usernames').doc(lower).get();
    if (!usernameDoc.exists) return 'Username not found';

    final friendUid = usernameDoc.data()!['uid'] as String?;
    if (friendUid == null) return 'Username not found';

    // Check limit (free: 20, premium: unlimited)
    if (!isPremium) {
      final count = await friendCount(myUid);
      if (count >= 20) return 'Free accounts can have up to 20 friends';
    }

    // Check already friends
    if (await isFriend(myUid, friendUid)) return 'Already friends';

    // Get friend's profile
    final friendDoc = await _db.collection('users').doc(friendUid).get();
    if (!friendDoc.exists) return 'User not found';
    final friendData = friendDoc.data()!;

    // Write to my friends subcollection only (one-directional: I follow them)
    await _friendsCol(myUid).doc(friendUid).set({
      'username': friendData['username'] as String? ?? lower,
      if (friendData['displayName'] != null)
        'displayName': friendData['displayName'],
      if (friendData['photoURL'] != null) 'photoURL': friendData['photoURL'],
      'addedAt': FieldValue.serverTimestamp(),
    });

    return null; // success
  }

  // ── Remove friend ─────────────────────────────────────────────────────────

  Future<void> removeFriend(String myUid, String friendUid) async {
    await _friendsCol(myUid).doc(friendUid).delete();
  }

  // ── Friends' UIDs (for feed queries) ─────────────────────────────────────

  Future<List<String>> friendUids(String myUid) async {
    final snap = await _friendsCol(myUid).get();
    return snap.docs.map((d) => d.id).toList();
  }
}
