import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/stamp_model.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/stamp_repository.dart';

final stampRepositoryProvider = Provider<StampRepository>((ref) {
  return StampRepository(cloudinary: ref.watch(cloudinaryServiceProvider));
});

// ── Paper stamps stream for the current user ──────────────────────────────────

final myPaperStampsProvider = StreamProvider<List<PaperStamp>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.watch(stampRepositoryProvider).paperStampsStream(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ── Rubber stamps stream ──────────────────────────────────────────────────────

final myRubberStampsProvider = StreamProvider<List<RubberStamp>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.watch(stampRepositoryProvider).rubberStampsStream(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ── Capture notifier ──────────────────────────────────────────────────────────

class StampCaptureNotifier extends Notifier<AsyncValue<PaperStamp?>> {
  @override
  AsyncValue<PaperStamp?> build() => const AsyncValue.data(null);

  Future<PaperStamp?> capture({
    required File imageFile,
    required StampShape shape,
    double? latitude,
    double? longitude,
  }) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return null;

    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(stampRepositoryProvider).createPaperStamp(
            uid: uid,
            imageFile: imageFile,
            shape: shape,
            latitude: latitude,
            longitude: longitude,
          ),
    );
    state = result;
    return result.value;
  }

  Future<PaperStamp?> captureFromBytes({
    required List<int> imageBytes,
    required StampShape shape,
    double? latitude,
    double? longitude,
  }) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return null;

    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(stampRepositoryProvider).createPaperStampFromBytes(
            uid: uid,
            imageBytes: imageBytes,
            shape: shape,
            latitude: latitude,
            longitude: longitude,
          ),
    );
    state = result;
    return result.value;
  }

  void reset() => state = const AsyncValue.data(null);
}

final stampCaptureProvider =
    NotifierProvider<StampCaptureNotifier, AsyncValue<PaperStamp?>>(
        StampCaptureNotifier.new);
