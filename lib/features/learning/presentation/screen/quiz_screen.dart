import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/gamification/logic/gamification_provider.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';
import 'package:tutur_id_app/shared/enums/quest_type.dart';
import 'package:tutur_id_app/shared/enums/xp_source.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const QuizScreen({super.key, required this.moduleId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOption;
  bool _answered = false;

  @override
  Widget build(BuildContext context) {
    final moduleAsync = ref.watch(moduleDetailProvider(widget.moduleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Kuis')),
      body: moduleAsync.when(
        data: (module) {
          if (module == null || module.quizQuestions.isEmpty) {
            return const Center(child: Text('Tidak ada soal kuis'));
          }

          if (_currentIndex >= module.quizQuestions.length) {
            return _buildResult(module.quizQuestions.length);
          }

          final question = module.quizQuestions[_currentIndex];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soal ${_currentIndex + 1}/${module.quizQuestions.length}',
                ),
                const SizedBox(height: 16),
                Text(
                  question.question,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                ...List.generate(question.options.length, (i) {
                  final isCorrect = i == question.correctOptionIndex;
                  final isSelected = i == _selectedOption;

                  Color? tileColor;
                  if (_answered && isSelected) {
                    tileColor = isCorrect ? Colors.green[100] : Colors.red[100];
                  } else if (_answered && isCorrect) {
                    tileColor = Colors.green[100];
                  }

                  return Card(
                    color: tileColor,
                    child: ListTile(
                      title: Text(question.options[i]),
                      onTap: _answered
                          ? null
                          : () {
                              setState(() {
                                _selectedOption = i;
                                _answered = true;
                                if (isCorrect) _correctCount++;
                              });
                            },
                    ),
                  );
                }),
                const Spacer(),
                if (_answered)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex++;
                        _selectedOption = null;
                        _answered = false;
                      });
                    },
                    child: Text(
                      _currentIndex + 1 >= module.quizQuestions.length
                          ? 'Selesai'
                          : 'Soal Berikutnya',
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildResult(int totalQuestions) {
    final isPerfect = _correctCount == totalQuestions;

    // Semua logic async digabung jadi satu callback, dipanggil sekali
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleQuizCompletion(isPerfect);
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPerfect ? Icons.emoji_events : Icons.check_circle,
            size: 64,
            color: isPerfect ? Colors.amber : Colors.green,
          ),
          const SizedBox(height: 16),
          Text(
            'Skor: $_correctCount / $totalQuestions',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/learning'),
            child: const Text('Kembali ke Daftar Modul'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuizCompletion(bool isPerfect) async {
    await ref
        .read(learningNotifierProvider.notifier)
        .completeModule(widget.moduleId);

    if (_correctCount > 0) {
      await ref
          .read(gamificationNotifierProvider.notifier)
          .addXp(
            amount: _correctCount * 10,
            source: XpSource.quiz,
            referenceId: widget.moduleId,
          );
    }

    if (isPerfect) {
      await ref
          .read(gamificationNotifierProvider.notifier)
          .updateQuestProgress(QuestType.quizMaster);
    }
  }
}
