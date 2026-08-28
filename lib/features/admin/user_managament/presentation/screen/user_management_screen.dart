import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/admin/user_managament/logic/user_management_provider.dart';
import 'package:tutur_id_app/features/auth/data/models/user_model.dart';
import 'package:tutur_id_app/shared/enums/user_status.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';


class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _searchQuery = '';
  UserTier? _tierFilter;
  UserStatus _statusFilter = UserStatus.all;

  List<UserModel> _applyFilters(List<UserModel> users) {
    return users.where((user) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          (user.username?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesTier =
          _tierFilter == null || user.subscriptionTier == _tierFilter;

      final matchesStatus = switch (_statusFilter) {
        UserStatus.all => true,
        UserStatus.active => !user.isSuspended,
        UserStatus.suspended => user.isSuspended,
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua Tier'),
                      ),
                      ...UserTier.values.map(
                        (tier) => DropdownMenuItem(
                          value: tier,
                          child: Text(tier.name.toUpperCase()),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _tierFilter = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<UserStatus>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserStatus.all,
                        child: Text('Semua Status'),
                      ),
                      DropdownMenuItem(
                        value: UserStatus.active,
                        child: Text('Aktif'),
                      ),
                      DropdownMenuItem(
                        value: UserStatus.suspended,
                        child: Text('Disuspend'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _statusFilter = value!),
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
                    return const Center(
                      child: Text('Tidak ada pengguna yang cocok'),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _UserTile(user: filtered[index]),
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
        backgroundImage: user.photoUrl != null
            ? NetworkImage(user.photoUrl!)
            : null,
        child: user.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.username ?? user.email),
      subtitle: Text(
        '${user.email} • ${user.subscriptionTier.name.toUpperCase()}',
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text(user.isSuspended ? 'Disuspend' : 'Aktif'),
            backgroundColor: user.isSuspended
                ? Colors.red[100]
                : Colors.green[100],
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
        title: Text(
          user.isSuspended ? 'Aktifkan Kembali?' : 'Suspend Pengguna?',
        ),
        content: Text(
          user.isSuspended
              ? '${user.username ?? user.email} akan bisa mengakses aplikasi kembali.'
              : '${user.username ?? user.email} tidak akan bisa mengakses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(userManagementNotifierProvider.notifier)
                  .toggleSuspend(user.uid, user.isSuspended);
            },
            child: Text(
              user.isSuspended ? 'Aktifkan' : 'Suspend',
              style: TextStyle(
                color: user.isSuspended ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
