Setuju, mending diselesaikan sekarang mumpung konteksnya masih fresh. Sebelum masuk ke 3 modul ini, ada **1 refactor kecil** yang perlu dilakukan dulu — karena `AiTrainingScreen` saat ini cuma terima **satu** `ModelCategory` untuk seluruh sesi, padahal SpellingQuest & The Identity butuh **campuran** huruf+angka dalam satu sequence (beda model tiap item).

## 1. Refactor: `ModelCategoryResolver`

Daripada screen manual nentuin kategori, kita resolve otomatis **per-item** berdasarkan isi labelnya.

```dart
// lib/features/ai_training/ml/model/model_category_resolver.dart
import 'tflite_model_loader.dart';

class ModelCategoryResolver {
  /// Tentukan model mana yang dipakai berdasarkan isi label materi
  static ModelCategory resolve(String label) {
    // Angka murni -> model number
    if (RegExp(r'^[0-9]+$').hasMatch(label)) {
      return ModelCategory.number;
    }
    // Satu huruf tunggal -> model alphabet (fingerspelling)
    if (label.length == 1 && RegExp(r'^[A-Za-z]$').hasMatch(label)) {
      return ModelCategory.alphabet;
    }
    // Selain itu (kata/frasa) -> model words
    return ModelCategory.words;
  }
}
```

## 2. Update `AiTrainingScreen` — Hapus Parameter `category` Statis

Ini **menyederhanakan** kode yang sudah ada juga — `_categoryForModule()` yang kemarin sempat aku catat sebagai "rapuh" sekarang gak perlu lagi, karena resolve-nya per material, bukan per modul.

```dart
// lib/features/ai_training/presentation/screens/ai_training_screen.dart
// Ganti constructor, HAPUS field `category`

class AiTrainingScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final List<MaterialItem> materials;

  const AiTrainingScreen({
    super.key,
    required this.moduleId,
    required this.materials,
  });

  // ... sisanya sama
}
```

Update pemanggilan `startShutterTimer` — sekarang resolve category dari material yang sedang aktif:

```dart
// di dalam build(), ganti pemanggilan tombol "Mulai"
ElevatedButton.icon(
  onPressed: () => notifier.startShutterTimer(
    expectedLabel: currentMaterial.label,
    category: ModelCategoryResolver.resolve(currentMaterial.label),
  ),
  icon: const Icon(Icons.camera),
  label: const Text('Mulai (4 detik)'),
),
```

Update juga `module_detail_screen.dart` — hapus `_categoryForModule()` dan `extra: {'category': ...}` karena udah gak dipakai:

```dart
context.push(
  '/ai-training/${module.id}',
  extra: {'materials': module.materials}, // category dihapus dari sini
);
```

Dan `router.dart` disesuaikan (hapus parsing `category`):
```dart
GoRoute(
  path: '/ai-training/:moduleId',
  builder: (context, state) {
    final moduleId = state.pathParameters['moduleId']!;
    final extra = state.extra as Map<String, dynamic>?;
    return AiTrainingScreen(
      moduleId: moduleId,
      materials: extra?['materials'] ?? [],
    );
  },
),
```

## 3. Material Lookup — Cari `MaterialItem` Berdasarkan Label

Karena SpellingQuest/Identity/Master Challenge butuh **generate sequence dinamis** (bukan dari 1 modul tetap), kita butuh cara ambil `MaterialItem` (yang isinya video/gambar) berdasarkan label huruf/angka/kata apapun.

```dart
// lib/features/learning/data/repositories/learning_repository.dart
// Tambahkan method baru

Future<Map<String, MaterialItem>> getMaterialsLookup(List<int> levels) async {
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
```

```dart
// lib/features/learning/logic/learning_provider.dart
// Tambahkan provider baru

final materialsLookupProvider =
    FutureProvider.family<Map<String, MaterialItem>, List<int>>((ref, levels) async {
  return ref.watch(learningRepositoryProvider).getMaterialsLookup(levels);
});
```

## 4. Model: `ChallengeType` untuk Bedakan 3 Modul Spesial

Sesuai `ModuleType` yang udah ada (`spellingChallenge`, `masterChallenge`), tapi karena **SpellingQuest I** dan **The Identity** sama-sama `spellingChallenge`, kita butuh cara bedain keduanya. Untuk sekarang (sesuai gaya "asal bisa dulu"), aku bedakan dari `title` — sama seperti pendekatan `_categoryForModule` sebelumnya, dengan catatan yang sama soal kerapuhannya.

