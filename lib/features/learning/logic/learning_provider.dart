import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/learning/data/models/module_model.dart';
import 'package:tutur_id_app/features/learning/data/repositories/learning_repository.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(ref.watch(firebaseServiceProvider));
});

// List modul per level
final modulesProvider = FutureProvider.family<List<ModuleModel>, int>((
  ref,
  level,
) async {
  return ref.watch(learningRepositoryProvider).getModulesByLevel(level);
});

// Detail satu modul
final moduleDetailProvider = FutureProvider.family<ModuleModel?, String>((
  ref,
  moduleId,
) async {
  return ref.watch(learningRepositoryProvider).getModuleById(moduleId);
});

// Progres modul yang sudah selesai (dipakai buat checklist/progress bar)
final completedModulesProvider = FutureProvider<List<String>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref
      .watch(learningRepositoryProvider)
      .getCompletedModuleIds(profile.uid);
});

// Notifier buat aksi: tandai modul selesai
class LearningNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> completeModule(String moduleId) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(learningRepositoryProvider)
          .markModuleCompleted(profile.uid, moduleId);
    });
    ref.invalidate(completedModulesProvider);
  }
}

final learningNotifierProvider = AsyncNotifierProvider<LearningNotifier, void>(
  LearningNotifier.new,
);
