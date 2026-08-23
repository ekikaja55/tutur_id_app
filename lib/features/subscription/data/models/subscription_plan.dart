import 'package:tutur_id_app/shared/enums/user_tier.dart';

class SubscriptionPlan {
  final UserTier tier;
  final String title;
  final int price; // dalam Rupiah, 0 untuk Starter
  final int batteryCapacity;
  final int refillRatePerHour;
  final List<String> features;

  const SubscriptionPlan({
    required this.tier,
    required this.title,
    required this.price,
    required this.batteryCapacity,
    required this.refillRatePerHour,
    required this.features,
  });

  static const List<SubscriptionPlan> all = [
    SubscriptionPlan(
      tier: UserTier.starter,
      title: 'Starter',
      price: 0,
      batteryCapacity: 14,
      refillRatePerHour: 1,
      features: ['14 baterai', 'Refresh 1/jam', 'Akses Level 1-2'],
    ),
    SubscriptionPlan(
      tier: UserTier.growth,
      title: 'Growth',
      price: 35000,
      batteryCapacity: 30,
      refillRatePerHour: 2,
      features: [
        '30 baterai',
        'Refresh 2/jam',
        'Akses semua level',
        'Badge & banner eksklusif',
      ],
    ),
    SubscriptionPlan(
      tier: UserTier.ultimate,
      title: 'Ultimate',
      price: 75000,
      batteryCapacity: 999,
      refillRatePerHour: 999,
      features: [
        'Baterai unlimited',
        'Semua fitur premium',
        'Kustomisasi profil lanjutan',
      ],
    ),
  ];
}
