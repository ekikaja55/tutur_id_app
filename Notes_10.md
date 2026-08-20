Oke, lanjut ke **`features/gamification/`** — ini bakal jadi "pusat" XP, Daily Quest, Leaderboard, dan Battery Refresh, yang dipanggil dari `learning/` dan `ai_training/` yang sudah kita bangun.

## 1. Data Models

### `features/gamification/data/models/xp_log_model.dart`

```dart
// lib/features/gamification/data/models/xp_log_model.dart

enum XpSource { quiz, moduleComplete, aiSession, dailyQuest }

class XpLogModel {
  final String id;
  final String userId;
  final int amount;
  final XpSource source;
  final String? referenceId;
  final DateTime createdAt;

  XpLogModel({
    required this.id,
    required this.userId,
    required this.amount,

    required this.source,
    this.referenceId,
    required this.createdAt,
  });

  factory XpLogModel.fromJson(Map<String, dynamic> json) {
    return XpLogModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: json['amount'] as int,
      source: XpSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => XpSource.quiz,
      ),
      referenceId: json['referenceId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'source': source.name,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
```

### `features/gamification/data/models/daily_quest_model.dart`

```dart
// lib/features/gamification/data/models/daily_quest_model.dart

enum QuestType {
  dailyLogin,
  persistentLearner, // 3 sesi AI training
  knowledgeSeeker,   // 1 modul selesai
  quizMaster,        // 100% skor kuis 1 modul
  socialGiver,       // share progres
}

class QuestItem {
  final QuestType type;
  final String title;
  final int xpReward;
  final int targetCount; // misal: 3 untuk persistentLearner
  final int currentProgress;
  final bool completed;

  QuestItem({
    required this.type,
    required this.title,
    required this.xpReward,
    this.targetCount = 1,
    this.currentProgress = 0,
    this.completed = false,
  });

  factory QuestItem.fromJson(Map<String, dynamic> json) {
    return QuestItem(
      type: QuestType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestType.dailyLogin,
      ),
      title: json['title'] as String,
      xpReward: json['xpReward'] as int,
      targetCount: json['targetCount'] as int? ?? 1,
      currentProgress: json['currentProgress'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'title': title,
      'xpReward': xpReward,
      'targetCount': targetCount,
      'currentProgress': currentProgress,
      'completed': completed,
    };
  }

  QuestItem copyWith({int? currentProgress, bool? completed}) {
    return QuestItem(
      type: type,
      title: title,
      xpReward: xpReward,
      targetCount: targetCount,
      currentProgress: currentProgress ?? this.currentProgress,
      completed: completed ?? this.completed,
    );
  }
}

class DailyQuestModel {
  final String date; // format "2026-07-28"
  final List<QuestItem> quests;

  DailyQuestModel({required this.date, required this.quests});

  // Template default 5 quest harian, sesuai requirement
  static List<QuestItem> defaultQuests() => [
        QuestItem(type: QuestType.dailyLogin, title: 'Daily Login', xpReward: 10),
        QuestItem(
          type: QuestType.persistentLearner,
          title: 'Persistent Learner',
          xpReward: 50,
          targetCount: 3,
        ),
        QuestItem(type: QuestType.knowledgeSeeker, title: 'Knowledge Seeker', xpReward: 70),
        QuestItem(type: QuestType.quizMaster, title: 'Quiz Master', xpReward: 50),
        QuestItem(type: QuestType.socialGiver, title: 'Social Giver', xpReward: 20),
      ];

  factory DailyQuestModel.fromJson(Map<String, dynamic> json) {
    return DailyQuestModel(
      date: json['date'] as String,
      quests: (json['quests'] as List<dynamic>? ?? [])
          .map((e) => QuestItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date, 'quests': quests.map((e) => e.toJson()).toList()};
  }
}
```

### `features/gamification/data/models/leaderboard_entry_model.dart`

