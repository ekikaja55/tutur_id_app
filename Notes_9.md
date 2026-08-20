Oke, setuju — fondasi udah solid, kita lanjut bangun dulu baru nanti sekali gas testing & tweak semua sekaligus di HP fisik.

Sebelum pindah ke fitur lain, ada 2 hal kecil yang perlu dibereskan dulu biar `ai_training/` ini "closed" sebagai satu unit (gak nanggung):

## 1. Permission Handling (Singkat)

Cukup tambahkan `permission_handler` biar gak crash diam-diam kalau user reject izin kamera.

```yaml
# pubspec.yaml
dependencies:
  permission_handler: ^11.3.1
```

Update `camera_controller_provider.dart`, tambahkan cek permission sebelum `initialize()`:

```dart
// lib/features/ai_training/logic/camera_controller_provider.dart
import 'package:permission_handler/permission_handler.dart';
// ... import lain tetap

class CameraControllerNotifier extends AsyncNotifier<CameraController?> {
  // ... build() tetap sama

  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.back}) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final permissionStatus = await Permission.camera.request();
      if (!permissionStatus.isGranted) {
        AppLogger.w('Izin kamera ditolak', tag: _tag);
        throw Exception('Izin kamera diperlukan untuk fitur ini');
      }

      final cameras = await ref.read(availableCamerasProvider.future);
      if (cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia di device ini');
      }

      final selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      AppLogger.s('Kamera berhasil diinisialisasi', tag: _tag);
      return controller;
    });
  }

  // ... sisanya tetap sama
}
```

Android manifest juga perlu ditambah (selain yang kemarin):
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
```
(sudah ada dari sebelumnya, tinggal pastikan `permission_handler` juga otomatis handle request dialog-nya)

## 2. Update `router.dart` — Daftarkan Route `ai_training`

```dart
// app/router.dart
GoRoute(
  path: '/ai-training/:moduleId',
  builder: (context, state) {
    final moduleId = state.pathParameters['moduleId']!;
    // materials & category idealnya dikirim lewat extra, bukan parse ulang dari path
    final extra = state.extra as Map<String, dynamic>?;
    return AiTrainingScreen(
      moduleId: moduleId,
      materials: extra?['materials'] ?? [],
      category: extra?['category'] ?? ModelCategory.alphabet,
    );
  },
),
```

Dan cara manggilnya dari `ModuleDetailScreen` (perlu ditambahkan tombol "Latihan Kamera" di sana nanti):
```dart
context.push(
  '/ai-training/${module.id}',
  extra: {
    'materials': module.materials,
    'category': _categoryForModule(module), // helper function mapping level/type -> ModelCategory
  },
);
```

> Catatan: pakai `extra` di `go_router` untuk pass object kompleks (`List<MaterialItem>`, enum) itu **normal dan aman** selama navigasi terjadi dalam 1 app session — beda dengan pass lewat query parameter yang harus string. Cuma perlu diingat `extra` gak akan survive kalau app di-restart dari deep link eksternal (gak relevan buat kasus kita karena ini internal navigation).

## Update `TODO.txt` — Checklist Section AI Training

```
[FITUR: AI TRAINING / KAMERA]
[x] Setup TFLite interpreter (load + cache per kategori model)
[x] Implementasi preprocessing (resize 320x320, normalisasi, RGB, Float32List)
[x] Implementasi inference pipeline + logging validasi tensor
[x] Provider: aiTrainingProvider (shutter timer + capture + detect)
[x] UI kamera + shutter countdown + popup hasil
[x] Sistem baterai: consumption 2 poin/sesi (dipotong sekali di awal sesi)
[x] CameraController setup + permission handling
[ ] Sistem baterai: refresh rate per tier - PENDING, masuk ke fitur subscription/gamification
[ ] Sync status baterai real-time ke Firebase - PENDING (saat ini masih single fetch, belum stream)
[ ] Frame throttling / skip-frame optimization - SKIP, sudah teratasi dengan shutter-trigger approach
[ ] Rotasi frame kamera - PENDING, perlu testing di device fisik dulu
[ ] Testing performa di device low-end - PENDING, nanti sekaligus di fase testing
[ ] Trigger completeModule() setelah AI training modul selesai - PENDING, perlu integrasi ke learning/
```

## Sisa Pekerjaan yang Sengaja Ditunda (Bukan Lupa)

1. **`completeModule()` belum terhubung** — di popup hasil benar (`isLastMaterial`), masih ada komentar `// TODO: trigger completeModule`. Ini nyambung ke `learningNotifierProvider` yang udah kita buat di fitur `learning/`.
2. **XP belum ditambahkan** — sesuai requirement, selesai sesi AI training harusnya +50 XP, tapi `gamification/` belum kita bangun sama sekali.
3. **Battery sync masih single fetch**, bukan `StreamProvider` — jadi kalau baterai berubah di device lain, gak auto-update real-time di UI. Ini optimisasi yang bisa nyusul.

