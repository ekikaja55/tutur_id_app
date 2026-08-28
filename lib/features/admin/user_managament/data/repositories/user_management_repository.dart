import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/auth/data/models/user_model.dart';

const _tag = 'USER_MGMT_REPO';

class UserManagementRepository {
  final FirebaseService _firebaseService;

  UserManagementRepository(this._firebaseService);

  Future<List<UserModel>> getAllUsers() async {
    final data = await _firebaseService.getCollection(
      'users',
      queryBuilder: (query) => query.orderBy('createdAt', descending: true),
    );
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<void> setSuspendStatus(String userId, bool isSuspended) async {
    await _firebaseService.updateDocument('users', userId, {
      'isSuspended': isSuspended,
    });
    AppLogger.i(
      'User $userId ${isSuspended ? "disuspend" : "diaktifkan kembali"}',
      tag: _tag,
    );
  }
}