```dart
// lib/features/gamification/data/models/leaderboard_entry_model.dart

class LeaderboardEntryModel {
  final String userId;
  final String username;
  final String? photoUrl;
  final int weeklyXp;
  final String subscriptionTier;

  LeaderboardEntryModel({
    required this.userId,
    required this.username,
    this.photoUrl,
    required this.weeklyXp,
    required this.subscriptionTier,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      userId: json['userId'] as String,
      username: json['username'] as String,
      photoUrl: json['photoUrl'] as String?,
      weeklyXp: json['weeklyXp'] as int? ?? 0,
      subscriptionTier: json['subscriptionTier'] as String? ?? 'starter',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'photoUrl': photoUrl,
      'weeklyXp': weeklyXp,
      'subscriptionTier': subscriptionTier,
    };
  }
}
```

## 2. Repository

### `features/gamification/data/repositories/gamification_repository.dart`

```dart
// lib/features/gamification/data/repositories/gamification_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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
    await _firebaseService.updateDocument('users', userId, {'xp': currentXp + amount});

    // 2. Update weeklyXp di leaderboard/{uid}
    final leaderboardData = await _firebaseService.getDocument('leaderboard', userId);
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
    await _firebaseService.setDocument('xp_logs', logId, XpLogModel(
      id: logId,
      userId: userId,
      amount: amount,
      source: source,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    ).toJson());

    AppLogger.s('XP +$amount (${source.name}) untuk user $userId', tag: _tag);
  }

  // ---------- DAILY QUEST ----------

  Future<DailyQuestModel> getTodayQuests(String userId) async {
    final data = await _firebaseService.getDocument('daily_quests', userId);

    // Belum ada data hari ini -> reset dengan template default
    if (data == null || data['date'] != _todayKey) {
      AppLogger.i('Reset daily quest untuk hari baru: $_todayKey', tag: _tag);
      final fresh = DailyQuestModel(date: _todayKey, quests: DailyQuestModel.defaultQuests());
      await _firebaseService.setDocument('daily_quests', userId, fresh.toJson());
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
      AppLogger.s('Quest ${type.name} selesai! +${questJustCompleted.xpReward} XP', tag: _tag);
    }
  }

  // ---------- LEADERBOARD ----------

  Future<List<LeaderboardEntryModel>> getWeeklyLeaderboard({int limit = 50}) async {
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
      final lastLoginDay = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
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
```

## 3. Provider

### `features/gamification/logic/gamification_provider.dart`

```dart
// lib/features/gamification/logic/gamification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../../shared/enums/user_tier.dart';
import '../../auth/logic/auth_provider.dart';
import '../data/repositories/gamification_repository.dart';
import '../data/models/daily_quest_model.dart';
import '../data/models/xp_log_model.dart';
import '../data/models/leaderboard_entry_model.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository(ref.watch(firebaseServiceProvider));
});

final todayQuestsProvider = FutureProvider<DailyQuestModel?>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return null;
  return ref.watch(gamificationRepositoryProvider).getTodayQuests(profile.uid);
});

final weeklyLeaderboardProvider = FutureProvider<List<LeaderboardEntryModel>>((ref) async {
  return ref.watch(gamificationRepositoryProvider).getWeeklyLeaderboard();
});

// Mapping tier -> battery config, dipakai buat refresh & limit
class BatteryConfig {
  final int maxCapacity;
  final int refillRatePerHour;
  const BatteryConfig({required this.maxCapacity, required this.refillRatePerHour});
}

const _batteryConfigByTier = {
  UserTier.starter: BatteryConfig(maxCapacity: 14, refillRatePerHour: 1),
  UserTier.growth: BatteryConfig(maxCapacity: 30, refillRatePerHour: 2),
  UserTier.ultimate: BatteryConfig(maxCapacity: 999, refillRatePerHour: 999), // unlimited
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

    await ref.read(gamificationRepositoryProvider).addXp(
          userId: profile.uid,
          amount: amount,
          source: source,
          referenceId: referenceId,
        );

    ref.invalidate(userProfileProvider);
    ref.invalidate(weeklyLeaderboardProvider);
  }

  Future<void> updateQuestProgress(QuestType type, {int incrementBy = 1}) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref.read(gamificationRepositoryProvider).updateQuestProgress(
          userId: profile.uid,
          type: type,
          incrementBy: incrementBy,
        );

    ref.invalidate(todayQuestsProvider);
    ref.invalidate(userProfileProvider); // XP mungkin berubah kalau quest completed
  }

  Future<void> handleDailyLogin() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref.read(gamificationRepositoryProvider).handleDailyLogin(profile.uid);
    ref.invalidate(userProfileProvider);
    ref.invalidate(todayQuestsProvider);
  }

  Future<void> refreshBattery() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    final config = _batteryConfigByTier[profile.subscriptionTier]!;
    await ref.read(gamificationRepositoryProvider).refreshBatteryIfNeeded(
          userId: profile.uid,
          maxCapacity: config.maxCapacity,
          refillRatePerHour: config.refillRatePerHour,
        );

    ref.invalidate(userProfileProvider);
  }
}

final gamificationNotifierProvider = AsyncNotifierProvider<GamificationNotifier, void>(
  GamificationNotifier.new,
);
```

