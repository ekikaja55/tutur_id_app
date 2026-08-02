import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';

enum UserRole { student, admin, unknown }

// buat stream auth state dari firebase
final authStateProvider = StreamProvider((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.authStateChanges;
});

// buat fetch user dari firestore berdasarkan state auth state yang di handle di authStateProvider
final userRoleProvider = FutureProvider<UserRole>((ref) async {
  AppLogger.i(
    "Try fetching data user from firestore",
    tag: "Auth Provider -> userRoleProvider()",
  );

  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  AppLogger.i(
    "Data from authState : $user",
    tag: "Auth Provider -> userRoleProvider()",
  );
  if (user == null) return UserRole.unknown;

  final firebaseService = ref.watch(firebaseServiceProvider);
  final userData = await firebaseService.getDocument('users', user.uid);
  AppLogger.i(
    "Data from userData : $userData",
    tag: "Auth Provider -> userRoleProvider()",
  );
  if (userData == null) return UserRole.unknown;

  final userString = userData['role'] as String? ?? 'student';
  AppLogger.i(
    "Data from userString : $userString",
    tag: "Auth Provider -> userRoleProvider()",
  );

  return userString == 'admin' ? UserRole.admin : UserRole.student;
});
