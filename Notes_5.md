Oke, pendekatan enum ini lebih baik daripada string bebas — lebih type-safe, gak rawan typo (`"strater"` vs `"starter"`), dan auto-complete di IDE jadi lebih membantu. Aku sesuaikan `UserModel` pakai pola yang sama, dan sekalian aku terapkan pola serupa untuk `role` biar konsisten (daripada campur: satu pakai enum, satu pakai string bebas).

## 1. `shared/enums/user_tier.dart`

Karena ini dipakai lintas fitur (auth, subscription, ai_training buat cek limit baterai), taruh di `shared/enums/` sesuai kesepakatan kita sebelumnya:

```dart
// lib/shared/enums/user_tier.dart

enum UserTier {
  starter,
  growth,
  ultimate;

  String toMap() => name;

  static UserTier fromMap(String? value) {
    if (value == null) return UserTier.starter;
    return UserTier.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserTier.starter,
    );
  }
}
```

## 2. `shared/enums/user_role.dart`

Aku samakan pola untuk role, biar konsisten (sebelumnya kita pakai string `'student'`/`'admin'` — sekarang diseragamkan jadi enum juga):

```dart
// lib/shared/enums/user_role.dart

enum UserRole {
  student,
  admin;

  String toMap() => name;

  static UserRole fromMap(String? value) {
    if (value == null) return UserRole.student;
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.student,
    );
  }
}
```

> Catatan: enum `UserRole` ini **menggantikan** enum `UserRole` yang sempat aku define inline di `features/auth/logic/auth_provider.dart` sebelumnya (yang ada `unknown` juga). Aku jelasin penyesuaiannya di bagian bawah.

## 3. Update `UserModel`

```dart
// lib/features/auth/data/models/user_model.dart
import '../../../../shared/enums/user_tier.dart';
import '../../../../shared/enums/user_role.dart';

class UserModel {
  final String uid;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;

  // Battery
  final int battery;
  final DateTime? batteryLastRefill;

  // Subscription
  final UserTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;

  // Gamification
  final int xp;
  final int streak;
  final DateTime? lastLoginDate;

  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.username,
    this.phoneNumber,
    this.photoUrl,
    this.role = UserRole.student,
    this.battery = 14,
    this.batteryLastRefill,
    this.subscriptionTier = UserTier.starter,
    this.subscriptionExpiresAt,
    this.xp = 0,
    this.streak = 0,
    this.lastLoginDate,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      username: json['username'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      role: UserRole.fromMap(json['role'] as String?),
      battery: json['battery'] as int? ?? 14,
      batteryLastRefill: json['batteryLastRefill'] != null
          ? DateTime.parse(json['batteryLastRefill'] as String)
          : null,
      subscriptionTier: UserTier.fromMap(json['subscriptionTier'] as String?),
      subscriptionExpiresAt: json['subscriptionExpiresAt'] != null
          ? DateTime.parse(json['subscriptionExpiresAt'] as String)
          : null,
      xp: json['xp'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'] as String)
          : null,
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
      'role': role.toMap(),
      'battery': battery,
      'batteryLastRefill': batteryLastRefill?.toIso8601String(),
      'subscriptionTier': subscriptionTier.toMap(),
      'subscriptionExpiresAt': subscriptionExpiresAt?.toIso8601String(),
      'xp': xp,
      'streak': streak,
      'lastLoginDate': lastLoginDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? username,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    int? battery,
    DateTime? batteryLastRefill,
    UserTier? subscriptionTier,
    DateTime? subscriptionExpiresAt,
    int? xp,
    int? streak,
    DateTime? lastLoginDate,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      battery: battery ?? this.battery,
      batteryLastRefill: batteryLastRefill ?? this.batteryLastRefill,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      subscriptionExpiresAt: subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      createdAt: createdAt,
    );
  }
}
```

## 4. Efek Domino: Update `auth_provider.dart`

Karena `UserRole` sekarang didefinisikan di `shared/enums/`, dan **tidak punya value `unknown`** (cuma `student`/`admin`), perlu sedikit penyesuaian logic di provider yang sebelumnya bergantung ke `unknown` buat nandain "belum onboarding":

```dart
// lib/features/auth/logic/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/providers.dart';
import '../../../shared/enums/user_role.dart'; // <- import dari shared, bukan define lokal
import '../data/repositories/auth_repository.dart';
import '../data/models/user_model.dart';

// HAPUS enum UserRole yang sebelumnya didefinisikan inline di sini

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseServiceProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// null = belum login ATAU belum onboarding (belum ada dokumen di Firestore)
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  return ref.watch(authRepositoryProvider).getUserProfile(user.uid);
});

// Role sekarang nullable - null artinya belum bisa ditentukan (belum login/onboarding)
final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  return profile?.role; // null kalau profile null, gak perlu 'unknown' lagi
});
```

### Kenapa `unknown` Dihapus, Bukan Ditambahin ke Enum Baru?

Karena `unknown` itu sebenarnya bukan representasi "role", tapi representasi **"belum ada data"** — beda konsep. Dengan `UserModel?` yang **nullable**, kita udah otomatis dapat state itu tanpa perlu nambah value semu ke enum. Ini lebih bersih: enum `UserRole` isinya cuma role yang **valid secara bisnis** (`student`, `admin`), sedangkan "belum tau" direpresentasikan lewat `null` di level yang lebih atas (`UserModel?`, `UserRole?`).

### Dampak ke `router.dart` — Perlu Disesuaikan Juga

Redirect logic yang sebelumnya bandingin `role == 'admin'` (string) sekarang harus pakai enum:

```dart
// di router.dart, redirect logic
final role = UserRole.fromMap(userData['role'] as String?);

if (isLoggingIn || isOnboarding) {
  return role == UserRole.admin ? '/admin' : '/learning';
}

if (role != UserRole.admin && _matchesAnyPrefix(location, _adminOnlyPrefixes)) {
  return '/access-denied';
}

if (role == UserRole.admin && _matchesAnyPrefix(location, _studentOnlyPrefixes)) {
  return '/access-denied';
}
```

Dan di `AccessDeniedScreen` yang kemarin kita buat (yang baca `roleAsync.value`), update perbandingannya dari string ke enum juga:
```dart
context.go(role == UserRole.admin ? '/admin' : '/learning');
```

## Ringkasan Perubahan yang Perlu Kamu Terapkan

| File | Perubahan |
|---|---|
| `shared/enums/user_tier.dart` | **Baru** — sesuai yang kamu kasih |
| `shared/enums/user_role.dart` | **Baru** — pola sama, buat konsistensi |
| `features/auth/data/models/user_model.dart` | Field `role` & `subscriptionTier` ganti dari `String` ke enum |
| `features/auth/logic/auth_provider.dart` | Hapus enum `UserRole` inline, import dari `shared/`, `userRoleProvider` jadi nullable |
| `app/router.dart` | Ganti perbandingan string jadi perbandingan enum |
| `core/widgets/access_denied_screen.dart` | Ganti perbandingan string jadi perbandingan enum |

Firestore rules yang kita buat kemarin **gak perlu berubah** — karena di level database, value tetap disimpan sebagai string (`"admin"`, `"starter"`, dst) lewat `.toMap()`. Enum ini murni buat type-safety di sisi Dart/Flutter aja.

Silakan lanjut buat struktur Firestore-nya. Kabari kalau sudah selesai.