## 4. Integrasi ke Fitur yang Sudah Ada

### Update `learning_provider.dart` — `completeModule()` Sekarang Kasih XP

```dart
// lib/features/learning/logic/learning_provider.dart
// Tambahkan import gamification

class LearningNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> completeModule(String moduleId) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final wasAlreadyCompleted = (await ref
              .read(learningRepositoryProvider)
              .getCompletedModuleIds(profile.uid))
          .contains(moduleId);

      await ref.read(learningRepositoryProvider).markModuleCompleted(profile.uid, moduleId);

      // Cuma kasih XP kalau memang baru pertama kali selesai (bukan re-visit)
      if (!wasAlreadyCompleted) {
        await ref.read(gamificationNotifierProvider.notifier).addXp(
              amount: 100,
              source: XpSource.moduleComplete,
              referenceId: moduleId,
            );
        await ref.read(gamificationNotifierProvider.notifier)
            .updateQuestProgress(QuestType.knowledgeSeeker);
      }
    });
    ref.invalidate(completedModulesProvider);
  }
}
```

### Update `quiz_screen.dart` — XP per Jawaban Benar + Quest Master

```dart
// Di dalam _buildResult(), tambahkan logic XP kuis
Widget _buildResult(int totalQuestions) {
  final isPerfect = _correctCount == totalQuestions;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    ref.read(learningNotifierProvider.notifier).completeModule(widget.moduleId);

    // XP per jawaban benar
    if (_correctCount > 0) {
      await ref.read(gamificationNotifierProvider.notifier).addXp(
            amount: _correctCount * 10,
            source: XpSource.quiz,
            referenceId: widget.moduleId,
          );
    }

    // Quest Master kalau skor sempurna
    if (isPerfect) {
      await ref.read(gamificationNotifierProvider.notifier)
          .updateQuestProgress(QuestType.quizMaster);
    }
  });

  // ... sisanya tetap sama
}
```

### Update `ai_training_provider.dart` — XP + Quest Setelah Sesi Kamera

```dart
// Tambahkan method baru di AiTrainingNotifier
Future<void> completeSession() async {
  await ref.read(gamificationNotifierProvider.notifier).addXp(
        amount: 50,
        source: XpSource.aiSession,
      );
  await ref.read(gamificationNotifierProvider.notifier)
      .updateQuestProgress(QuestType.persistentLearner);
}
```

Panggil ini di `ai_training_screen.dart` saat modul selesai (di dalam tombol "Selesai" pas `isLastMaterial`):
```dart
if (isLastMaterial) {
  Navigator.of(context).pop();
  ref.read(aiTrainingProvider.notifier).completeSession(); // <- tambahkan ini
}
```

## 5. Widget: `DailyQuestCard` & `StreakIndicator`

### `features/gamification/presentation/widgets/daily_quest_card.dart`

