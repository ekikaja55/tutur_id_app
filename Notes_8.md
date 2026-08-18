Oke, lanjut ke setup `CameraController` — ini yang akan menggantikan placeholder `Container(color: Colors.black87)` dengan preview kamera asli, dan jadi sumber `CameraImage` yang di-capture saat shutter selesai.

## 1. `features/ai_training/logic/camera_controller_provider.dart`

```dart
// lib/features/ai_training/logic/camera_controller_provider.dart
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';

const _tag = 'CAMERA';

/// List kamera yang tersedia di device (front & back)
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  try {
    final cameras = await availableCameras();
    AppLogger.i('Ditemukan ${cameras.length} kamera', tag: _tag);
    for (final cam in cameras) {
      AppLogger.i('- ${cam.name} (${cam.lensDirection})', tag: _tag);
    }
    return cameras;
  } catch (error, stackTrace) {
    AppLogger.e('Gagal mengambil daftar kamera', error: error, stackTrace: stackTrace, tag: _tag);
    return [];
  }
});

/// Notifier untuk lifecycle CameraController
class CameraControllerNotifier extends AsyncNotifier<CameraController?> {
  @override
  Future<CameraController?> build() async {
    ref.onDispose(() {
      state.value?.dispose();
      AppLogger.i('CameraController di-dispose', tag: _tag);
    });
    return null;
  }

  Future<void> initialize({CameraLensDirection direction = CameraLensDirection.back}) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final cameras = await ref.read(availableCamerasProvider.future);
      if (cameras.isEmpty) {
        throw Exception('Tidak ada kamera yang tersedia di device ini');
      }

      final selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => cameras.first,
      );

      AppLogger.i('Inisialisasi kamera: ${selectedCamera.name}', tag: _tag);

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // cukup untuk 320x320 input model, hemat resource
        enableAudio: false, // gak butuh audio untuk gesture detection
        imageFormatGroup: ImageFormatGroup.yuv420, // sesuai preprocessing kita
      );

      await controller.initialize();
      AppLogger.s('Kamera berhasil diinisialisasi', tag: _tag);

      return controller;
    });
  }

  Future<void> switchCamera() async {
    final current = state.value;
    if (current == null) return;

    final newDirection = current.description.lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    AppLogger.i('Beralih kamera ke: $newDirection', tag: _tag);

    await current.dispose();
    await initialize(direction: newDirection);
  }

  Future<void> disposeCamera() async {
    final current = state.value;
    if (current != null) {
      await current.dispose();
      state = const AsyncData(null);
      AppLogger.i('Kamera di-dispose manual', tag: _tag);
    }
  }
}

final cameraControllerProvider =
    AsyncNotifierProvider<CameraControllerNotifier, CameraController?>(
  CameraControllerNotifier.new,
);
```

## 2. Cara Capture Single Frame Saat Shutter Selesai

Package `camera` gak punya cara langsung "ambil 1 CameraImage sekarang juga" — biasanya kamu `startImageStream()` untuk terus-terusan dapat frame, lalu **stop setelah dapat 1 frame** yang kamu mau. Ini kita bungkus jadi helper method:

```dart
// lib/features/ai_training/ml/inference/frame_capture_helper.dart
import 'dart:async';
import 'package:camera/camera.dart';
import '../../../../core/utils/app_logger.dart';

class FrameCaptureHelper {
  static const _tag = 'FRAME_CAPTURE';

  /// Ambil SATU frame dari camera stream, lalu langsung stop stream-nya.
  /// Dipakai sekali per shutter trigger, bukan continuous.
  static Future<CameraImage> captureSingleFrame(CameraController controller) async {
    final completer = Completer<CameraImage>();
    bool frameReceived = false;

    AppLogger.i('Memulai image stream untuk capture 1 frame...', tag: _tag);

    await controller.startImageStream((CameraImage image) {
      if (!frameReceived) {
        frameReceived = true;
        AppLogger.i('Frame diterima: ${image.width}x${image.height}', tag: _tag);
        completer.complete(image);

        // Stop stream segera setelah dapat 1 frame
        controller.stopImageStream().then((_) {
          AppLogger.i('Image stream dihentikan', tag: _tag);
        }).catchError((error) {
          AppLogger.e('Gagal menghentikan image stream', error: error, tag: _tag);
        });
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        AppLogger.e('Timeout: tidak ada frame diterima dalam 5 detik', tag: _tag);
        controller.stopImageStream();
        throw Exception('Gagal mengambil frame dari kamera (timeout)');
      },
    );
  }
}
```

