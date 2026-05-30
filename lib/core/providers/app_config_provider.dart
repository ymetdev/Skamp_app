import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  final bool inviteOnly;
  const AppConfig({this.inviteOnly = true});

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    return AppConfig(inviteOnly: data['inviteOnly'] ?? true);
  }
}

// Stream config จาก Firestore — default inviteOnly: true ถ้ายังไม่มี doc
final appConfigProvider = StreamProvider<AppConfig>((ref) {
  return FirebaseFirestore.instance
      .collection('config')
      .doc('app')
      .snapshots()
      .map((doc) => doc.exists
          ? AppConfig.fromFirestore(doc.data()!)
          : const AppConfig(inviteOnly: true));
});
