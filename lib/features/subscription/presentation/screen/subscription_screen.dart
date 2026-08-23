import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/subscription/data/models/subscription_plan.dart';
import 'package:tutur_id_app/features/subscription/logic/subscription_provider.dart';
import 'package:tutur_id_app/features/subscription/presentation/screen/payment_webview_screen.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final subscriptionState = ref.watch(subscriptionNotifierProvider);

    ref.listen(subscriptionNotifierProvider, (previous, next) {
      if (next.snapToken != null && previous?.snapToken != next.snapToken) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              snapToken: next.snapToken!,
              onPaymentSuccess: () {
                ref
                    .read(subscriptionNotifierProvider.notifier)
                    .confirmPayment();
              },
            ),
          ),
        );
      }

      if (next.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: ${next.errorMessage}')));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade Langganan')),
      body: profileAsync.when(
        data: (profile) {
          final currentTier = profile?.subscriptionTier ?? UserTier.starter;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: SubscriptionPlan.all.length,
            itemBuilder: (context, index) {
              final plan = SubscriptionPlan.all[index];
              final isCurrentPlan = plan.tier == currentTier;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: isCurrentPlan ? Colors.blue[50] : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            plan.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (isCurrentPlan)
                            const Chip(
                              label: Text('Aktif'),
                              backgroundColor: Colors.blue,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.price == 0 ? 'Gratis' : 'Rp${plan.price}/bulan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...plan.features.map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(f),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isCurrentPlan && plan.price > 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: subscriptionState.isProcessing
                                ? null
                                : () => ref
                                      .read(
                                        subscriptionNotifierProvider.notifier,
                                      )
                                      .upgradeTier(plan.tier, plan.price),
                            child: subscriptionState.isProcessing
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Upgrade'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