## 3. Update `AiTrainingNotifier` — Integrasi Penuh

Sekarang gabungkan semua: camera capture → preprocessing → inference.

```dart
// lib/features/ai_training/logic/ai_training_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/services/providers.dart';
import '../../auth/logic/auth_provider.dart';
import '../data/repositories/battery_repository.dart';
import '../ml/inference/inference_isolate.dart';
import '../ml/inference/inference_engine.dart';
import '../ml/inference/frame_capture_helper.dart';
import '../ml/model/tflite_model_loader.dart';
import 'camera_controller_provider.dart';

const _tag = 'AI_TRAINING';

enum DetectionState { idle, countdown, processing, result }

class AiTrainingState {
  final DetectionState detectionState;
  final int countdownValue;
  final DetectionResult? lastResult;
  final bool isCorrect;

  AiTrainingState({
    this.detectionState = DetectionState.idle,
    this.countdownValue = 0,
    this.lastResult,
    this.isCorrect = false,
  });

  AiTrainingState copyWith({
    DetectionState? detectionState,
    int? countdownValue,
    DetectionResult? lastResult,
    bool? isCorrect,
  }) {
    return AiTrainingState(
      detectionState: detectionState ?? this.detectionState,
      countdownValue: countdownValue ?? this.countdownValue,
      lastResult: lastResult ?? this.lastResult,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}

class AiTrainingNotifier extends Notifier<AiTrainingState> {
  Timer? _timer;
  static const int _shutterDuration = 4;

  @override
  AiTrainingState build() {
    ref.onDispose(() => _timer?.cancel());
    return AiTrainingState();
  }

  Future<bool> startSession() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) {
      AppLogger.w('startSession gagal: profile null', tag: _tag);
      return false;
    }

    if (profile.battery < 2) {
      AppLogger.w('Baterai tidak cukup: ${profile.battery}', tag: _tag);
      return false;
    }

    await ref.read(batteryRepositoryProvider).consumeBattery(profile.uid, 2);
    ref.invalidate(userProfileProvider);
    AppLogger.s('Sesi dimulai, baterai dipotong 2 poin', tag: _tag);
    return true;
  }

  void startShutterTimer({
    required String expectedLabel,
    required ModelCategory category,
  }) {
    if (state.detectionState != DetectionState.idle) return;

    AppLogger.i('Shutter timer dimulai untuk label: $expectedLabel', tag: _tag);

    state = state.copyWith(
      detectionState: DetectionState.countdown,
      countdownValue: _shutterDuration,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.countdownValue - 1;
      if (remaining <= 0) {
        timer.cancel();
        _captureAndDetect(expectedLabel: expectedLabel, category: category);
      } else {
        state = state.copyWith(countdownValue: remaining);
      }
    });
  }

  Future<void> _captureAndDetect({
    required String expectedLabel,
    required ModelCategory category,
  }) async {
    state = state.copyWith(detectionState: DetectionState.processing);

    try {
      final cameraController = ref.read(cameraControllerProvider).value;
      if (cameraController == null || !cameraController.value.isInitialized) {
        throw Exception('Kamera belum siap');
      }

      // 1. Capture 1 frame
      final frame = await FrameCaptureHelper.captureSingleFrame(cameraController);

      // 2. Preprocessing (isolate) + inference
      final result = await InferenceService.detectFromCameraImage(
        cameraImage: frame,
        category: category,
      );

      final isCorrect = result != null &&
          result.label.toLowerCase() == expectedLabel.toLowerCase();

      AppLogger.i(
        'Hasil: ${result?.label ?? "tidak terdeteksi"} | expected: $expectedLabel | correct: $isCorrect',
        tag: _tag,
      );

      state = state.copyWith(
        detectionState: DetectionState.result,
        lastResult: result,
        isCorrect: isCorrect,
      );
    } catch (error, stackTrace) {
      AppLogger.e('Gagal capture & deteksi', error: error, stackTrace: stackTrace, tag: _tag);
      // Balik ke idle supaya user bisa coba lagi, bukan stuck di processing
      state = state.copyWith(detectionState: DetectionState.idle);
    }
  }

  void reset() {
    _timer?.cancel();
    state = AiTrainingState();
    AppLogger.i('State direset ke idle', tag: _tag);
  }
}

final aiTrainingProvider = NotifierProvider<AiTrainingNotifier, AiTrainingState>(
  AiTrainingNotifier.new,
);
```

