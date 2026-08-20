import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/gamification/data/models/daily_quest_model.dart';
import 'package:tutur_id_app/features/gamification/data/models/leaderboard_entry_model.dart';
import 'package:tutur_id_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:tutur_id_app/shared/enums/quest_type.dart';
import 'package:tutur_id_app/shared/enums/user_tier.dart';
import 'package:tutur_id_app/shared/enums/xp_source.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(ref.watch(firebaseServiceProvider));
});

final todayQuestsProvider = FutureProvider<DailyQuestModel?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(gamificationRepositoryProvider).getTodayQuests(profile.uid);
});

final weeklyLeaderboardProvider = FutureProvider<List<LeaderboardEntryModel>>((
  ref,
) async {
  return ref.watch(gamificationRepositoryProvider).getWeeklyLeaderboard();
});

// Mapping tier -> battery config, dipakai buat refresh & limit
class BatteryConfig {
  final int maxCapacity;
  final int refillRatePerHour;
  const BatteryConfig({
    required this.maxCapacity,
    required this.refillRatePerHour,
  });
}

const _batteryConfigByTier = {
  UserTier.starter: BatteryConfig(maxCapacity: 14, refillRatePerHour: 1),
  UserTier.growth: BatteryConfig(maxCapacity: 30, refillRatePerHour: 2),
  UserTier.ultimate: BatteryConfig(
    maxCapacity: 999,
    refillRatePerHour: 999,
  ), // unlimited
};

class GamificationNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addXp({
    required int amount,
    required XpSource source,
    String? referenceId,
  }) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref
        .read(gamificationRepositoryProvider)
        .addXp(
          userId: profile.uid,
          amount: amount,
          source: source,
          referenceId: referenceId,
        );

    ref.invalidate(userProfileProvider);
    ref.invalidate(weeklyLeaderboardProvider);
  }

  Future<void> updateQuestProgress(
    QuestType type, {
    int incrementBy = 1,
  }) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref
        .read(gamificationRepositoryProvider)
        .updateQuestProgress(
          userId: profile.uid,
          type: type,
          incrementBy: incrementBy,
        );

    ref.invalidate(todayQuestsProvider);
    ref.invalidate(
      userProfileProvider,
    ); // XP mungkin berubah kalau quest completed
  }

  Future<void> handleDailyLogin() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref
        .read(gamificationRepositoryProvider)
        .handleDailyLogin(profile.uid);
    ref.invalidate(userProfileProvider);
    ref.invalidate(todayQuestsProvider);
  }

  Future<void> refreshBattery() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    final config = _batteryConfigByTier[profile.subscriptionTier]!;
    await ref
        .read(gamificationRepositoryProvider)
        .refreshBatteryIfNeeded(
          userId: profile.uid,
          maxCapacity: config.maxCapacity,
          refillRatePerHour: config.refillRatePerHour,
        );

    ref.invalidate(userProfileProvider);
  }
}

final gamificationNotifierProvider =
    AsyncNotifierProvider<GamificationNotifier, void>(GamificationNotifier.new);
