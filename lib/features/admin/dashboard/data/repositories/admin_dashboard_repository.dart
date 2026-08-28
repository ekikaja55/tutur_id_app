import 'package:tutur_id_app/core/services/firebase_service.dart';

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
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: startOfMonth.toIso8601String(),
          ),
    );

    return DashboardSummary(
      totalUsers: users.length,
      pendingReports: reports.length,
      totalModules: modules.length,
      monthlyTransactionCount: transactions.length,
    );
  }
}
