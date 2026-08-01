import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/go_router_refresh_stream.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return GoRouter(
    initialLocation: "/login",
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = firebaseService.currentUser != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/learning';
      return null;
    },
    refreshListenable: GoRouterRefreshStream(firebaseService.authStateChanges),
    routes: [
      GoRoute(path: "", builder: (context, state) => const Text(""))],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found : ${state.uri}'))),
  );
});
