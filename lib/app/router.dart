import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/go_router_refresh_stream.dart';
import 'package:tutur_id_app/core/widgets/access_denied_screen.dart';
import 'package:tutur_id_app/core/widgets/admin_shell.dart';
import 'package:tutur_id_app/core/widgets/not_found_screen.dart';
import 'package:tutur_id_app/core/widgets/placeholder_screen.dart';
import 'package:tutur_id_app/features/admin/dashboard/presentation/screen/admin_dashboard_screen.dart';
import 'package:tutur_id_app/features/ai_training/presentation/screen/ai_training_screen.dart';
import 'package:tutur_id_app/features/auth/presentation/screen/login_screen.dart';
import 'package:tutur_id_app/features/auth/presentation/screen/onboarding_screen.dart';
import 'package:tutur_id_app/features/feedback_report/presentation/screen/feedback_report_hub_screen.dart';
import 'package:tutur_id_app/features/gamification/presentation/screen/leaderboard_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/learning_home_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/module_detail_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/quiz_screen.dart';
import 'package:tutur_id_app/features/notification/presentation/screen/notification_screen.dart';
import 'package:tutur_id_app/features/profile/presentation/screen/profile_screen.dart';
import 'package:tutur_id_app/features/subscription/presentation/screen/subscription_screen.dart';
import 'package:tutur_id_app/shared/enums/user_role.dart';

const _adminPrefixes = ['/admin'];
const _studentPrefixes = [
  '/learning',
  '/ai-training',
  '/subscription',
  '/leaderboard',
  '/feedback-report',
];

// ini aku comment karena yah gausa toh juga yang gamasuk prefix admin / student route pasti shared kan
// const _sharedPrefixes = ['/profile', '/notification'];

bool _matchesAnyPrefix(String location, List<String> prefixes) {
  return prefixes.any((prefix) => location.startsWith(prefix));
}

final routerProvider = Provider<GoRouter>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return GoRouter(
    initialLocation: "/login",
    debugLogDiagnostics: true,

    redirect: (context, state) async {
      final isLoggedIn = firebaseService.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final location = state.matchedLocation;

      if (!isLoggedIn && !isLoggingIn) return '/login';

      if (isLoggedIn) {
        final userData = await firebaseService.getDocument(
          'users',
          firebaseService.currentUser!.uid,
        );
        if (userData == null) {
          return isOnboarding ? null : '/onboarding';
        }

        final role = UserRole.fromMap(userData['role'] as String?);
        if (isLoggingIn || isOnboarding) {
          return role == UserRole.admin ? '/admin' : '/learning';
        }
        if (role != UserRole.admin &&
            _matchesAnyPrefix(location, _adminPrefixes)) {
          return '/access-denied';
        }
        if (role == UserRole.admin &&
            _matchesAnyPrefix(location, _studentPrefixes)) {
          return '/access-denied';
        }
      }
      return null;
    },
    refreshListenable: GoRouterRefreshStream(firebaseService.authStateChanges),
    routes: [
      // =============== ROUTES ACCESS DENIED ===============
      GoRoute(
        path: "/access-denied",
        builder: (context, state) => const AccessDeniedScreen(),
      ),

      // =============== ROUTES LIST BUAT PELAJAR ===============
      GoRoute(path: "/login", builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: "/onboarding",
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/learning',
        builder: (context, state) => const LearningHomeScreen(),
        routes: [
          GoRoute(
            path: 'module/:moduleId',
            builder: (context, state) {
              final moduleId = state.pathParameters['moduleId']!;
              return ModuleDetailScreen(moduleId: moduleId);
            },
            routes: [
              GoRoute(
                path: 'quiz',
                builder: (context, state) {
                  final moduleId = state.pathParameters['moduleId']!;
                  return QuizScreen(moduleId: moduleId);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: "/ai-training/:moduleId",
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return AiTrainingScreen(
            moduleId: moduleId,
            materials: extra?['materials'] ?? [],
          );
        },
      ),
      GoRoute(
        path: "/subscription",
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: "/profile",
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/feedback-report',
        builder: (context, state) => const FeedbackReportHubScreen(),
      ),
      GoRoute(
        path: "/notification",
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),

      // =============== ROUTES LIST SHELL BUAT ADMIN ===============
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
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Manajemen Pengguna'),
          ),
          GoRoute(
            path: '/admin/content',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Materi Pembelajaran'),
          ),
          GoRoute(
            path: '/admin/broadcast',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Broadcast Notifikasi'),
          ),
          GoRoute(
            path: '/admin/transactions',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Laporan Transaksi'),
          ),
          GoRoute(
            path: '/admin/feedback',
            builder: (context, state) =>
                const PlaceholderScreen(title: 'Report & Feedback'),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(attemptedPath: state.uri.toString()),
  );
});