> **Catatan**: `DetectionResult` sekarang dipakai langsung dari `inference_engine.dart` (bukan class custom terpisah seperti sebelumnya), dan aku tambahkan field `isCorrect` di state supaya popup bisa langsung tau tanpa perlu re-compare lagi.

## 4. Update UI — Pasang `CameraPreview` Asli

```dart
// lib/features/ai_training/presentation/screens/ai_training_screen.dart
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/module_model.dart' show MaterialItem;
import '../../logic/ai_training_provider.dart';
import '../../logic/camera_controller_provider.dart';
import '../../ml/model/tflite_model_loader.dart';

class AiTrainingScreen extends ConsumerStatefulWidget {
  final String moduleId;
  final List<MaterialItem> materials;
  final ModelCategory category;

  const AiTrainingScreen({
    super.key,
    required this.moduleId,
    required this.materials,
    required this.category,
  });

  @override
  ConsumerState<AiTrainingScreen> createState() => _AiTrainingScreenState();
}

class _AiTrainingScreenState extends ConsumerState<AiTrainingScreen> {
  int _currentIndex = 0;
  bool _sessionReady = false;
  bool _insufficientBattery = false;

  MaterialItem get currentMaterial => widget.materials[_currentIndex];
  bool get isLastMaterial => _currentIndex >= widget.materials.length - 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Init kamera dulu
    await ref.read(cameraControllerProvider.notifier).initialize();

    // Baru potong baterai & mulai sesi
    final success = await ref.read(aiTrainingProvider.notifier).startSession();
    if (mounted) {
      setState(() {
        _sessionReady = success;
        _insufficientBattery = !success;
      });
    }
  }

  @override
  void dispose() {
    ref.read(cameraControllerProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_insufficientBattery) {
      return _buildInsufficientBattery();
    }
    if (!_sessionReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final state = ref.watch(aiTrainingProvider);
    final notifier = ref.read(aiTrainingProvider.notifier);
    final cameraAsync = ref.watch(cameraControllerProvider);

    ref.listen(aiTrainingProvider, (previous, next) {
      if (next.detectionState == DetectionState.result) {
        _showResultDialog(context, next, notifier);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Peragakan: ${currentMaterial.label}')),
      body: Stack(
        children: [
          Positioned.fill(
            child: cameraAsync.when(
              data: (controller) {
                if (controller == null || !controller.value.isInitialized) {
                  return const ColoredBox(color: Colors.black87);
                }
                return CameraPreview(controller);
              },
              loading: () => const ColoredBox(
                color: Colors.black87,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
              error: (err, stack) => ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Text('Gagal membuka kamera: $err',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: _borderColorFor(state.detectionState), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: state.detectionState == DetectionState.processing
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : null,
            ),
          ),

          if (state.detectionState == DetectionState.countdown)
            Center(
              child: Text(
                '${state.countdownValue}',
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 12, color: Colors.black)],
                ),
              ),
            ),

          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _instructionText(state.detectionState),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          if (state.detectionState == DetectionState.idle)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => notifier.startShutterTimer(
                    expectedLabel: currentMaterial.label,
                    category: widget.category,
                  ),
                  icon: const Icon(Icons.camera),
                  label: const Text('Mulai (4 detik)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsufficientBattery() {
    return Scaffold(
      appBar: AppBar(title: const Text('Latihan Kamera')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.battery_alert, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('Baterai tidak cukup untuk memulai sesi latihan'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/subscription'),
              child: const Text('Upgrade untuk Baterai Lebih Banyak'),
            ),
          ],
        ),
      ),
    );
  }

  String _instructionText(DetectionState state) {
    switch (state) {
      case DetectionState.idle:
        return 'Posisikan tanganmu di dalam kotak, lalu klik mulai';
      case DetectionState.countdown:
        return 'Bersiap...';
      case DetectionState.processing:
        return 'Menganalisa...';
      case DetectionState.result:
        return '';
    }
  }

  Color _borderColorFor(DetectionState state) {
    switch (state) {
      case DetectionState.idle:
        return Colors.white54;
      case DetectionState.countdown:
        return Colors.orange;
      case DetectionState.processing:
        return Colors.blue;
      case DetectionState.result:
        return Colors.green;
    }
  }

  void _showResultDialog(
    BuildContext context,
    AiTrainingState state,
    AiTrainingNotifier notifier,
  ) {
    final result = state.lastResult;
    final isCorrect = state.isCorrect;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          isCorrect ? Icons.check_circle : Icons.cancel,
          color: isCorrect ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(isCorrect ? 'Benar!' : 'Coba Lagi'),
        content: Text(
          result == null
              ? 'Gestur tidak terdeteksi, coba lagi dengan pencahayaan lebih baik'
              : isCorrect
                  ? 'Jawabannya adalah "${result.label}"'
                  : 'Terdeteksi sebagai "${result.label}", bukan "${currentMaterial.label}"',
        ),
        actions: [
          if (!isCorrect)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                notifier.reset();
              },
              child: const Text('Coba Lagi'),
            ),
          if (isCorrect)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                notifier.reset();
                if (isLastMaterial) {
                  Navigator.of(context).pop(); // modul selesai, balik ke ModuleDetailScreen
                  // TODO: trigger completeModule
                } else {
                  setState(() => _currentIndex++);
                }
              },
              child: Text(isLastMaterial ? 'Selesai' : 'Lanjut'),
            ),
        ],
      ),
    );
  }
}
```

