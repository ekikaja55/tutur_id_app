## 1. `core/network/api_client.dart`

Dio wrapper generik, dipakai oleh Cloudinary & Midtrans service.

```dart
// lib/core/network/api_client.dart
import 'package:dio/dio.dart';

class ApiClient {
  late final Dio dio;

  ApiClient({String? baseUrl}) {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }
}
```

## 2. `core/errors/failure.dart`

Class error umum, dipakai buat handling error di semua repository.

```dart
// lib/core/errors/failure.dart
class Failure {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  String toString() => 'Failure: $message${statusCode != null ? " ($statusCode)" : ""}';
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Tidak ada koneksi internet']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Terjadi kesalahan pada server', super.statusCode]);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Autentikasi gagal']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Data tidak ditemukan']);
}
```

## 3. `core/services/firebase_service.dart`

Wrapper untuk Auth + Firestore.Fokus di method generik dulu — nanti tiap repository fitur(misal`LearningRepository`) tinggal panggil method di sini.

```dart
// lib/core/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ---------- AUTH ----------

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Login dibatalkan oleh pengguna');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ---------- FIRESTORE: generic read/write ----------

  Future<Map<String, dynamic>?> getDocument(String collection, String docId) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
  }) async {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
        .toList();
  }

  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = true,
  }) async {
    await _firestore.collection(collection).doc(docId).set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  Stream<Map<String, dynamic>?> streamDocument(String collection, String docId) {
    return _firestore
        .collection(collection)
        .doc(docId)
        .snapshots()
        .map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> streamCollection(
    String collection, {
    Query Function(Query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
              .toList(),
        );
  }
}
```

## 4. `core/services/cloudinary_service.dart`

  ```dart
// lib/core/services/cloudinary_service.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  late final CloudinaryPublic _cloudinary;

  CloudinaryService() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
    // Upload preset unsigned perlu dibuat dulu di Cloudinary Console
    // Settings > Upload > Add upload preset > set "Signing Mode: Unsigned"
    _cloudinary = CloudinaryPublic(cloudName, 'tutur_id_unsigned', cache: false);
  }

  Future<String> uploadImage(File file, {String folder = 'tutur_id'}) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

2  Future<String> uploadVideo(File file, {String folder = 'tutur_id'}) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Video,
      ),
    );
    return response.secureUrl;
  }
}
```

  > Catatan: package `cloudinary_public` pakai ** unsigned upload preset ** (dibuat di Cloudinary Console → Settings → Upload → Add upload preset, set mode ke "Unsigned"). Ini supaya upload dari client aman tanpa expose `CLOUDINARY_API_SECRET` — secret itu cuma dipakai kalau kamu butuh operasi admin(delete, transform advanced) dari server / Cloud Function, bukan dari client Flutter langsung.

## 5. `core/services/midtrans_service.dart`

  ```dart
// lib/core/services/midtrans_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../network/api_client.dart';
import '../errors/failure.dart';

class MidtransService {
  final ApiClient _apiClient;

  MidtransService(this._apiClient);

  Future<String> createTransactionToken({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final serverKey = dotenv.env['MIDTRANS_SERVER_KEY']!;
      final isProduction = dotenv.env['MIDTRANS_IS_PRODUCTION'] == 'true';

      final baseUrl = isProduction
          ? 'https://app.midtrans.com/snap/v1/transactions'
          : 'https://app.sandbox.midtrans.com/snap/v1/transactions';

      final authString = base64Encode(utf8.encode('$serverKey:'));

      final response = await _apiClient.dio.post(
        baseUrl,
        options: Options(headers: {'Authorization': 'Basic $authString'}),
        data: {
          'transaction_details': {
            'order_id': orderId,
            'gross_amount': grossAmount,
          },
          'customer_details': {
            'first_name': customerName,
            'email': customerEmail,
          },
        },
      );

      return response.data['token'];
    } catch (e) {
      throw ServerFailure('Gagal membuat transaksi: $e');
    }
  }
}
```

