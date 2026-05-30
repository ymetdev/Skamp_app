import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';

import 'google_auth_mobile.dart'
    if (dart.library.html) 'google_auth_web.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> userStream(String uid) {
    // Sync Firebase Auth profile fields into Firestore if they're missing
    _syncProfileIfNeeded(uid);

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> _syncProfileIfNeeded(String uid) async {
    final authUser = _auth.currentUser;
    if (authUser == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final updates = <String, dynamic>{};

    if (data['photoURL'] == null && authUser.photoURL != null) {
      updates['photoURL'] = authUser.photoURL;
    }
    if (data['displayName'] == null && authUser.displayName != null) {
      updates['displayName'] = authUser.displayName;
    }

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  Future<UserCredential> signInWithGoogle() => googleSignIn(_auth);

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), googleSignOut()]);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final doc = await _firestore
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    return !doc.exists;
  }

  Future<void> setUsername(
    String uid,
    String username,
    String email, {
    String? displayName,
    String? photoURL,
  }) async {
    final lowerUsername = username.toLowerCase();
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('users').doc(uid),
      UserModel(
        uid: uid,
        email: email,
        username: lowerUsername,
        displayName: displayName,
        photoURL: photoURL,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );

    batch.set(
      _firestore.collection('usernames').doc(lowerUsername),
      {'uid': uid},
    );

    await batch.commit();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ตรวจสอบ invite code — return error message หรือ null ถ้าผ่าน
  Future<String?> verifyInviteCode(String code) async {
    final doc = await _firestore
        .collection('inviteCodes')
        .doc(code.trim().toUpperCase())
        .get();
    if (!doc.exists) return 'Invalid invite code';
    final data = doc.data()!;
    if (data['used'] == true) return 'This code has already been used';
    return null;
  }

  // ใช้ invite code — mark used และ set isInvited ใน user doc
  Future<void> redeemInviteCode(String uid, String code) async {
    final upperCode = code.trim().toUpperCase();
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('inviteCodes').doc(upperCode),
      {'used': true, 'usedBy': uid, 'usedAt': FieldValue.serverTimestamp()},
    );

    // set+merge เพราะ user doc อาจยังไม่มี (สร้างตอน username setup)
    batch.set(
      _firestore.collection('users').doc(uid),
      {'isInvited': true},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // สร้าง invite codes (admin use) — เรียกจาก Firestore console หรือ admin tool
  Future<void> createInviteCodes(List<String> codes) async {
    final batch = _firestore.batch();
    for (final code in codes) {
      batch.set(
        _firestore.collection('inviteCodes').doc(code.toUpperCase()),
        {'used': false, 'createdAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }
}
