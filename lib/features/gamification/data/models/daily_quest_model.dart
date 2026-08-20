
import 'package:tutur_id_app/shared/enums/quest_type.dart';

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
    QuestItem(
      type: QuestType.knowledgeSeeker,
      title: 'Knowledge Seeker',
      xpReward: 70,
    ),
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
