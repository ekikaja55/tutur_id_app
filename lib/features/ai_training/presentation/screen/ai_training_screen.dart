import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/ai_training/logic/ai_training_provider.dart';
import 'package:tutur_id_app/features/ai_training/logic/camera_controller_provider.dart';
import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/shared/enums/model_category.dart';

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
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              error: (err, stack) => ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Text(
                    'Gagal membuka kamera: $err',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _borderColorFor(state.detectionState),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: state.detectionState == DetectionState.processing
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
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
                  Navigator.of(context).pop();
                  ref
                      .read(aiTrainingProvider.notifier)
                      .completeSession();
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
