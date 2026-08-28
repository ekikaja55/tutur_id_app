import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/admin/user_managament/data/repositories/user_management_repository.dart';
import 'package:tutur_id_app/features/auth/data/models/user_model.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((
  ref,
) {
  return UserManagementRepository(ref.watch(firebaseServiceProvider));
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  return ref.watch(userManagementRepositoryProvider).getAllUsers();
});

class UserManagementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> toggleSuspend(String userId, bool currentStatus) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(userManagementRepositoryProvider)
          .setSuspendStatus(userId, !currentStatus);
    });
    ref.invalidate(allUsersProvider);
  }
}

final userManagementNotifierProvider =
    AsyncNotifierProvider<UserManagementNotifier, void>(
      UserManagementNotifier.new,
    );
