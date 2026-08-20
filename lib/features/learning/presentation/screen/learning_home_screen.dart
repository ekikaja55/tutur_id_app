import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/gamification/logic/gamification_provider.dart';
import 'package:tutur_id_app/features/gamification/presentation/widgets/daily_quest_card.dart';
import 'package:tutur_id_app/features/learning/data/models/level_model.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';

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
                final level = LevelModel.all[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text('Level ${level.level}: ${level.title}'),
                    subtitle: Text(level.description),
                    children: [_ModuleListForLevel(level: level.level)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleListForLevel extends ConsumerWidget {
  final int level;
  const _ModuleListForLevel({required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(modulesProvider(level));
    final completedAsync = ref.watch(completedModulesProvider);

    return modulesAsync.when(
      data: (modules) {
        final completedIds = completedAsync.value ?? [];
        if (modules.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada modul di level ini.'),
          );
        }
        return Column(
          children: modules.map((module) {
            final isCompleted = completedIds.contains(module.id);
            return ListTile(
              leading: Icon(
                isCompleted ? Icons.check_circle : Icons.play_circle_outline,
                color: isCompleted ? Colors.green : Colors.grey,
              ),
              title: Text(module.title),
              subtitle: Text(module.description),
              onTap: () => context.go('/learning/module/${module.id}'),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat modul: $err'),
      ),
    );
  }
}
