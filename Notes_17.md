Oke, lanjut ke **`features/admin/dashboard/`**. Karena admin ini target platformnya web (browser), sebelum masuk ke screen dashboard itu sendiri, aku tambahkan dulu **shell/layout dengan side navigation** — supaya admin gak perlu bolak-balik "back" tiap pindah sub-fitur, sesuai kebiasaan UX aplikasi admin panel pada umumnya.

## 1. `core/widgets/admin_shell.dart` — Layout dengan Side Navigation

```dart
// lib/core/widgets/admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/logic/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const AdminShell({super.key, required this.child, required this.currentPath});

  static const _menuItems = [
    _AdminMenuItem(path: '/admin', icon: Icons.dashboard, label: 'Dashboard'),
    _AdminMenuItem(path: '/admin/users', icon: Icons.people, label: 'Manajemen Pengguna'),
    _AdminMenuItem(path: '/admin/content', icon: Icons.book, label: 'Materi Pembelajaran'),
    _AdminMenuItem(path: '/admin/broadcast', icon: Icons.campaign, label: 'Broadcast'),
    _AdminMenuItem(path: '/admin/transactions', icon: Icons.receipt_long, label: 'Transaksi'),
    _AdminMenuItem(path: '/admin/feedback', icon: Icons.feedback, label: 'Report & Feedback'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _menuItems.indexWhere((item) => item.path == currentPath);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 900,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) => context.go(_menuItems[index].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings, size: 32),
                  const SizedBox(height: 4),
                  Text('Tutur.id Admin', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Keluar',
                    onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
                  ),
                ),
              ),
            ),
            destinations: _menuItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminMenuItem {
  final String path;
  final IconData icon;
  final String label;
  const _AdminMenuItem({required this.path, required this.icon, required this.label});
}
```

## 2. Repository: Aggregasi Data untuk Dashboard

```dart
// lib/features/admin/dashboard/data/repositories/admin_dashboard_repository.dart
import '../../../../core/services/firebase_service.dart';

class DashboardSummary {
  final int totalUsers;
  final int pendingReports;
  final int totalModules;
  final int monthlyTransactionCount;

  DashboardSummary({
    required this.totalUsers,
    required this.pendingReports,
    required this.totalModules,
    required this.monthlyTransactionCount,
  });
}

class AdminDashboardRepository {
  final FirebaseService _firebaseService;

  AdminDashboardRepository(this._firebaseService);

  Future<DashboardSummary> getSummary() async {
    final users = await _firebaseService.getCollection('users');
    final reports = await _firebaseService.getCollection(
      'reports',
      queryBuilder: (query) => query.where('status', isEqualTo: 'diterima'),
    );
    final modules = await _firebaseService.getCollection('modules');

    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final transactions = await _firebaseService.getCollection(
      'transactions',
      queryBuilder: (query) => query
          .where('status', isEqualTo: 'success')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth.toIso8601String()),
    );

    return DashboardSummary(
      totalUsers: users.length,
      pendingReports: reports.length,
      totalModules: modules.length,
      monthlyTransactionCount: transactions.length,
    );
  }
}
```