## 5. Screen: SpellingQuest I

```dart
// lib/features/learning/presentation/screens/spelling_quest_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/learning_provider.dart';
import '../../data/models/module_model.dart';

class SpellingQuestScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const SpellingQuestScreen({super.key, required this.moduleId});

  @override
  ConsumerState<SpellingQuestScreen> createState() => _SpellingQuestScreenState();
}

class _SpellingQuestScreenState extends ConsumerState<SpellingQuestScreen> {
  final _inputController = TextEditingController();
  String? _errorText;

  static const _options = ['ADA1', 'BACA02', 'MAMA4'];

  // Filter sesuai requirement: hanya A-M dan 0-4
  bool _isValidInput(String value) {
    return RegExp(r'^[A-Ma-m0-4]+$').hasMatch(value) && value.isNotEmpty;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _startChallenge(String word) async {
    final lookup = await ref.read(materialsLookupProvider([1]).future);

    final materials = <MaterialItem>[];
    for (final char in word.toUpperCase().split('')) {
      final item = lookup[char];
      if (item == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Materi untuk "$char" belum tersedia')),
          );
        }
        return;
      }
      materials.add(item);
    }

    if (mounted) {
      context.push('/ai-training/${widget.moduleId}', extra: {'materials': materials});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpellingQuest I')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih kata untuk dieja, atau ketik sendiri (huruf A-M dan angka 0-4)',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _options
                  .map((opt) => ActionChip(
                        label: Text(opt),
                        onPressed: () => _startChallenge(opt),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text('Atau ketik sendiri:'),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Contoh: BAJA13',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final value = _inputController.text.trim();
                if (!_isValidInput(value)) {
                  setState(() => _errorText = 'Hanya huruf A-M dan angka 0-4 yang diizinkan');
                  return;
                }
                setState(() => _errorText = null);
                _startChallenge(value);
              },
              child: const Text('Mulai Tantangan'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 6. Screen: The Identity

```dart
// lib/features/learning/presentation/screens/identity_challenge_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/learning_provider.dart';
import '../../data/models/module_model.dart';

class IdentityChallengeScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const IdentityChallengeScreen({super.key, required this.moduleId});

  @override
  ConsumerState<IdentityChallengeScreen> createState() => _IdentityChallengeScreenState();
}

