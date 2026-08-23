import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/subscription/data/models/transaction_model.dart';
import 'package:tutur_id_app/features/subscription/data/repositories/subscription_repository.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';

const _tag = 'SUBSCRIPTION';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    ref.watch(firebaseServiceProvider),
    ref.watch(midtransServiceProvider),
  );
});

final userTransactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref
      .watch(subscriptionRepositoryProvider)
      .getUserTransactions(profile.uid);
});

class SubscriptionState {
  final bool isProcessing;
  final String? snapToken;
  final String? pendingOrderId;
  final UserTier? pendingTier;
  final String? errorMessage;

  SubscriptionState({
    this.isProcessing = false,
    this.snapToken,
    this.pendingOrderId,
    this.pendingTier,
    this.errorMessage,
  });

  SubscriptionState copyWith({
    bool? isProcessing,
    String? snapToken,
    String? pendingOrderId,
    UserTier? pendingTier,
    String? errorMessage,
  }) {
    return SubscriptionState(
      isProcessing: isProcessing ?? this.isProcessing,
      snapToken: snapToken,
      pendingOrderId: pendingOrderId ?? this.pendingOrderId,
      pendingTier: pendingTier ?? this.pendingTier,
      errorMessage: errorMessage,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => SubscriptionState();

  Future<void> upgradeTier(UserTier targetTier, int amount) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final result = await ref
          .read(subscriptionRepositoryProvider)
          .initiateUpgradeWithOrderId(
            userId: profile.uid,
            userEmail: profile.email,
            userName: profile.username ?? 'User',
            targetTier: targetTier,
            amount: amount,
          );

      state = state.copyWith(
        isProcessing: false,
        snapToken: result.snapToken,
        pendingOrderId: result.orderId,
        pendingTier: targetTier,
      );
    } catch (error, stackTrace) {
      AppLogger.e(
        'Gagal memulai upgrade',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      state = state.copyWith(
        isProcessing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> confirmPayment() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null ||
        state.pendingTier == null ||
        state.pendingOrderId == null) {
      AppLogger.w(
        'confirmPayment dipanggil tanpa pendingOrderId/pendingTier',
        tag: _tag,
      );
      return;
    }

    state = state.copyWith(isProcessing: true);

    try {
      await ref
          .read(subscriptionRepositoryProvider)
          .confirmTransactionOptimistic(
            orderId: state.pendingOrderId!,
            userId: profile.uid,
            tier: state.pendingTier!,
          );

      ref.invalidate(userProfileProvider);
      ref.invalidate(userTransactionsProvider);

      state = SubscriptionState(); // reset ke idle
    } catch (error, stackTrace) {
      AppLogger.e(
        'Gagal konfirmasi pembayaran',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      state = state.copyWith(
        isProcessing: false,
        errorMessage: error.toString(),
      );
    }
  }

  void reset() {
    state = SubscriptionState();
  }
}

final subscriptionNotifierProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
      SubscriptionNotifier.new,
    );
