import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? displayName;
  final String? photoURL;
  final bool isPremium;
  final bool isInvited;
  final int dailyStampCount;
  final DateTime? lastStampDate;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.displayName,
    this.photoURL,
    this.isPremium = false,
    this.isInvited = false,
    this.dailyStampCount = 0,
    this.lastStampDate,
    required this.createdAt,
  });

  bool get canStampToday {
    if (isPremium) return true;
    if (lastStampDate == null) return true;
    final today = DateTime.now();
    final isToday = lastStampDate!.year == today.year &&
        lastStampDate!.month == today.month &&
        lastStampDate!.day == today.day;
    return !isToday || dailyStampCount < 3;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      isPremium: data['isPremium'] ?? false,
      isInvited: data['isInvited'] ?? false,
      dailyStampCount: data['dailyStampCount'] ?? 0,
      lastStampDate: (data['lastStampDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'username': username,
        'displayName': displayName,
        'photoURL': photoURL,
        'isPremium': isPremium,
        'isInvited': isInvited,
        'dailyStampCount': dailyStampCount,
        'lastStampDate':
            lastStampDate != null ? Timestamp.fromDate(lastStampDate!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
