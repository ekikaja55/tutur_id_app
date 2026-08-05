Oke, lanjut ke **`features/auth/`** sesuai rencana — ini fondasi untuk Login & Onboarding (SSO Google + biodata + role assignment).

## 1. `features/auth/data/models/user_model.dart`

```dart
// lib/features/auth/data/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String? photoUrl;
  final String role; // 'student' atau 'admin'
  final int battery;
  final String subscriptionTier; // 'starter', 'growth', 'ultimate'
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.phoneNumber,
    this.photoUrl,
    this.role = 'student',
    this.battery = 14,
    this.subscriptionTier = 'starter',
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      role: json['role'] as String? ?? 'student',
      battery: json['battery'] as int? ?? 14,
      subscriptionTier: json['subscriptionTier'] as String? ?? 'starter',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'role': role,
      'battery': battery,
      'subscriptionTier': subscriptionTier,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? username,
    String? phoneNumber,
    String? photoUrl,
    String? role,
    int? battery,
    String? subscriptionTier,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      battery: battery ?? this.battery,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt,
    );
  }
}
```

## 2. `features/auth/data/repositories/auth_repository.dart`

```dart
// lib/features/auth/data/repositories/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/firebase_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseService _firebaseService;

  AuthRepository(this._firebaseService);

  Stream<User?> get authStateChanges => _firebaseService.authStateChanges;

  User? get currentUser => _firebaseService.currentUser;

  Future<User> signInWithGoogle() async {
    final credential = await _firebaseService.signInWithGoogle();
    if (credential.user == null) {
      throw Exception('Gagal login dengan Google');
    }
    return credential.user!;
  }

  Future<void> signOut() => _firebaseService.signOut();

  Future<UserModel?> getUserProfile(String uid) async {
    final data = await _firebaseService.getDocument('users', uid);
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
```

## 3. `features/auth/logic/auth_provider.dart`

Update dari yang kita buat kemarin, dilengkapi jadi lebih utuh:

```dart
// lib/features/auth/logic/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/providers.dart';
import '../data/repositories/auth_repository.dart';
import '../data/models/user_model.dart';

enum UserRole { student, admin, unknown }

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseServiceProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Profile lengkap user (null kalau belum onboarding / belum ada dokumen)
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  return ref.watch(authRepositoryProvider).getUserProfile(user.uid);
});

final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return UserRole.unknown;
  return profile.role == 'admin' ? UserRole.admin : UserRole.student;
});

// Notifier untuk aksi login/logout/onboarding
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    });
    ref.invalidate(userProfileProvider); // refresh profile setelah login
  }

  Future<void> completeOnboarding({
    required String username,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw Exception('User tidak ditemukan');

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

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(
  AuthNotifier.new,
);
```

## 4. `features/auth/presentation/screens/login_screen.dart`

```dart
// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login gagal: $error')),
          );
        },
      );
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FlutterLogo(size: 96), // ganti dengan logo Tutur.id
              const SizedBox(height: 24),
              Text(
                'Tutur.id',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Belajar BISINDO secara interaktif',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              authState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () {
                        ref.read(authNotifierProvider.notifier).signInWithGoogle();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Masuk dengan Google'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 5. `features/auth/presentation/screens/onboarding_screen.dart`

```dart
// lib/features/auth/presentation/screens/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan data: $error')),
          );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Profil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sedikit lagi! Lengkapi data dirimu.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Username minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return null; // optional
                  if (!RegExp(r'^08\d{8,11}$').hasMatch(value)) {
                    return 'Format nomor telepon tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // TODO: foto profil upload (skippable) - via Cloudinary, ditambahkan nanti
              const SizedBox(height: 32),
              authState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          ref.read(authNotifierProvider.notifier).completeOnboarding(
                                username: _usernameController.text.trim(),
                                phoneNumber: _phoneController.text.trim().isEmpty
                                    ? null
                                    : _phoneController.text.trim(),
                              );
                        }
                      },
                      child: const Text('Selesai'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Catatan Penting

1. **Field `phoneNumber` boleh kosong** sesuai requirement kamu di awal — validasi cuma jalan kalau user isi sesuatu, kalau dikosongin langsung lolos.
2. **Foto profil upload** aku kasih `TODO` dulu — karena ini butuh integrasi `image_picker` + `CloudinaryService` yang sudah kita buat, sengaja aku pisah biar gak terlalu banyak sekaligus. Mau langsung aku tambahkan sekarang atau nanti?
3. **Default role saat `createUserProfile`** selalu `'student'` (sesuai default di `UserModel`) — jadi kalau kamu mau jadi admin, tetap harus manual ubah field `role` di Firestore Console setelah onboarding selesai, sesuai yang kita bahas sebelumnya.
4. Router kamu sekarang sudah bisa jalan untuk path `/login` dan `/onboarding` — tapi masih ada import ke screen lain yang belum dibuat (`learning`, `ai_training`, dst). Ganti sementara pakai `PlaceholderScreen` untuk yang belum jadi.

Mau lanjut tambahkan **upload foto profil** dulu di onboarding, atau lanjut ke fitur berikutnya (`features/learning/`) sesuai urutan TODO?