## Yang Perlu Kamu Tambahkan ke `pubspec.yaml`

```yaml
dependencies:
  camera: ^0.11.0+2  # sudah kita masukkan di awal, pastikan versinya sesuai
```

## Permission — Wajib Ditambahkan

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Tutur.id requires camera access for BISINDO gesture practice.</string>
```

## Yang Perlu Kamu Perhatikan Saat Testing Nanti

1. **Permission runtime** — kode di atas belum handle request permission secara eksplisit di UI (Android/iOS modern butuh runtime permission, bukan cuma manifest declaration). Kalau `controller.initialize()` gagal karena permission, perlu ditambahkan package `permission_handler` atau pakai mekanisme built-in dari `camera` package. Mau aku tambahkan sekarang atau tunggu ketemu errornya dulu pas testing?

2. **Rotasi frame** — seperti dicatat sebelumnya, `ImagePreprocessor` belum handle rotasi. Kalau hasil deteksi meleset terus padahal gestur sudah benar, kemungkinan besar ini penyebabnya.

3. **`ResolutionPreset.medium`** — aku pilih ini (bukan `high`/`max`) supaya frame yang di-capture gak terlalu besar (lebih cepat diproses saat resize ke 320x320, dan lebih hemat memori). Bisa disesuaikan kalau ternyata deteksi kurang akurat karena resolusi terlalu rendah.

Mau lanjut handle **permission request** dulu, atau langsung coba jalankan ini di HP fisik kamu buat lihat sejauh mana errornya (biar kita debug berdasarkan error nyata daripada nebak-nebak semua kemungkinan sekarang)?
