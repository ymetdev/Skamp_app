import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Firebase auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Firestore user doc stream
final userProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).userStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Auth actions — Riverpod v3 uses Notifier instead of StateNotifier
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signInWithEmail(email, password));
  }

  Future<void> registerWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).registerWithEmail(email, password));
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).signOut());
  }

  void reset() => state = const AsyncValue.data(null);
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);

// Username setup actions
class UsernameNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> checkAvailable(String username) {
    return ref.read(authRepositoryProvider).isUsernameAvailable(username);
  }

  Future<void> setUsername(
    String uid,
    String username,
    String email, {
    String? displayName,
    String? photoURL,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(authRepositoryProvider).setUsername(
          uid,
          username,
          email,
          displayName: displayName,
          photoURL: photoURL,
        ));
  }

  void reset() => state = const AsyncValue.data(null);
}

final usernameNotifierProvider =
    NotifierProvider<UsernameNotifier, AsyncValue<void>>(UsernameNotifier.new);

// Invite code actions
class InviteNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  // return error string หรือ null ถ้า valid
  Future<String?> verify(String code) {
    return ref.read(authRepositoryProvider).verifyInviteCode(code);
  }

  Future<void> redeem(String uid, String code) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(authRepositoryProvider).redeemInviteCode(uid, code));
  }

  void reset() => state = const AsyncValue.data(null);
}

final inviteNotifierProvider =
    NotifierProvider<InviteNotifier, AsyncValue<void>>(InviteNotifier.new);
