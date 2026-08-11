Oke, kita kerjakan bertahap. Karena Level 1-3 punya banyak variasi modul (fingerspelling, quiz, challenge, spelling), aku desain dulu **model generik yang fleksibel** supaya gak perlu bikin model beda-beda untuk tiap modul — baru nanti tiap modul tinggal isi data sesuai tipenya.

## 1. Data Model

### `features/learning/data/models/module_model.dart`

```dart
// lib/features/learning/data/models/module_model.dart

enum ModuleType {
  fingerspelling,   // belajar huruf/angka satu-satu (Level 1-2)
  lexical,          // belajar kosakata kata utuh (Level 3)
  spellingChallenge, // SpellingQuest, The Identity
  masterChallenge,   // The Master Challenge (kalimat 3 kosakata)
}

class ModuleModel {
  final String id;
  final int level; // 1, 2, atau 3
  final String title; // "Alphabet Alpha (A-M)"
  final String description;
  final ModuleType type;
  final int order; // urutan tampil dalam level
  final List<MaterialItem> materials; // konten belajar (huruf/angka/kata)
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level,
      'title': title,
      'description': description,
      'type': type.name,
      'order': order,
      'materials': materials.map((e) => e.toJson()).toList(),
      'quizQuestions': quizQuestions.map((e) => e.toJson()).toList(),
    };
  }
}

// Satu unit materi: satu huruf, satu angka, atau satu kata
class MaterialItem {
  final String id;
  final String label; // "A", "5", "Terima Kasih"
  final String videoUrl; // dari Cloudinary
  final String? imageUrl;

  MaterialItem({
    required this.id,
    required this.label,
    required this.videoUrl,
    this.imageUrl,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] as String,
      label: json['label'] as String,
      videoUrl: json['videoUrl'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'videoUrl': videoUrl, 'imageUrl': imageUrl};
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctOptionIndex;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctOptionIndex: json['correctOptionIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
    };
  }
}
```

### `features/learning/data/models/level_model.dart`

```dart
// lib/features/learning/data/models/level_model.dart

class LevelModel {
  final int level; // 1, 2, 3
  final String title; // "First Steps", "Essential Skills", "Daily Conversation"
  final String description;

  const LevelModel({
    required this.level,
    required this.title,
    required this.description,
  });

  // Static data - level cuma 3 dan gak berubah-ubah, gak perlu simpan di Firestore
  static const List<LevelModel> all = [
    LevelModel(
      level: 1,
      title: 'First Steps',
      description: 'Langkah awal mengenal fingerspelling dan angka dasar',
    ),
    LevelModel(
      level: 2,
      title: 'Essential Skills',
      description: 'Melengkapi kemampuan mengeja secara utuh',
    ),
    LevelModel(
      level: 3,
      title: 'Daily Conversation',
      description: 'Belajar kosakata percakapan sehari-hari',
    ),
  ];
}
```

> **Catatan desain**: `LevelModel` sengaja **hardcoded**, bukan diambil dari Firestore — karena berdasarkan requirement awal kamu, cuma ada 3 level yang fixed dan gak akan berubah (kamu bilang admin cuma bisa update **isi** materi, bukan ubah struktur Level 1-3). Kalau nanti butuh dinamis, tinggal ganti jadi fetch dari Firestore.

## 2. Repository

### `features/learning/data/repositories/learning_repository.dart`

```dart
// lib/features/learning/data/repositories/learning_repository.dart
import '../../../../core/services/firebase_service.dart';
import '../models/module_model.dart';

class LearningRepository {
  final FirebaseService _firebaseService;

  LearningRepository(this._firebaseService);

  Future<List<ModuleModel>> getModulesByLevel(int level) async {
    final data = await _firebaseService.getCollection(
      'modules',
      queryBuilder: (query) => query
          .where('level', isEqualTo: level)
          .orderBy('order'),
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
      await _firebaseService.setDocument(
        'user_progress',
        userId,
        {'completedModules': current},
      );
    }
  }
}
```

## 3. Provider

### `features/learning/logic/learning_provider.dart`

```dart
// lib/features/learning/logic/learning_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../auth/logic/auth_provider.dart';
import '../data/repositories/learning_repository.dart';
import '../data/models/module_model.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return LearningRepository(ref.watch(firebaseServiceProvider));
});

// List modul per level
final modulesProvider = FutureProvider.family<List<ModuleModel>, int>((ref, level) async {
  return ref.watch(learningRepositoryProvider).getModulesByLevel(level);
});

// Detail satu modul
final moduleDetailProvider = FutureProvider.family<ModuleModel?, String>((ref, moduleId) async {
  return ref.watch(learningRepositoryProvider).getModuleById(moduleId);
});

// Progres modul yang sudah selesai (dipakai buat checklist/progress bar)
final completedModulesProvider = FutureProvider<List<String>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(learningRepositoryProvider).getCompletedModuleIds(profile.uid);
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
      await ref.read(learningRepositoryProvider).markModuleCompleted(profile.uid, moduleId);
    });
    ref.invalidate(completedModulesProvider);
  }
}

final learningNotifierProvider = AsyncNotifierProvider<LearningNotifier, void>(
  LearningNotifier.new,
);
```

## 4. Screen: List Level & Modul

### `features/learning/presentation/screens/learning_home_screen.dart`

