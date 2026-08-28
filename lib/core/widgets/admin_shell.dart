import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

class AdminShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const AdminShell({super.key, required this.child, required this.currentPath});

  static const _menuItems = [
    _AdminMenuItem(path: '/admin', icon: Icons.dashboard, label: 'Dashboard'),
    _AdminMenuItem(
      path: '/admin/users',
      icon: Icons.people,
      label: 'Manajemen Pengguna',
    ),
    _AdminMenuItem(
      path: '/admin/content',
      icon: Icons.book,
      label: 'Materi Pembelajaran',
    ),
    _AdminMenuItem(
      path: '/admin/broadcast',
      icon: Icons.campaign,
      label: 'Broadcast',
    ),
    _AdminMenuItem(
      path: '/admin/transactions',
      icon: Icons.receipt_long,
      label: 'Transaksi',
    ),
    _AdminMenuItem(
      path: '/admin/feedback',
      icon: Icons.feedback,
      label: 'Report & Feedback',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _menuItems.indexWhere(
      (item) => item.path == currentPath,
    );

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width > 900,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) =>
                context.go(_menuItems[index].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Tutur.id Admin',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
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
                    onPressed: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  ),
                ),
              ),
            ),
            destinations: _menuItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
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
  const _AdminMenuItem({
    required this.path,
    required this.icon,
    required this.label,
  });
}
