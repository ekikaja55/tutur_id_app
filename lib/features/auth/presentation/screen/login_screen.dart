import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to login : $error')));
        },
      );
    });
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 96),
              const SizedBox(height: 24),
              Text(
                'Tutur.id',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                "Belajar BISINDO secara interaktif",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              authState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle();
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
