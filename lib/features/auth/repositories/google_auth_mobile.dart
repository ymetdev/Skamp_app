import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

const _serverClientId =
    '920019057231-taa7m9r199ff4uaks4kubb301qv3c7ug.apps.googleusercontent.com';

bool _initialized = false;

Future<UserCredential> googleSignIn(FirebaseAuth auth) async {
  if (!_initialized) {
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _initialized = true;
  }
  final googleUser = await GoogleSignIn.instance.authenticate();
  final googleAuth = googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,
  );
  return auth.signInWithCredential(credential);
}

Future<void> googleSignOut() async {
  await GoogleSignIn.instance.disconnect();
}
