import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/errors/failure.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/auth/data/models/user_model.dart';
import 'package:tutur_id_app/features/auth/data/repositories/auth_repository.dart';
import 'package:tutur_id_app/shared/enums/user_role.dart';

// define provider dari auth repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseServiceProvider));
});

// buat stream auth state dari firebase
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// buat state profile user (null kalau belum onboarding / belum ada dokumen)
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  return ref.watch(authRepositoryProvider).getUserProfile(user.uid);
});

// buat state  user dari firestore berdasarkan state auth state yang di handle di authStateProvider
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  AppLogger.i(
    "Try watch ref from userProfileProvider()",
    tag: "Auth Provider -> userRoleProvider()",
  );

  final profile = await ref.watch(userProfileProvider.future);
  AppLogger.i(
    "Data from profile : $profile",
    tag: "Auth Provider -> userRoleProvider()",
  );
  return profile?.role;
});

class AuthNotifier extends AsyncNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    });
    ref.invalidate(userProfileProvider);
  }

  Future<void> completeOnboarding({
    required String username,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw AuthFailure(message: "User not found");

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        username: username,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        createdAt: DateTime.now(),
      );
      await ref.read(authRepositoryProvider).createUserProfile(newUser);
    });
    ref.invalidate(userProfileProvider);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
    ref.invalidate(userProfileProvider);
  }
}

// inisiasi instance provider
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
