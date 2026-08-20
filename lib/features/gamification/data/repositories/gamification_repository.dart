import 'package:tutur_id_app/shared/enums/quest_type.dart';
import 'package:tutur_id_app/shared/enums/xp_source.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/xp_log_model.dart';
import '../models/daily_quest_model.dart';
import '../models/leaderboard_entry_model.dart';

const _tag = 'GAMIFICATION_REPO';

class GamificationRepository {
  final FirebaseService _firebaseService;

  GamificationRepository(this._firebaseService);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ---------- XP ----------

  Future<void> addXp({
    required String userId,
    required int amount,
    required XpSource source,
    String? referenceId,
  }) async {

    // 1. Update total XP di users/{uid}
    final userData = await _firebaseService.getDocument('users', userId);
    final currentXp = userData?['xp'] as int? ?? 0;
    await _firebaseService.updateDocument('users', userId, {
      'xp': currentXp + amount,
    });

    // 2. Update weeklyXp di leaderboard/{uid}
    final leaderboardData = await _firebaseService.getDocument(
      'leaderboard',
      userId,
    );
    final currentWeeklyXp = leaderboardData?['weeklyXp'] as int? ?? 0;
    await _firebaseService.setDocument('leaderboard', userId, {
      'userId': userId,
      'username': userData?['username'] ?? 'Anonim',
      'photoUrl': userData?['photoUrl'],
      'weeklyXp': currentWeeklyXp + amount,
      'subscriptionTier': userData?['subscriptionTier'] ?? 'starter',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // 3. Catat log (audit trail)
    final logId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
    await _firebaseService.setDocument(
      'xp_logs',
      logId,
      XpLogModel(
        id: logId,
        userId: userId,
        amount: amount,
        source: source,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      ).toJson(),
    );

    AppLogger.s('XP +$amount (${source.name}) untuk user $userId', tag: _tag);
  }

  // ---------- DAILY QUEST ----------

  Future<DailyQuestModel> getTodayQuests(String userId) async {
    final data = await _firebaseService.getDocument('daily_quests', userId);

    // Belum ada data hari ini -> reset dengan template default
    if (data == null || data['date'] != _todayKey) {
      AppLogger.i('Reset daily quest untuk hari baru: $_todayKey', tag: _tag);
      final fresh = DailyQuestModel(
        date: _todayKey,
        quests: DailyQuestModel.defaultQuests(),
      );
      await _firebaseService.setDocument(
        'daily_quests',
        userId,
        fresh.toJson(),
      );
      return fresh;
    }

    return DailyQuestModel.fromJson(data);
  }

  Future<void> updateQuestProgress({
    required String userId,
    required QuestType type,
    int incrementBy = 1,
  }) async {
    final current = await getTodayQuests(userId);

    final updatedQuests = current.quests.map((quest) {
      if (quest.type != type || quest.completed) return quest;

      final newProgress = quest.currentProgress + incrementBy;
      final isNowCompleted = newProgress >= quest.targetCount;

      return quest.copyWith(
        currentProgress: newProgress.clamp(0, quest.targetCount),
        completed: isNowCompleted,
      );
    }).toList();

    await _firebaseService.setDocument(
      'daily_quests',
      userId,
      DailyQuestModel(date: current.date, quests: updatedQuests).toJson(),
    );

    // Kalau baru saja completed, langsung kasih XP reward
    final questJustCompleted = updatedQuests.firstWhere(
      (q) => q.type == type,
      orElse: () => updatedQuests.first,
    );
    final wasAlreadyCompleted = current.quests
        .firstWhere((q) => q.type == type, orElse: () => current.quests.first)
        .completed;

    if (questJustCompleted.completed && !wasAlreadyCompleted) {
      await addXp(
        userId: userId,
        amount: questJustCompleted.xpReward,
        source: XpSource.dailyQuest,
        referenceId: type.name,
      );
      AppLogger.s(
        'Quest ${type.name} selesai! +${questJustCompleted.xpReward} XP',
        tag: _tag,
      );
    }
  }

  // ---------- LEADERBOARD ----------

  Future<List<LeaderboardEntryModel>> getWeeklyLeaderboard({
    int limit = 50,
  }) async {
    final data = await _firebaseService.getCollection(
      'leaderboard',
      queryBuilder: (query) =>
          query.orderBy('weeklyXp', descending: true).limit(limit),
    );
    return data.map((e) => LeaderboardEntryModel.fromJson(e)).toList();
  }

  // ---------- STREAK & DAILY LOGIN ----------

  Future<void> handleDailyLogin(String userId) async {
    final userData = await _firebaseService.getDocument('users', userId);
    if (userData == null) return;

    final lastLoginStr = userData['lastLoginDate'] as String?;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int newStreak = userData['streak'] as int? ?? 0;

    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final lastLoginDay = DateTime(
        lastLogin.year,
        lastLogin.month,
        lastLogin.day,
      );
      final dayDifference = today.difference(lastLoginDay).inDays;

      if (dayDifference == 0) {
        // Sudah login hari ini, gak perlu proses ulang
        return;
      } else if (dayDifference == 1) {
        newStreak += 1; // login berturut-turut
      } else {
        newStreak = 1; // streak putus, reset
      }
    } else {
      newStreak = 1; // login pertama kali
    }

    await _firebaseService.updateDocument('users', userId, {
      'lastLoginDate': now.toIso8601String(),
      'streak': newStreak,
    });

    AppLogger.i('Daily login diproses, streak: $newStreak', tag: _tag);

    // Trigger quest "Daily Login"
    await updateQuestProgress(userId: userId, type: QuestType.dailyLogin);
  }

  // ---------- BATTERY REFRESH ----------

  Future<void> refreshBatteryIfNeeded({
    required String userId,
    required int maxCapacity,
    required int refillRatePerHour,
  }) async {
    final userData = await _firebaseService.getDocument('users', userId);
    if (userData == null) return;

    final currentBattery = userData['battery'] as int? ?? 0;
    if (currentBattery >= maxCapacity) return; // sudah penuh, gak perlu refill

    final lastRefillStr = userData['batteryLastRefill'] as String?;
    final now = DateTime.now();

    if (lastRefillStr == null) {
      // Belum pernah ada catatan refill, set sekarang sebagai baseline
      await _firebaseService.updateDocument('users', userId, {
        'batteryLastRefill': now.toIso8601String(),
      });
      return;
    }

    final lastRefill = DateTime.parse(lastRefillStr);
    final hoursPassed = now.difference(lastRefill).inMinutes / 60.0;
    final batteryToAdd = (hoursPassed * refillRatePerHour).floor();

    if (batteryToAdd <= 0) return; // belum cukup waktu buat nambah 1 baterai

    final newBattery = (currentBattery + batteryToAdd).clamp(0, maxCapacity);

    await _firebaseService.updateDocument('users', userId, {
      'battery': newBattery,
      'batteryLastRefill': now.toIso8601String(),
    });

    AppLogger.s(
      'Battery refresh: +$batteryToAdd (${hoursPassed.toStringAsFixed(1)} jam berlalu) -> $newBattery',
      tag: _tag,
    );
  }
}
