import 'package:firebase_auth/firebase_auth.dart';
import 'package:tutur_id_app/core/errors/failure.dart';
import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/features/auth/data/models/user_model.dart';

class AuthRepository {
  final FirebaseService _firebaseService;

  AuthRepository(this._firebaseService);

  Stream<User?> get authStateChanges => _firebaseService.authStateChanges;
  User? get currentUser => _firebaseService.currentUser;

  Future<User> signInWithGoogle() async {
    final credentials = await _firebaseService.signInWithGoogle();
    if (credentials.user == null) {
      throw AuthFailure(message: "Failed to sign in via google");
    }
    return credentials.user!;
  }

  Future<void> signOut() => _firebaseService.signOut();

  Future<UserModel?> getUserProfile(String uid) async {
    final data = await _firebaseService.getDocument("users", uid);
    if (data == null) return null;
    return UserModel.fromJson({...data, 'uid': uid});
  }

  Future<void> createUserProfile(UserModel user) async {
    await _firebaseService.setDocument('users', user.uid, user.toJson());
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firebaseService.updateDocument('users', uid, data);
  }
}
