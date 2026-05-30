import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/friend_model.dart';
import '../repositories/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>(
  (_) => FriendRepository(),
);

// Live stream of my friends list
final myFriendsProvider = StreamProvider<List<FriendProfile>>((ref) {
  final uid = ref.watch(userProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(friendRepositoryProvider).friendsStream(uid);
});

// Add / remove friend actions
class FriendNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<String?> addByUsername(String targetUsername) async {
    final user = ref.read(userProvider).value;
    if (user == null) return 'Not logged in';

    state = const AsyncValue.loading();
    String? error;
    try {
      error = await ref.read(friendRepositoryProvider).addFriendByUsername(
            myUid: user.uid,
            myUsername: user.username,
            targetUsername: targetUsername,
            isPremium: user.isPremium,
          );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      error = e.toString();
    }
    return error;
  }

  Future<void> remove(String friendUid) async {
    final uid = ref.read(userProvider).value?.uid;
    if (uid == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(friendRepositoryProvider).removeFriend(uid, friendUid),
    );
  }

  void reset() => state = const AsyncValue.data(null);
}

final friendNotifierProvider =
    NotifierProvider<FriendNotifier, AsyncValue<void>>(FriendNotifier.new);
