import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/module_model.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';
import 'package:tutur_id_app/shared/enums/model_category.dart';

class ModuleDetailScreen extends ConsumerWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moduleAsync = ref.watch(moduleDetailProvider(moduleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Materi')),
      body: moduleAsync.when(
        data: (module) {
          if (module == null) {
            return const Center(child: Text('Modul tidak ditemukan'));
          }
          return _buildContent(context, ref, module);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
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
                      extra: {
                        'materials': module.materials,
                        'category': _categoryForModule(module),
                      },
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

  // Helper: tentukan model TFLite mana yang dipakai berdasarkan level & tipe modul
  ModelCategory _categoryForModule(ModuleModel module) {
    // Level 1-2 isinya alphabet & number (fingerspelling)
    // Level 3 isinya kosakata/lexical (words)
    if (module.type == ModuleType.lexical) {
      return ModelCategory.words;
    }

    // Untuk fingerspelling, perlu bedakan alphabet vs number
    // berdasarkan title modul (sesuai penamaan modul di requirement awal kamu)
    final title = module.title.toLowerCase();
    if (title.contains('number') || title.contains('angka')) {
      return ModelCategory.number;
    }

    return ModelCategory.alphabet; // default untuk Alphabet Alpha/Omega
  }
}
