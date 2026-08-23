Kamu benar, aku sebut fungsi itu tapi belum aku buatkan — dan soal pertanyaan terakhir, aku putuskan aja langsung daripada nanya balik, karena ini murni penyesuaian struktural mengikuti pola yang udah konsisten kita pakai (misal `AiTrainingState` yang punya banyak field buat nampung hasil async).

## Fix: `SubscriptionRepository`

Ganti `initiateUpgrade()` supaya return objek yang isinya `orderId` + `snapToken` sekaligus, bukan cuma `String` token doang.

```dart
// lib/features/subscription/data/repositories/subscription_repository.dart
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/midtrans_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../shared/enums/user_tier.dart';
import '../models/transaction_model.dart';

const _tag = 'SUBSCRIPTION_REPO';

// Wrapper kecil buat bungkus 2 nilai balik sekaligus
class UpgradeInitiationResult {
  final String orderId;
  final String snapToken;

  UpgradeInitiationResult({required this.orderId, required this.snapToken});
}

class SubscriptionRepository {
  final FirebaseService _firebaseService;
  final MidtransService _midtransService;

  SubscriptionRepository(this._firebaseService, this._midtransService);

  Future<UpgradeInitiationResult> initiateUpgradeWithOrderId({
    required String userId,
    required String userEmail,
    required String userName,
    required UserTier targetTier,
    required int amount,
  }) async {
    final orderId = 'TUTUR-${userId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.i('Memulai transaksi: $orderId untuk tier ${targetTier.name}', tag: _tag);

    final snapToken = await _midtransService.createTransactionToken(
      orderId: orderId,
      grossAmount: amount,
      customerName: userName,
      customerEmail: userEmail,
    );

    final transaction = TransactionModel(
      id: orderId,
      userId: userId,
      orderId: orderId,
      tier: targetTier,
      grossAmount: amount,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firebaseService.setDocument('transactions', orderId, transaction.toJson());
    AppLogger.s('Transaksi dicatat dengan status pending', tag: _tag);

    return UpgradeInitiationResult(orderId: orderId, snapToken: snapToken);
  }

  Future<void> confirmTransactionOptimistic({
    required String orderId,
    required String userId,
    required UserTier tier,
  }) async {
    AppLogger.i('Update optimis transaksi $orderId sebagai success', tag: _tag);

    await _firebaseService.updateDocument('transactions', orderId, {
      'status': TransactionStatus.success.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await _firebaseService.updateDocument('users', userId, {
      'subscriptionTier': tier.toMap(),
      'subscriptionExpiresAt':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    });

    await _firebaseService.setDocument('subscriptions', userId, {
      'tier': tier.toMap(),
      'startDate': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'status': 'active',
      'lastTransactionId': orderId,
    });

    AppLogger.s('Tier user berhasil diupdate ke ${tier.name}', tag: _tag);
  }

  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    final data = await _firebaseService.getCollection(
      'transactions',
      queryBuilder: (query) =>
          query.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true),
    );
    return data.map((e) => TransactionModel.fromJson(e)).toList();
  }
}
```

> `initiateUpgrade()` yang lama **dihapus**, diganti total sama `initiateUpgradeWithOrderId()` — bukan ditambah sebagai method kedua, biar gak ada 2 cara berbeda buat hal yang sama.

## Fix: `SubscriptionNotifier`

```dart
// lib/features/subscription/logic/subscription_provider.dart
// (bagian yang berubah, sisanya tetap sama)

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => SubscriptionState();

  Future<void> upgradeTier(UserTier targetTier, int amount) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = state.copyWith(isProcessing: true, errorMessage: null);

    try {
      final result = await ref.read(subscriptionRepositoryProvider).initiateUpgradeWithOrderId(
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
      AppLogger.e('Gagal memulai upgrade', error: error, stackTrace: stackTrace, tag: _tag);
      state = state.copyWith(isProcessing: false, errorMessage: error.toString());
    }
  }

  Future<void> confirmPayment() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null || state.pendingTier == null || state.pendingOrderId == null) {
      AppLogger.w('confirmPayment dipanggil tanpa pendingOrderId/pendingTier', tag: _tag);
      return;
    }

    state = state.copyWith(isProcessing: true);

    try {
      await ref.read(subscriptionRepositoryProvider).confirmTransactionOptimistic(
            orderId: state.pendingOrderId!,
            userId: profile.uid,
            tier: state.pendingTier!,
          );

      ref.invalidate(userProfileProvider);
      ref.invalidate(userTransactionsProvider);

      state = SubscriptionState(); // reset ke idle
    } catch (error, stackTrace) {
      AppLogger.e('Gagal konfirmasi pembayaran', error: error, stackTrace: stackTrace, tag: _tag);
      state = state.copyWith(isProcessing: false, errorMessage: error.toString());
    }
  }

  void reset() {
    state = SubscriptionState();
  }
}
```

**Perubahan kunci**: `confirmPayment()` sekarang **gak butuh parameter** `orderId` lagi dari luar — dia ambil langsung dari `state.pendingOrderId` yang udah tersimpan sejak `upgradeTier()` dipanggil. Ini lebih aman karena gak ada celah "orderId yang mana yang dipakai" seperti gap sebelumnya.

## Fix: `subscription_screen.dart`

```dart
// lib/features/subscription/presentation/screens/subscription_screen.dart
// (bagian ref.listen yang berubah)

ref.listen(subscriptionNotifierProvider, (previous, next) {
  if (next.snapToken != null && previous?.snapToken != next.snapToken) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          snapToken: next.snapToken!,
          onPaymentSuccess: () {
            // Sekarang cukup panggil tanpa parameter,
            // orderId sudah tersimpan di state notifier
            ref.read(subscriptionNotifierProvider.notifier).confirmPayment();
          },
        ),
      ),
    );
  }

  if (next.errorMessage != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal: ${next.errorMessage}')),
    );
  }
});
```

## Ringkasan Perubahan

| File | Perubahan |
|---|---|
| `subscription_repository.dart` | `initiateUpgrade()` → `initiateUpgradeWithOrderId()`, return `UpgradeInitiationResult` (orderId + snapToken) |
| `subscription_provider.dart` | `upgradeTier()` simpan `pendingOrderId` ke state; `confirmPayment()` gak butuh parameter, ambil dari state |
| `subscription_screen.dart` | `onPaymentSuccess` callback disederhanakan, gak perlu manual pass orderId lagi |

Sekarang alurnya bersih tanpa gap — `orderId` di-generate sekali di repository, disimpan di state, dan dipakai lagi saat konfirmasi tanpa perlu di-pass manual berkali-kali lewat closure yang rawan lupa.

Lanjut ke fitur berikutnya sesuai TODO — **`features/profile/`**, atau ada yang mau dicek dulu dari subscription ini?