```dart
// lib/features/gamification/presentation/widgets/daily_quest_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/gamification_provider.dart';

class DailyQuestCard extends ConsumerWidget {
  const DailyQuestCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(todayQuestsProvider);

    return questsAsync.when(
      data: (dailyQuest) {
        if (dailyQuest == null) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Misi Harian', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                ...dailyQuest.quests.map((quest) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            quest.completed ? Icons.check_circle : Icons.circle_outlined,
                            color: quest.completed ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(quest.title)),
                          Text('${quest.currentProgress}/${quest.targetCount}'),
                          const SizedBox(width: 8),
                          Text('+${quest.xpReward} XP',
                              style: const TextStyle(color: Colors.orange)),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
```

### `features/gamification/presentation/widgets/streak_indicator.dart`

```dart
// lib/features/gamification/presentation/widgets/streak_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/logic/auth_provider.dart';

class StreakIndicator extends ConsumerWidget {
  const StreakIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
              const SizedBox(width: 4),
              Text('${profile.streak} hari', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
```

## 6. Screen: Leaderboard

### `features/gamification/presentation/screens/leaderboard_screen.dart`

```dart
// lib/features/gamification/presentation/screens/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/gamification_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(weeklyLeaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Leaderboard')),
      body: leaderboardAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('Belum ada data leaderboard minggu ini'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(entry.username),
                subtitle: Text(entry.subscriptionTier.toUpperCase()),
                trailing: Text(
                  '${entry.weeklyXp} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
```

## 7. Hook ke Lifecycle App — Panggil `handleDailyLogin()` & `refreshBattery()`

Ini penting: keduanya perlu dipanggil **begitu user berhasil login/masuk app**, bukan cuma sekali onboarding. Tempatnya di `LearningHomeScreen` (home pelajar), pas pertama kali dibuka:

```dart
// lib/features/learning/presentation/screens/learning_home_screen.dart
class LearningHomeScreen extends ConsumerStatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  ConsumerState<LearningHomeScreen> createState() => _LearningHomeScreenState();
}

class _LearningHomeScreenState extends ConsumerState<LearningHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gamificationNotifierProvider.notifier).handleDailyLogin();
      ref.read(gamificationNotifierProvider.notifier).refreshBattery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belajar BISINDO')),
      body: Column(
        children: [
          const DailyQuestCard(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: LevelModel.all.length,
              itemBuilder: (context, index) {
                // ... sama seperti sebelumnya
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## 8. Update `router.dart` — Tambah Route Leaderboard

```dart
GoRoute(
  path: '/leaderboard',
  builder: (context, state) => const LeaderboardScreen(),
),
```

Jangan lupa masukkan ke `_studentOnlyPrefixes` di logic redirect yang udah kita buat sebelumnya.

## Update `TODO.txt`

```
[FITUR: GAMIFIKASI]
[x] Sistem XP otomatis (sesi latihan +50, modul +100, kuis +10 per jawaban benar)
[x] Daily Quest (5 misi, reset otomatis tiap hari berbeda)
[x] Weekly Leaderboard (denormalized data, order by weeklyXp)
[x] Provider: leaderboardProvider, dailyQuestProvider
[x] Battery refresh otomatis berdasarkan tier & waktu berlalu
[x] Streak tracking berdasarkan daily login
[ ] Visualisasi progres belajar (grafik) - PENDING, masuk ke features/profile/
[ ] Badge & banner reward untuk top rank - PENDING, perlu asset/desain dulu
[ ] Weekly leaderboard reset tiap Senin - PENDING, butuh scheduled function (Cloud Functions/cron)
```

## Catatan Penting: Weekly Reset Belum Otomatis

Aku sengaja **belum** implementasikan reset `weeklyXp` tiap Senin otomatis — karena itu butuh **scheduled job** (Cloud Functions dengan Cloud Scheduler, atau alternatif serverless lain), yang levelnya beda dari kode client Flutter yang udah kita buat sejauh ini. Untuk skala skripsi, ini bisa:
1. Di-set manual dari Firebase Console tiap awal minggu (paling simpel buat demo)
2. Atau dijadikan bagian "future work" di laporan kamu — jelasin bahwa arsitekturnya sudah siap, tinggal butuh Cloud Function terpisah buat automasi

Mana yang kamu mau untuk sekarang — skip dulu (manual reset), atau langsung coba setup Cloud Function sederhana?
