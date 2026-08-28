import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/admin/dashboard/data/logic/admin_dashboard_provider.dart';

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
              Text(
                'Ringkasan',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
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
              Text(
                'Akses Cepat',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
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

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
