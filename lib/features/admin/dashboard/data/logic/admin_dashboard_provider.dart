import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/admin/dashboard/data/repositories/admin_dashboard_repository.dart';

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((
  ref,
) {
  return AdminDashboardRepository(ref.watch(firebaseServiceProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  return ref.watch(adminDashboardRepositoryProvider).getSummary();
});
