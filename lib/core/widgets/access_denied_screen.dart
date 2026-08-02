import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

class AccessDeniedScreen extends ConsumerWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              "Access Denied !",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              "Onfortunately you cannot access this page :)",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final role = roleAsync.value;
                context.go(role == UserRole.admin ? '/admin' : '/learning');
              },
              child: const Text("Homepage"),
            ),
          ],
        ),
      ),
    );
  }
}