class _IdentityChallengeScreenState extends ConsumerState<IdentityChallengeScreen> {
  final _nameController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startChallenge() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nama tidak boleh kosong');
      return;
    }

    // Level 2 sudah lengkap A-Z, jadi lookup dari level 1 + 2
    final lookup = await ref.read(materialsLookupProvider([1, 2]).future);

    final onlyLetters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (onlyLetters.isEmpty) {
      setState(() => _errorText = 'Nama harus mengandung huruf');
      return;
    }

    final materials = <MaterialItem>[];
    for (final char in onlyLetters.split('')) {
      final item = lookup[char];
      if (item == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Materi untuk "$char" belum tersedia')),
          );
        }
        return;
      }
      materials.add(item);
    }

    if (mounted) {
      context.push('/ai-training/${widget.moduleId}', extra: {'materials': materials});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Identity')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Masukkan nama lengkapmu, lalu peragakan tiap hurufnya.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Nama Lengkap',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startChallenge,
              child: const Text('Mulai Tantangan'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 7. Screen: The Master Challenge

```dart
// lib/features/learning/presentation/screens/master_challenge_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../logic/learning_provider.dart';
import '../../data/models/module_model.dart';

class MasterChallengeScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const MasterChallengeScreen({super.key, required this.moduleId});

  @override
  ConsumerState<MasterChallengeScreen> createState() => _MasterChallengeScreenState();
}

class _MasterChallengeScreenState extends ConsumerState<MasterChallengeScreen> {
  List<MaterialItem>? _generatedSentence;
  bool _loading = false;

  Future<void> _generateChallenge() async {
    setState(() => _loading = true);

    // Semua kosakata Level 3 (lexical)
    final lookup = await ref.read(materialsLookupProvider([3]).future);
    final allWords = lookup.values.toList();

    if (allWords.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kosakata Level 3 belum cukup untuk membuat tantangan')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    allWords.shuffle(Random());
    final sentence = allWords.take(3).toList();

    setState(() {
      _generatedSentence = sentence;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Master Challenge')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sistem akan memberikan 3 kosakata acak untuk kamu peragakan berurutan.'),
            const SizedBox(height: 24),
            if (_generatedSentence != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: _generatedSentence!
                        .map((item) => Chip(label: Text(item.label)))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.push(
                    '/ai-training/${widget.moduleId}',
                    extra: {'materials': _generatedSentence},
                  );
                },
                child: const Text('Mulai Peragakan'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _generateChallenge,
                child: const Text('Acak Ulang'),
              ),
            ] else
              ElevatedButton(
                onPressed: _loading ? null : _generateChallenge,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Buat Tantangan'),
              ),
          ],
        ),
      ),
    );
  }
}
```

## 8. Update `ModuleDetailScreen` — Routing Berdasarkan Tipe Modul

```dart
// lib/features/learning/presentation/screens/module_detail_screen.dart
// Update build() untuk cek tipe modul dulu

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

        // Modul spesial punya alur sendiri, bukan list materi + kuis standar
        if (module.type == ModuleType.spellingChallenge) {
          return module.title.toLowerCase().contains('identity')
              ? IdentityChallengeScreen(moduleId: module.id)
              : SpellingQuestScreen(moduleId: module.id);
        }
        if (module.type == ModuleType.masterChallenge) {
          return MasterChallengeScreen(moduleId: module.id);
        }

        return _buildContent(context, ref, module);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    ),
  );
}
```

> Catatan: karena `IdentityChallengeScreen`, `SpellingQuestScreen`, `MasterChallengeScreen` masing-masing punya `Scaffold` + `AppBar` sendiri, sementara mereka di-`return` di dalam `body:` milik `ModuleDetailScreen` yang **juga** punya `Scaffold`+`AppBar` — ini bakal jadi **nested Scaffold**, keliatan aneh (2 AppBar bertumpuk). Perlu diperbaiki: pindahkan `Scaffold`+`AppBar` dari `ModuleDetailScreen` supaya cuma 3 screen spesial itu yang punya `Scaffold` sendiri, sedangkan `_buildContent` (materi standar) dibungkus `Scaffold` terpisah juga.

### Fix: Pisahkan Jadi Routing Murni, Bukan Nested Body

```dart
// lib/features/learning/presentation/screens/module_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/module_model.dart';
import '../../logic/learning_provider.dart';
import 'spelling_quest_screen.dart';
import 'identity_challenge_screen.dart';
import 'master_challenge_screen.dart';

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
            appBar: AppBar(title: const Text('Materi')),
            body: const Center(child: Text('Modul tidak ditemukan')),
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
          appBar: AppBar(title: const Text('Materi')),
          body: _buildContent(context, ref, module),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ModuleModel module) {
    // ... sama seperti sebelumnya, TANPA Scaffold di dalamnya
  }
}
```

## Ringkasan Perubahan

| File | Perubahan |
|---|---|
| `ml/model/model_category_resolver.dart` | **Baru** — resolve kategori model per-label, bukan per-screen |
| `ai_training_screen.dart` | Hapus parameter `category`, resolve dinamis per material |
| `learning_repository.dart` | Tambah `getMaterialsLookup()` |
| `learning_provider.dart` | Tambah `materialsLookupProvider` |
| `spelling_quest_screen.dart` | **Baru** |
| `identity_challenge_screen.dart` | **Baru** |
| `master_challenge_screen.dart` | **Baru** |
| `module_detail_screen.dart` | Routing berdasarkan `ModuleType`, fix nested Scaffold |

## Update `TODO.txt`

```
[FITUR: LEARNING MODULE]
[x] Level 1: SpellingQuest I - selesai, reuse ai_training + material lookup
[x] Level 2: The Identity - selesai, reuse ai_training + material lookup
[x] Level 3: The Master Challenge - selesai, reuse ai_training + material lookup

[POLISH & DESIGN]
[ ] Ganti pembeda SpellingQuest vs Identity dari title-matching jadi field eksplisit (subType) di ModuleModel
```

Semua fitur inti (`auth`, `learning`, `ai_training`, `gamification`) sekarang saling terhubung. Lanjut ke `features/subscription/` sesuai rencana?