Ini semua **saling terkait** dan enaknya diselesaikan sekalian pas kita bangun `features/gamification/` (karena baik battery refresh maupun XP itu domainnya gamifikasi). Jadi urutan selanjutnya menurutku:

## Rekomendasi Urutan Berikutnya

1. **`features/gamification/`** — biar `completeModule()` + XP + battery refresh bisa langsung terintegrasi penuh ke `learning/` dan `ai_training/` yang sudah dibuat
2. **`features/subscription/`** — nyambung ke battery capacity per tier & Midtrans yang service-nya udah siap dari awal
3. Modul spesial yang tadi di-skip: **SpellingQuest I, The Identity, The Master Challenge** — sekarang udah bisa dikerjakan karena `ai_training/` udah ada

Mau lanjut ke `features/gamification/` sesuai urutan ini?

Maksudnya di dalam method `_buildContent()`, sejajar dengan tombol "Mulai Kuis" yang udah ada — jadi ada 2 tombol di bagian bawah: "Latihan Kamera" dan "Mulai Kuis". Ini aku kasih posisi persisnya plus helper function `_categoryForModule` yang kemarin baru aku sebut tapi belum aku buatkan.

## Update `module_detail_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/module_model.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';
import 'package:tutur_id_app/features/ai_training/ml/model/tflite_model_loader.dart';

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

        // ============ INI BAGIAN YANG DITAMBAHKAN ============
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
        // ============ SAMPAI SINI ============

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
```

## Kenapa Logic `_categoryForModule` Ditaruh di Sini, Bukan di `ModuleModel`?

Ini keputusan desain kecil yang perlu aku jelasin — aku taruh logic mapping ini di **screen**, bukan di `ModuleModel` itu sendiri, karena:
- `ModuleModel` itu representasi **data murni** dari Firestore, gak seharusnya tau soal `ModelCategory` yang notabene konsep dari fitur `ai_training/` (beda domain fitur).
- Kalau taruh di model, `learning/` jadi punya dependency ke `ai_training/` cuma buat satu helper function — melanggar prinsip "fitur harusnya independent kecuali lewat shared/core".

## ⚠️ Catatan: Ini Solusi Sementara yang Agak Rapuh

Jujur, logic `_categoryForModule` yang nebak dari **string title** (`title.contains('number')`) itu **rapuh** — kalau nanti admin ganti judul modul dikit aja beda kapitalisasi/typo, kategori bisa salah deteksi. Ini masuk kategori **"asal bisa dulu"** sesuai kesepakatan kita.

**Solusi lebih baik untuk nanti**: tambahkan field eksplisit `modelCategory` langsung di `ModuleModel` (disimpan di Firestore juga), jadi admin yang nentuin pas CRUD materi, bukan ditebak dari title. Aku catat ini juga di `TODO.txt`:

```
[POLISH & DESIGN]
[ ] Ganti _categoryForModule() dari string-matching jadi field eksplisit `modelCategory` di ModuleModel
```

Sudah jelas posisinya? Lanjut ke `features/gamification/`?
