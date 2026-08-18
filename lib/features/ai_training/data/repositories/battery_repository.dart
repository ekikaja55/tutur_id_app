import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/core/services/providers.dart';

class BatteryRepository {
  final FirebaseService _firebaseService;
  BatteryRepository(this._firebaseService);

  Future<void> consumeBattery({
    required String userId,
    required int amount,
  }) async {
    final userData = await _firebaseService.getDocument('users', userId);
    final currentBattery = userData?['battery'] as int? ?? 0;
    final newBattery = (currentBattery - amount).clamp(0, 999);

    await _firebaseService.setDocument('users', userId, {
      'battery': newBattery,
    });
  }

  Future<void> refillBattery({
    required String userId,
    required int amount,
    required int maxAmount,
  }) async {
    final userData = await _firebaseService.getDocument('users', userId);
    final currentBattery = userData?['battery'] as int? ?? 0;
    final newBattery = (currentBattery - amount).clamp(0, maxAmount);

    await _firebaseService.setDocument('users', userId, {
      'battery': newBattery,
    });
  }
}

final batteryRepositoryProvider = Provider<BatteryRepository>((ref) {
  return BatteryRepository(ref.watch(firebaseServiceProvider));
});
