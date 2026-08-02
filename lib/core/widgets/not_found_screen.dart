// lib/core/widgets/not_found_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

class NotFoundScreen extends ConsumerWidget {
  final String? attemptedPath;

  const NotFoundScreen({super.key, this.attemptedPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Page Not Found !',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (attemptedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                attemptedPath!,
                style: const TextStyle(
                  color: Colors.grey,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final role = roleAsync.value;
                context.go(role == UserRole.admin ? '/admin' : 'learning');
              },
              child: const Text('Homepage'),
            ),
          ],
        ),
      ),
    );
  }
}
