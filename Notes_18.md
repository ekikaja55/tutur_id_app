Oke, lanjut ke **`admin/user_management/`** — List & filter user, lihat status subscription, dan aksi administratif (suspend).

## 1. Perlu Tambahan Field: `isSuspended` di `UserModel`

Requirement bilang admin bisa "melakukan tindakan administratif jika ditemukan penyalahgunaan akun" — ini butuh status aktif/suspend yang **belum ada** di `UserModel` kita. Tambahkan field baru.

### Update `features/auth/data/models/user_model.dart`

```dart
// Tambahkan field baru
class UserModel {
  // ... field yang sudah ada
  final bool isSuspended;

  UserModel({
    // ... parameter yang sudah ada
    this.isSuspended = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      // ... field yang sudah ada
      isSuspended: json['isSuspended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // ... field yang sudah ada
      'isSuspended': isSuspended,
    };
  }

  UserModel copyWith({
    // ... parameter yang sudah ada
    bool? isSuspended,
  }) {
    return UserModel(
      // ... field yang sudah ada
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}
```

## 2. Update Router Redirect — Blokir User yang Di-suspend

Ini penting — begitu ada field `isSuspended`, logic redirect di `router.dart` perlu tau soal ini, supaya user yang di-suspend gak bisa akses app sama sekali.

```dart
// app/router.dart, di dalam redirect logic, tambahkan setelah cek role

if (userData['isSuspended'] == true && !isLoggingIn) {
  return '/suspended';
}
```

Tambah screen sederhana:
```dart
// lib/core/widgets/suspended_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/logic/auth_provider.dart';

class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Akun Kamu Ditangguhkan'),
            const SizedBox(height: 8),
            const Text('Hubungi admin melalui fitur Report jika ini kesalahan.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
              child: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

Daftarkan route `/suspended` di `router.dart` (masuk `_sharedPrefixes` biar admin gak ke-block juga kalau iseng suspend diri sendiri, tapi karena ini kondisional dari `isSuspended`, biasanya gak akan konflik).

## 3. Repository

```dart
// lib/features/admin/user_management/data/repositories/user_management_repository.dart
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../auth/data/models/user_model.dart';

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
```

## 4. Provider

```dart
// lib/features/admin/user_management/logic/user_management_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/providers.dart';
import '../../../auth/data/models/user_model.dart';
import '../data/repositories/user_management_repository.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) {
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
      await ref.read(userManagementRepositoryProvider).setSuspendStatus(userId, !currentStatus);
    });
    ref.invalidate(allUsersProvider);
  }
}

final userManagementNotifierProvider =
    AsyncNotifierProvider<UserManagementNotifier, void>(UserManagementNotifier.new);
```

## 5. Screen: User List dengan Filter

```dart
// lib/features/admin/user_management/presentation/screens/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/enums/user_tier.dart';
import '../../../auth/data/models/user_model.dart';
import '../../logic/user_management_provider.dart';

enum _StatusFilter { all, active, suspended }

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  UserTier? _tierFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  List<UserModel> _applyFilters(List<UserModel> users) {
    return users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          (user.username?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesTier = _tierFilter == null || user.subscriptionTier == _tierFilter;

      final matchesStatus = switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.active => !user.isSuspended,
        _StatusFilter.suspended => user.isSuspended,
      };

      return matchesSearch && matchesTier && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Pengguna')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama atau email...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<UserTier?>(
                    value: _tierFilter,
                    decoration: const InputDecoration(
                      labelText: 'Tier',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Tier')),
                      ...UserTier.values.map(
                        (tier) => DropdownMenuItem(value: tier, child: Text(tier.name.toUpperCase())),
                      ),
                    ],
                    onChanged: (value) => setState(() => _tierFilter = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<_StatusFilter>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: _StatusFilter.all, child: Text('Semua Status')),
                      DropdownMenuItem(value: _StatusFilter.active, child: Text('Aktif')),
                      DropdownMenuItem(value: _StatusFilter.suspended, child: Text('Disuspend')),
                    ],
                    onChanged: (value) => setState(() => _statusFilter = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  final filtered = _applyFilters(users);
                  if (filtered.isEmpty) {
                    return const Center(child: Text('Tidak ada pengguna yang cocok'));
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _UserTile(user: filtered[index]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  final UserModel user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
        child: user.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.username ?? user.email),
      subtitle: Text('${user.email} • ${user.subscriptionTier.name.toUpperCase()}'),
      trailing: Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text(user.isSuspended ? 'Disuspend' : 'Aktif'),
            backgroundColor: user.isSuspended ? Colors.red[100] : Colors.green[100],
          ),
          IconButton(
            icon: Icon(user.isSuspended ? Icons.lock_open : Icons.block),
            tooltip: user.isSuspended ? 'Aktifkan Kembali' : 'Suspend',
            onPressed: () => _confirmToggleSuspend(context, ref),
          ),
        ],
      ),
    );
  }

  void _confirmToggleSuspend(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.isSuspended ? 'Aktifkan Kembali?' : 'Suspend Pengguna?'),
        content: Text(
          user.isSuspended
              ? '${user.username ?? user.email} akan bisa mengakses aplikasi kembali.'
              : '${user.username ?? user.email} tidak akan bisa mengakses aplikasi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(userManagementNotifierProvider.notifier)
                  .toggleSuspend(user.uid, user.isSuspended);
            },
            child: Text(
              user.isSuspended ? 'Aktifkan' : 'Suspend',
              style: TextStyle(color: user.isSuspended ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 6. Update `router.dart`

```dart
// Ganti PlaceholderScreen untuk /admin/users
GoRoute(
  path: '/admin/users',
  builder: (context, state) => const UserManagementScreen(),
),
```

## Update Firestore Rules

Rules yang udah ada di `users/{userId}` sebenarnya **sudah cukup** — `allow update: if isOwner(userId) || isAdmin()`, jadi admin memang boleh update field apapun termasuk `isSuspended`. Gak perlu perubahan.

## Update `TODO.txt`

```
[ADMIN: MANAJEMEN PENGGUNA]
[x] List & filter pengguna aktif (search, filter by tier, filter by status)
[x] Lihat status subscription per user
[x] Aksi administratif (suspend/aktifkan kembali akun)
[x] Blokir akses app untuk user yang di-suspend (router redirect)

[POLISH & DESIGN]
[ ] Pagination untuk list user - saat ini fetch semua sekaligus, perlu dibatasi kalau user makin banyak
```

## Catatan: Belum Ada Pagination

Sama seperti dashboard, `getAllUsers()` fetch **semua** user sekaligus — untuk skala skripsi/demo (puluhan/ratusan user) ini gak masalah, tapi kalau nanti scale-nya besar, perlu ditambah pagination pakai `Query.limit()` + `startAfterDocument()`. Aku catat sebagai polish item, gak jadi blocker sekarang.

Lanjut ke `admin/content_management/`?