```dart
// lib/features/learning/presentation/screens/learning_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/level_model.dart';
import '../../logic/learning_provider.dart';

class LearningHomeScreen extends ConsumerWidget {
  const LearningHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belajar BISINDO')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: LevelModel.all.length,
        itemBuilder: (context, index) {
          final level = LevelModel.all[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text('Level ${level.level}: ${level.title}'),
              subtitle: Text(level.description),
              children: [
                _ModuleListForLevel(level: level.level),
              ],
            ),
          );
        },
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
```

## 5. Screen: Detail Materi

### `features/learning/presentation/screens/module_detail_screen.dart`

```dart
// lib/features/learning/presentation/screens/module_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/learning_provider.dart';
import '../../data/models/module_model.dart';
import 'quiz_screen.dart';

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

  Widget _buildContent(BuildContext context, WidgetRef ref, ModuleModel module) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(module.title, style: Theme.of(context).textTheme.headlineMedium),
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
                      Text(item.label, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      // Simpel dulu: tampilkan sebagai placeholder video player
                      // TODO: ganti dengan video_player + Cloudinary URL asli
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          color: Colors.black12,
                          child: const Center(child: Icon(Icons.play_circle, size: 48)),
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
```

## 6. Screen: Kuis (Generik untuk Semua Modul)

### `features/learning/presentation/screens/quiz_screen.dart`

```dart
// lib/features/learning/presentation/screens/quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/learning_provider.dart';

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
                Text('Soal ${_currentIndex + 1}/${module.quizQuestions.length}'),
                const SizedBox(height: 16),
                Text(question.question, style: Theme.of(context).textTheme.headlineMedium),
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

    // Tandai modul selesai begitu kuis kelar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(learningNotifierProvider.notifier).completeModule(widget.moduleId);
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
}
```

## 7. Update `router.dart`

```dart
GoRoute(
  path: '/learning',
  builder: (context, state) => const LearningHomeScreen(),
  routes: [
    GoRoute(
      path: 'module/:moduleId',
      builder: (context, state) {
        final moduleId = state.pathParameters['moduleId']!;
        return ModuleDetailScreen(moduleId: moduleId);
      },
      routes: [
        GoRoute(
          path: 'quiz',
          builder: (context, state) {
            final moduleId = state.pathParameters['moduleId']!;
            return QuizScreen(moduleId: moduleId);
          },
        ),
      ],
    ),
  ],
),
```

## Soal Level 1-3 dengan Berbagai Tipe Modul Spesifik

Sekarang poin pentingnya — **kamu gak perlu bikin kode terpisah untuk tiap modul** (Alphabet Alpha, Number Base, dst). Karena model `ModuleModel` sudah generik, **semua modul fingerspelling/quiz standar** (Alphabet Alpha, Number Base, Alphabet Omega, Number Advance, Social Essentials, Direction & Position, Expressive Signs) **otomatis jalan** pakai `ModuleDetailScreen` + `QuizScreen` yang sudah dibuat — tinggal beda **datanya** (diisi oleh admin lewat CRUD Materi nanti, atau untuk sekarang kamu input manual ke Firestore Console buat testing).

**Yang butuh screen KHUSUS** (karena punya interaksi beda dari sekadar "lihat materi + kuis pilihan ganda"):

| Modul | Kenapa butuh screen khusus |
|---|---|
| **SpellingQuest I** (Level 1) | Ada input teks manual dengan filter karakter (A-M, 0-4) |
| **The Identity** (Level 2) | User isi nama lengkap, sistem minta peragakan tiap huruf |
| **The Master Challenge** (Level 3) | Kalimat 3 kosakata acak, harus diperagakan berurutan di kamera |

Ketiga ini **butuh integrasi kamera** (`ai_training/`) juga, jadi masuk akal dikerjakan **setelah** `ai_training/` selesai, bukan sekarang — karena mereka bergantung ke situ.

## Yang Sudah Selesai vs Yang Ditunda

✅ **Selesai sekarang** (cover 7 dari 10 sub-modul):
- Alphabet Alpha, Number Base, Alphabet Omega, Number Advance, Social Essentials, Direction & Position, Expressive Signs — semua pakai `ModuleDetailScreen` + `QuizScreen` generik ini.

⏸️ **Ditunda sampai `ai_training/` selesai**:
- SpellingQuest I, The Identity, The Master Challenge — butuh integrasi kamera.

Update `TODO.txt` biar jelas:
```
[FITUR: LEARNING MODULE]
[x] Data model Module & Level
[x] Repository ambil data modul dari Firestore
[x] Provider: learningRepositoryProvider, modulesProvider
[x] Screen list level & modul
[x] Screen detail materi + kuis generik
[x] Level 1: Alphabet Alpha, Number Base (pakai screen generik)
[x] Level 2: Alphabet Omega, Number Advance (pakai screen generik)
[x] Level 3: Social Essentials, Direction & Position, Expressive Signs (pakai screen generik)
[ ] Level 1: SpellingQuest I - PENDING, butuh ai_training/ selesai dulu
[ ] Level 2: The Identity - PENDING, butuh ai_training/ selesai dulu
[ ] Level 3: The Master Challenge - PENDING, butuh ai_training/ selesai dulu
```

Masuk akal strateginya? Kalau iya, lanjut ke **`features/ai_training/`** sekarang — biar 3 modul yang pending itu juga bisa segera dikerjakan?
