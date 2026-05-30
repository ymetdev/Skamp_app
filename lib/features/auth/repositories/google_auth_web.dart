import 'package:firebase_auth/firebase_auth.dart';

Future<UserCredential> googleSignIn(FirebaseAuth auth) async {
  return auth.signInWithPopup(GoogleAuthProvider());
}

Future<void> googleSignOut() async {}
