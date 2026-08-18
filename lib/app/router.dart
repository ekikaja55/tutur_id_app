import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/go_router_refresh_stream.dart';
import 'package:tutur_id_app/core/widgets/access_denied_screen.dart';
import 'package:tutur_id_app/core/widgets/not_found_screen.dart';
import 'package:tutur_id_app/core/widgets/placeholder_screen.dart';
import 'package:tutur_id_app/features/auth/presentation/screen/login_screen.dart';
import 'package:tutur_id_app/features/auth/presentation/screen/onboarding_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/learning_home_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/module_detail_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/quiz_screen.dart';
import 'package:tutur_id_app/shared/enums/user_role.dart';

const _adminPrefixes = ['/admin'];
const _studentPrefixes = [
  '/learning',
  '/ai-training',
  '/subscription',
  '/leaderboard',
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
          final moduleId = state.pathParameters['moduleId'];
          return PlaceholderScreen(
            title: "AI Camera Page",
            subTitle: "Id Module : $moduleId",
          );
        },
      ),
      GoRoute(
        path: "/subscription",
        builder: (context, state) =>
            const PlaceholderScreen(title: "Subcription Page"),
      ),
      GoRoute(
        path: "/profile",
        builder: (context, state) =>
            const PlaceholderScreen(title: "Profile Page"),
      ),
      GoRoute(
        path: "/notification",
        builder: (context, state) =>
            const PlaceholderScreen(title: "Notification Page"),
      ),
      GoRoute(
        path: "/leaderboard",
        builder: (context, state) =>
            const PlaceholderScreen(title: "Leaderboard Page"),
      ),

      // =============== ROUTES LIST BUAT ADMIN ===============
      GoRoute(
        path: "/admin/",
        builder: (context, state) =>
            const PlaceholderScreen(title: "Admin - Dashboard Page"),
        routes: [
          GoRoute(
            path: "users",
            builder: (context, state) =>
                const PlaceholderScreen(title: "Admin - Users Management Page"),
          ),
          GoRoute(
            path: "content",
            builder: (context, state) => const PlaceholderScreen(
              title: "Admin - Contents Management Page",
            ),
          ),
          GoRoute(
            path: "broadcast",
            builder: (context, state) => const PlaceholderScreen(
              title: "Admin - Broadcast Management Page",
            ),
          ),
          GoRoute(
            path: "transactions",
            builder: (context, state) => const PlaceholderScreen(
              title: "Admin - Transactions Management Page",
            ),
          ),
          GoRoute(
            path: "feedback",
            builder: (context, state) => const PlaceholderScreen(
              title: "Admin - Feedback Management Page",
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        NotFoundScreen(attemptedPath: state.uri.toString()),
  );
});
