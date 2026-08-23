import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/core/services/midtrans_service.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/subscription/data/models/transaction_model.dart';
import 'package:tutur_id_app/shared/enums/transaction_status.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';

const _tag = 'SUBSCRIPTION_REPO';

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
    final orderId =
        'TUTUR-${userId.substring(0, 6)}-${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.i(
      'Memulai transaksi: $orderId untuk tier ${targetTier.name}',
      tag: _tag,
    );

    // 1. Dapatkan Snap token dari Midtrans
    final snapToken = await _midtransService.createTransactionToken(
      orderId: orderId,
      grossAmount: amount,
      customerName: userName,
      customerEmail: userEmail,
    );

    // 2. Catat transaksi dengan status pending
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

    await _firebaseService.setDocument(
      'transactions',
      orderId,
      transaction.toJson(),
    );
    AppLogger.s('Transaksi dicatat dengan status pending', tag: _tag);

    return UpgradeInitiationResult(orderId: orderId, snapToken: snapToken);
  }

  /// Dipanggil setelah user selesai proses bayar (dari WebView Midtrans Snap)
  /// CATATAN: Idealnya validasi status sebenarnya lewat webhook Midtrans (Cloud Function),
  /// ini fallback client-side untuk update optimis sementara skripsi.
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

    // Update tier user
    await _firebaseService.updateDocument('users', userId, {
      'subscriptionTier': tier.toMap(),
      'subscriptionExpiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
    });

    // Update juga collection subscriptions terpisah
    await _firebaseService.setDocument('subscriptions', userId, {
      'tier': tier.toMap(),
      'startDate': DateTime.now().toIso8601String(),
      'expiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'status': 'active',
      'lastTransactionId': orderId,
    });

    AppLogger.s('Tier user berhasil diupdate ke ${tier.name}', tag: _tag);
  }

  Future<List<TransactionModel>> getUserTransactions(String userId) async {
    final data = await _firebaseService.getCollection(
      'transactions',
      queryBuilder: (query) => query
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
    );
    return data.map((e) => TransactionModel.fromJson(e)).toList();
  }
}
