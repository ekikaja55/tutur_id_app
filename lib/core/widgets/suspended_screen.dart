import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Your account has been suspended !'),
            const SizedBox(height: 8),
            const Text(
              'Contact admin for further for more detail information.',
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
              child: const Text('Exit'),
            ),
          ],
        ),
      ),
    );
  }
}
