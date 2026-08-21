import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/module_model.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/identity_challange_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/master_challange_screen.dart';
import 'package:tutur_id_app/features/learning/presentation/screen/spelling_quest_screen.dart';

class ModuleDetailScreen extends ConsumerWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleDetailProvider(moduleId));

    return moduleAsync.when(
      data: (module) {
        if (module == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Learning Materials')),
            body: const Center(child: Text('Module not found')),
          );
        }

        // Modul spesial - masing-masing sudah punya Scaffold sendiri
        if (module.type == ModuleType.spellingChallenge) {
          return module.title.toLowerCase().contains('identity')
              ? IdentityChallengeScreen(moduleId: module.id)
              : SpellingQuestScreen(moduleId: module.id);
        }
        if (module.type == ModuleType.masterChallenge) {
          return MasterChallengeScreen(moduleId: module.id);
        }
        // Modul standar
        return Scaffold(
          appBar: AppBar(title: const Text('Learning Materials')),
          body: _buildContent(context, ref, module),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ModuleModel module,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            module.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: module.materials.length,
            itemBuilder: (context, index) {
              final item = module.materials[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.play_circle, size: 48),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: module.materials.isEmpty
                ? null
                : () {
                    context.push(
                      '/ai-training/${module.id}',
                      extra: {'materials': module.materials},
                    );
                  },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Latihan Kamera'),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: module.quizQuestions.isEmpty
                ? null
                : () {
                    context.push('/learning/module/${module.id}/quiz');
                  },
            child: Text(
              module.quizQuestions.isEmpty ? 'Tidak ada kuis' : 'Mulai Kuis',
            ),
          ),
        ),
      ],
    );
  }
}
