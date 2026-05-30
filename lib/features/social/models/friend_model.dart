import 'package:cloud_firestore/cloud_firestore.dart';

class FriendProfile {
  final String uid;
  final String username;
  final String? displayName;
  final String? photoURL;
  final DateTime addedAt;

  const FriendProfile({
    required this.uid,
    required this.username,
    this.displayName,
    this.photoURL,
    required this.addedAt,
  });

  factory FriendProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FriendProfile(
      uid: doc.id,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'username': username,
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        'addedAt': FieldValue.serverTimestamp(),
      };
}