Tambahkan import yang dibutuhkan di atas file:
```dart
import 'dart:convert';
import 'package:dio/dio.dart';
```

  > ⚠️ ** Penting soal keamanan Midtrans **: Memanggil Midtrans API langsung dari client app(seperti contoh di atas) berarti`MIDTRANS_SERVER_KEY` ** ikut ter - bundle di APK ** kamu — walau di `.env` dan gak keliatan di source code, secara teknis masih bisa di - extract dari APK dengan reverse engineering.Untuk skripsi / demo ini ** acceptable sebagai simplifikasi **, tapi kalau nanti production sungguhan, sebaiknya request token ini dilakukan lewat ** backend / Cloud Function **, bukan langsung dari client.Aku sarankan catat ini juga sebagai known limitation di laporan kamu, sama kayak soal Firestore rules kemarin.

## Providers untuk Semua Service

Riverpod provider dasar supaya semua service ini bisa diakses via `ref.watch()`:

```dart
// lib/core/services/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_service.dart';
import 'cloudinary_service.dart';
import 'midtrans_service.dart';
import '../network/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) => CloudinaryService());

final midtransServiceProvider = Provider<MidtransService>((ref) {
  return MidtransService(ref.watch(apiClientProvider));
});
```

---

  Semua fondasi `core/` sudah siap.Selanjutnya sesuai TODO kita bisa mulai fitur pertama: ** `features/auth/` ** (Login & Onboarding).Mau lanjut ke situ ?

  Betul, aku lewat itu. Ini kita setup `app/router.dart` dan `app/app.dart` pakai `go_router`, terintegrasi sama Riverpod supaya nanti gampang dipakai buat auth guard (misal redirect ke login kalau belum auth).

## 1. `app/router.dart`

```dart
// lib/app/router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/providers.dart';

// import screens (nanti diisi bertahap sesuai fitur yang sudah dibuat)
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/learning/presentation/screens/learning_home_screen.dart';
import '../features/ai_training/presentation/screens/ai_training_screen.dart';
import '../features/subscription/presentation/screens/subscription_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/notification/presentation/screens/notification_screen.dart';

// Admin screens
import '../features/admin/user_management/presentation/screens/user_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    // Auth guard: redirect otomatis berdasarkan status login
    redirect: (context, state) {
      final isLoggedIn = firebaseService.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/learning';
      }
      return null; // no redirect
    },

    // Re-evaluate redirect setiap auth state berubah
    refreshListenable: GoRouterRefreshStream(firebaseService.authStateChanges),

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/learning',
        builder: (context, state) => const LearningHomeScreen(),
        routes: [
          GoRoute(
            path: 'level/:levelId',
            builder: (context, state) {
              final levelId = state.pathParameters['levelId']!;
              return LearningHomeScreen(levelId: levelId); // sesuaikan constructor
            },
          ),
        ],
      ),
      GoRoute(
        path: '/ai-training/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          return AiTrainingScreen(moduleId: moduleId);
        },
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),

      // Admin routes (web)
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
```

## 2. Helper `GoRouterRefreshStream`

`go_router` butuh `Listenable`, sedangkan Firebase auth state berupa `Stream`. Ini adapter kecil untuk convert:

```dart
// lib/app/router.dart (tambahkan di file yang sama, atau pisah jadi utils)
import 'dart:async';
import 'package:flutter/foundation.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

## 3. `app/app.dart`

```dart
// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/colors.dart';
import 'theme/text_styles.dart';

class TuturApp extends ConsumerWidget {
  const TuturApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Tutur.id',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: AppTextStyles.textTheme,
      ),
      routerConfig: router,
    );
  }
}
```

## 4. `app/theme/colors.dart` (contoh dasar)

```dart
// lib/app/theme/colors.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF); // sesuaikan brand color Tutur.id
  static const secondary = Color(0xFF03DAC6);
  static const background = Color(0xFFF5F5F5);
  static const error = Color(0xFFB00020);
  static const success = Color(0xFF4CAF50);
}
```

## 5. `app/theme/text_styles.dart` (contoh dasar)

```dart
// lib/app/theme/text_styles.dart
import 'package:flutter/material.dart';

