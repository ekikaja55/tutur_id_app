import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/features/learning/data/models/quiz_question.dart';

enum ModuleType { fingerspelling, lexical, spellingChallenge, masterChallenge }

class ModuleModel {
  final String id;
  final int level;
  final String title;
  final String description;
  final ModuleType type;
  final int order;
  final List<MaterialItem> materials;
  final List<QuizQuestion> quizQuestions;

  ModuleModel({
    required this.id,
    required this.level,
    required this.title,
    required this.description,
    required this.type,
    required this.order,
    required this.materials,
    required this.quizQuestions,
  });

  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    return ModuleModel(
      id: json['id'] as String,
      level: json['level'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: ModuleType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ModuleType.fingerspelling,
      ),
      order: json['order'] as int? ?? 0,
      materials: (json['materials'] as List<dynamic>? ?? [])
          .map((e) => MaterialItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      quizQuestions: (json['quizQuestions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}



