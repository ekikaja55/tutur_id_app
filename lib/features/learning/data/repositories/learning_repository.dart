import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/features/learning/data/models/module_model.dart';

class LearningRepository {
  final FirebaseService _firebaseService;

  LearningRepository(this._firebaseService);

  Future<List<ModuleModel>> getModulesByLevel(int level) async {
    final data = await _firebaseService.getCollection(
      'modules',
      queryBuilder: (query) =>
          query.where('level', isEqualTo: level).orderBy('order'),
    );
    return data.map((e) => ModuleModel.fromJson(e)).toList();
  }

  Future<ModuleModel?> getModuleById(String moduleId) async {
    final data = await _firebaseService.getDocument('modules', moduleId);
    if (data == null) return null;
    return ModuleModel.fromJson({...data, 'id': moduleId});
  }

  // Progres user: modul mana yang sudah selesai
  Future<List<String>> getCompletedModuleIds(String userId) async {
    final data = await _firebaseService.getDocument('user_progress', userId);
    if (data == null) return [];
    return List<String>.from(data['completedModules'] as List? ?? []);
  }

  Future<void> markModuleCompleted(String userId, String moduleId) async {
    final current = await getCompletedModuleIds(userId);
    if (!current.contains(moduleId)) {
      current.add(moduleId);
      await _firebaseService.setDocument('user_progress', userId, {
        'completedModules': current,
      });
    }
  }

  Future<Map<String, MaterialItem>> getMaterialLookup(List<int> levels) async {
    final lookup = <String, MaterialItem>{};
    for (final level in levels) {
      final modules = await getModulesByLevel(level);
      for (final module in modules) {
        for (final item in module.materials) {
          lookup[item.label.toUpperCase()] = item;
        }
      }
    }
    return lookup;
  }
}