class AppTextStyles {
  static const textTheme = TextTheme(
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    bodyLarge: TextStyle(fontSize: 16),
    bodyMedium: TextStyle(fontSize: 14),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}
```

## Catatan Penting

1. **Import screen yang belum dibuat akan error** — file `router.dart` di atas mengasumsikan semua screen (`LoginScreen`, `OnboardingScreen`, dst) sudah ada. Karena kita **belum bikin fitur `auth/` sama sekali**, kode ini **belum bisa di-compile** kalau langsung dipasang sekarang.

2. **Saran urutan kerja**: supaya `router.dart` ini gak jadi bottleneck, kita bikin dulu **skeleton screen kosong** (placeholder `Scaffold` sederhana) untuk tiap fitur, baru diisi detailnya bertahap. Atau, kita bisa mulai dari fitur `auth/` dulu (sesuai urutan TODO), lalu update `router.dart` cuma untuk route yang sudah ada screennya, sisanya ditambah belakangan.

3. **Web vs Mobile routing** — saat ini semua route digabung dalam satu `GoRouter`. Nanti pas masuk ke fitur admin, kita perlu mikirkan apakah mau **split app** (mobile app khusus pelajar, web app khusus admin — dua entry point beda) atau **satu app dengan conditional routing** berdasarkan platform (`kIsWeb`). Ini keputusan arsitektur yang perlu didiskusikan sebelum fitur admin dikerjakan.

Mau aku bikinkan dulu skeleton screen kosong untuk semua fitur (biar `router.dart` bisa langsung jalan tanpa error), atau langsung fokus kerjain `features/auth/` dulu sesuai urutan TODO baru nanti `router.dart` disesuaikan?

Setuju, placeholder widget ini bakal sering dipakai. Dan soal routing berdasarkan role, pendekatanmu udah benar arahnya — aku detailkan strateginya plus kenapa perlu sedikit penyesuaian dari asumsi awal.

## 1. `core/widgets/placeholder_screen.dart`

```dart
// lib/core/widgets/placeholder_screen.dart
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.icon = Icons.construction,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '🚧 Under Construction',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
```

Dipakai sementara di `router.dart` untuk semua screen yang belum jadi:
```dart
GoRoute(
  path: '/learning',
  builder: (context, state) => const PlaceholderScreen(
    title: 'Learning Module',
    icon: Icons.school,
    subtitle: 'Modul belajar BISINDO akan tampil di sini',
  ),
),
```

Begitu fitur asli sudah jadi, tinggal ganti `PlaceholderScreen(...)` jadi screen sungguhan tanpa ubah struktur route lain.

## 2. Soal Role-Based Routing

Ide kamu benar secara konsep, tapi ada **satu detail penting** yang perlu diluruskan dulu:

### Masalah dengan asumsi awal
"Login berdasarkan email terdeteksi role admin" — ini agak riskan kalau deteksinya cuma dari **pattern email** (misal domain tertentu). Yang lebih aman: **role disimpan sebagai field di Firestore** (`users/{uid}` → `role: "admin"` atau `role: "student"`), **bukan** ditebak dari format email. Firebase Auth cuma tahu "siapa yang login", bukan "apa perannya" — perannya harus kamu simpan sendiri di database.

### Alur yang aku sarankan

```
1. User login via Google SSO (Firebase Auth)
   ↓
2. Setelah auth berhasil, sistem fetch dokumen users/{uid} dari Firestore
   ↓
3. Cek field `role`:
   - Kalau dokumen belum ada (user baru) → arahkan ke /onboarding,
     default role = "student"
   - Kalau role == "admin" → arahkan ke /admin/*
   - Kalau role == "student" → arahkan ke /learning (home pelajar)
```

### Kenapa Tidak Bikin 2 Aplikasi Terpisah (Split App)?

Sempat aku singgung ini sebagai opsi kemarin, tapi setelah dipikir lagi, untuk kasus kamu **satu codebase dengan conditional routing lebih baik**, karena:
- Admin kamu (dosen pembimbing/kamu sendiri) kemungkinan besar **akses dari browser/web**, sementara pelajar akses dari **mobile**. Tapi gak menutup kemungkinan admin butuh cek dari mobile juga sewaktu-waktu.
- Kalau split app total (2 project Flutter terpisah), kamu jadi maintain 2 codebase, 2 kali build config, duplikasi banyak `core/` — overhead besar untuk manfaat yang sebenarnya bisa diselesaikan cukup dengan role-based redirect.

## 3. Implementasi: Provider untuk Role User

```dart
// lib/features/auth/logic/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';

enum UserRole { student, admin, unknown }

// Stream auth state dari Firebase (User? null kalau belum login)
final authStateProvider = StreamProvider((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.authStateChanges;
});

// Fetch role user dari Firestore, reactive terhadap perubahan auth state
final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) return UserRole.unknown;

  final firebaseService = ref.watch(firebaseServiceProvider);
  final userData = await firebaseService.getDocument('users', user.uid);

  if (userData == null) return UserRole.unknown; // belum onboarding

  final roleString = userData['role'] as String? ?? 'student';
  return roleString == 'admin' ? UserRole.admin : UserRole.student;
});
```

## 4. Update `router.dart` dengan Role-Based Redirect

```dart
// lib/app/router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);

  return GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,

    redirect: (context, state) async {
      final isLoggedIn = firebaseService.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Belum login, dan bukan di halaman login → paksa ke login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // Sudah login tapi masih di halaman login → cek role & arahkan
      if (isLoggedIn) {
        final userData = await firebaseService.getDocument(
          'users',
          firebaseService.currentUser!.uid,
        );

        // User baru, belum ada data di Firestore → wajib onboarding dulu
        if (userData == null) {
          return isOnboarding ? null : '/onboarding';
        }

        final role = userData['role'] as String? ?? 'student';

        // Kalau lagi di /login atau /onboarding tapi sudah lengkap datanya
        if (isLoggingIn || isOnboarding) {
          return role == 'admin' ? '/admin/users' : '/learning';
        }

        // Proteksi: student coba akses /admin/* → tolak, redirect ke /learning
        if (state.matchedLocation.startsWith('/admin') && role != 'admin') {
          return '/learning';
        }

        // Proteksi: admin coba akses halaman khusus student (opsional,
        // tergantung apakah admin boleh juga akses fitur belajar)
        // if (role == 'admin' && state.matchedLocation.startsWith('/learning')) {
        //   return '/admin/users';
        // }
      }

      return null; // no redirect
    },

    refreshListenable: GoRouterRefreshStream(firebaseService.authStateChanges),

    routes: [
      // ... routes sama seperti sebelumnya
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Halaman tidak ditemukan: ${state.uri}')),
    ),
  );
});
```

## Kenapa Redirect Logic-nya Ada di `router.dart`, Bukan di UI Widget?

Ini penting biar konsisten sama arsitektur kita — proteksi akses dilakukan **di level navigasi**, bukan tiap screen cek manual "apakah saya boleh diakses". Keuntungannya:
- User gak bisa akses route admin cuma dengan ngetik URL manual di browser (khusus versi web).
- Satu tempat aja yang perlu diaudit soal keamanan navigasi.

## Yang Perlu Kamu Ingat ke Depan

1. **Set role admin manual dulu** — begitu kamu bikin akun sendiri, buka Firestore Console, cari dokumen `users/{uid_kamu}`, tambahkan field `role: "admin"` manual. Gak ada UI untuk "generate admin" dari app (memang harus begitu, biar gak bisa disalahgunakan).
2. **Field `role` di `users` collection** perlu didaftarkan resmi di skema data kamu — nanti waktu bikin `UserModel`, pastikan field ini ada dari awal.
3. Firestore Rules yang kita buat kemarin sudah punya helper `isAdmin()` yang cek field `role` ini juga — jadi proteksi di level **database** dan **routing** sudah saling melengkapi (defense in depth).

Mau lanjut ke pembuatan fitur `features/auth/` sekarang (termasuk `UserModel` dengan field `role`), atau ada yang mau didiskusikan dulu soal strategi role ini?