> **Catatan performa**: `getCollection('users')` di atas fetch **semua** dokumen cuma buat dapat `.length` — ini boros read quota kalau user udah banyak (tiap dokumen dihitung sebagai 1 read). Untuk skala skripsi/demo ini gak masalah, tapi kalau nanti mau lebih efisien, Firestore punya [`count()` aggregation query](https://firebase.google.com/docs/firestore/query-data/aggregation-queries) yang cuma kena 1 read biarpun collection-nya besar. Aku catat ini di `TODO.txt` sebagai optimisasi lanjutan.

## 3. Provider

```dart
// lib/features/admin/dashboard/logic/admin_dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/providers.dart';
import '../data/repositories/admin_dashboard_repository.dart';

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((ref) {
  return AdminDashboardRepository(ref.watch(firebaseServiceProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  return ref.watch(adminDashboardRepositoryProvider).getSummary();
});
```

## 4. Screen: Dashboard

```dart
// lib/features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/admin_dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Admin')),
      body: summaryAsync.when(
        data: (summary) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ringkasan', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _SummaryCard(
                    icon: Icons.people,
                    label: 'Total Pengguna',
                    value: '${summary.totalUsers}',
                    color: Colors.blue,
                  ),
                  _SummaryCard(
                    icon: Icons.report_problem,
                    label: 'Report Belum Ditangani',
                    value: '${summary.pendingReports}',
                    color: Colors.orange,
                    onTap: () => context.go('/admin/feedback'),
                  ),
                  _SummaryCard(
                    icon: Icons.book,
                    label: 'Total Modul',
                    value: '${summary.totalModules}',
                    color: Colors.green,
                    onTap: () => context.go('/admin/content'),
                  ),
                  _SummaryCard(
                    icon: Icons.receipt_long,
                    label: 'Transaksi Bulan Ini',
                    value: '${summary.monthlyTransactionCount}',
                    color: Colors.purple,
                    onTap: () => context.go('/admin/transactions'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Akses Cepat', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickAction(
                    icon: Icons.people,
                    label: 'Kelola Pengguna',
                    onTap: () => context.go('/admin/users'),
                  ),
                  _QuickAction(
                    icon: Icons.book,
                    label: 'Kelola Materi',
                    onTap: () => context.go('/admin/content'),
                  ),
                  _QuickAction(
                    icon: Icons.campaign,
                    label: 'Kirim Broadcast',
                    onTap: () => context.go('/admin/broadcast'),
                  ),
                  _QuickAction(
                    icon: Icons.feedback,
                    label: 'Tinjau Report',
                    onTap: () => context.go('/admin/feedback'),
                  ),
                ],
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 12),
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
```

## 5. Update `router.dart` — Bungkus Semua Route Admin dengan `AdminShell`

Ini bagian penting — supaya `NavigationRail` **tetap muncul** di semua sub-halaman admin (bukan cuma di dashboard), kita perlu ubah pattern routing admin jadi pakai `ShellRoute` dari `go_router`.

```dart
// lib/app/router.dart
import 'package:go_router/go_router.dart';
import '../core/widgets/admin_shell.dart';
import '../features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
// import screen admin lain nanti setelah dibuat

// ... di dalam routes: []

ShellRoute(
  builder: (context, state, child) {
    return AdminShell(currentPath: state.matchedLocation, child: child);
  },
  routes: [
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Manajemen Pengguna',
        icon: Icons.people,
      ),
    ),
    GoRoute(
      path: '/admin/content',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Materi Pembelajaran',
        icon: Icons.book,
      ),
    ),
    GoRoute(
      path: '/admin/broadcast',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Broadcast Notifikasi',
        icon: Icons.campaign,
      ),
    ),
    GoRoute(
      path: '/admin/transactions',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Laporan Transaksi',
        icon: Icons.receipt_long,
      ),
    ),
    GoRoute(
      path: '/admin/feedback',
      builder: (context, state) => const PlaceholderScreen(
        title: 'Report & Feedback',
        icon: Icons.feedback,
      ),
    ),
  ],
),
```

> **Ganti route admin lama** yang sebelumnya nested biasa (`GoRoute` dengan sub `routes:`) dengan `ShellRoute` ini — hapus definisi lama supaya gak dobel.

## Kenapa `ShellRoute`, Bukan Nested Route Biasa?

Beda mendasar: kalau pakai nested `GoRoute` biasa, tiap kali pindah halaman, **seluruh widget tree di-rebuild dari awal** — termasuk `NavigationRail`-nya, jadi keliatan "flicker" tiap navigasi. `ShellRoute` menjaga `AdminShell` (termasuk `NavigationRail`) **tetap hidup**, cuma bagian `child`-nya yang berganti. Ini pola standar untuk aplikasi dengan persistent navigation (sidebar/bottom nav).

## Update `TODO.txt`

```
[ADMIN: DASHBOARD]
[x] Layout admin dengan NavigationRail (AdminShell)
[x] Summary cards (total user, pending report, modul, transaksi bulan ini)
[x] Quick access ke semua sub-fitur admin
[x] ShellRoute setup untuk persistent navigation

[POLISH & DESIGN]
[ ] Ganti getCollection().length dengan Firestore count() aggregation query untuk efisiensi read quota
```

Dashboard-nya sekarang jadi **hub utama** — begitu sub-fitur admin lain selesai dibuat, tinggal ganti `PlaceholderScreen` di `router.dart` satu-satu, gak perlu ubah struktur shell-nya lagi.

Lanjut ke `admin/user_management/`?
