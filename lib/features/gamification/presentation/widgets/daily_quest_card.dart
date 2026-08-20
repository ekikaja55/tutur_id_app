import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:tutur_id_app/features/gamification/logic/gamification_provider.dart';

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
                Text(
                  'Misi Harian',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ...dailyQuest.quests.map(
                  (quest) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          quest.completed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: quest.completed ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(quest.title)),
                        Text('${quest.currentProgress}/${quest.targetCount}'),
                        const SizedBox(width: 8),
                        Text(
                          '+${quest.xpReward} XP',
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ),
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
