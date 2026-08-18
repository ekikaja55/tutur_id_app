Noted soal `AppLogger` — aku pasang logging di titik-titik kritis, terutama buat validasi urutan tensor yang aku singgung tadi.

## 1. Update `tflite_model_loader.dart` — Log Saat Model Dimuat

```dart
// lib/features/ai_training/ml/model/tflite_model_loader.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'label_loader.dart';
import '../../../../core/utils/app_logger.dart';

enum ModelCategory { alphabet, number, words }

class LoadedModel {
  final Interpreter interpreter;
  final List<String> labels;

  LoadedModel({required this.interpreter, required this.labels});
}

class TFLiteModelLoader {
  static const String _tag = 'TFLITE_LOADER';
  static final Map<ModelCategory, LoadedModel> _cache = {};

  static const Map<ModelCategory, String> _modelPaths = {
    ModelCategory.alphabet: 'assets/models/alphabet_model.tflite',
    ModelCategory.number: 'assets/models/number_model.tflite',
    ModelCategory.words: 'assets/models/words_model.tflite',
  };

  static const Map<ModelCategory, String> _labelPaths = {
    ModelCategory.alphabet: 'assets/models/alphabet_classes.txt',
    ModelCategory.number: 'assets/models/number_classes.txt',
    ModelCategory.words: 'assets/models/words_classes.txt',
  };

  static Future<LoadedModel> load(ModelCategory category) async {
    if (_cache.containsKey(category)) {
      AppLogger.i('Model ${category.name} diambil dari cache', tag: _tag);
      return _cache[category]!;
    }

    AppLogger.i('Memuat model ${category.name} dari asset...', tag: _tag);
    final stopwatch = Stopwatch()..start();

    try {
      final options = InterpreterOptions()..threads = 2;

      final interpreter = await Interpreter.fromAsset(
        _modelPaths[category]!,
        options: options,
      );

      final labels = await LabelLoader.loadLabels(_labelPaths[category]!);

      stopwatch.stop();
      AppLogger.s(
        'Model ${category.name} berhasil dimuat (${stopwatch.elapsedMilliseconds}ms), ${labels.length} label',
        tag: _tag,
      );

      // === LOG PENTING: urutan & shape tensor asli dari Dart interpreter ===
      _logTensorInfo(interpreter, category);

      final loaded = LoadedModel(interpreter: interpreter, labels: labels);
      _cache[category] = loaded;
      return loaded;
    } catch (error, stackTrace) {
      AppLogger.e(
        'Gagal memuat model ${category.name}',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      rethrow;
    }
  }

  static void _logTensorInfo(Interpreter interpreter, ModelCategory category) {
    AppLogger.i('=== TENSOR INFO: ${category.name} ===', tag: _tag);

    final inputTensors = interpreter.getInputTensors();
    for (int i = 0; i < inputTensors.length; i++) {
      final t = inputTensors[i];
      AppLogger.i(
        'Input[$i] name=${t.name} shape=${t.shape} type=${t.type}',
        tag: _tag,
      );
    }

    final outputTensors = interpreter.getOutputTensors();
    for (int i = 0; i < outputTensors.length; i++) {
      final t = outputTensors[i];
      AppLogger.i(
        'Output[$i] name=${t.name} shape=${t.shape} type=${t.type}',
        tag: _tag,
      );
    }

    AppLogger.w(
      'Cocokkan urutan Output[i] di atas dengan urutan di InferenceEngine.runInference() '
      '— urutan Dart bisa BEDA dari urutan index Python (337/338/339/340)!',
      tag: _tag,
    );
  }

  static void disposeAll() {
    for (final model in _cache.values) {
      model.interpreter.close();
    }
    _cache.clear();
    AppLogger.i('Semua model TFLite di-dispose', tag: _tag);
  }
}
```

## 2. Update `inference_engine.dart` — Log Hasil Tiap Inference

```dart
// lib/features/ai_training/ml/inference/inference_engine.dart
import 'dart:typed_data';
import '../model/tflite_model_loader.dart';
import '../../../../core/utils/app_logger.dart';

class DetectionResult {
  final String label;
  final double confidence;

  DetectionResult({required this.label, required this.confidence});
}

class InferenceEngine {
  static const String _tag = 'INFERENCE';
  static const double confidenceThreshold = 0.40;

  static DetectionResult? runInference(
    LoadedModel model,
    Float32List inputData,
  ) {
    final stopwatch = Stopwatch()..start();
    final interpreter = model.interpreter;

    final input = inputData.reshape([1, 320, 320, 3]);

    final outputBoxes = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
    final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
    final outputCount = List.filled(1, 0.0);

    final outputs = <int, Object>{
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    };

    try {
      interpreter.runForMultipleInputs([input], outputs);
    } catch (error, stackTrace) {
      AppLogger.e('Inference gagal dijalankan', error: error, stackTrace: stackTrace, tag: _tag);
      return null;
    }

    stopwatch.stop();

    final scores = outputScores[0];
    final classes = outputClasses[0];

    // === LOG PENTING: raw output, buat validasi urutan tensor ===
    AppLogger.i(
      'Raw scores: ${scores.map((s) => s.toStringAsFixed(3)).toList()}',
      tag: _tag,
    );
    AppLogger.i(
      'Raw classes: ${classes.map((c) => c.toInt()).toList()}',
      tag: _tag,
    );
    AppLogger.i(
      'Latency inference: ${stopwatch.elapsedMilliseconds}ms',
      tag: _tag,
    );

    double bestScore = 0;
    int bestClassIndex = -1;

    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestClassIndex = classes[i].toInt();
      }
    }

    if (bestScore < confidenceThreshold) {
      AppLogger.w(
        'Confidence tertinggi ($bestScore) di bawah threshold ($confidenceThreshold) — tidak ada deteksi valid',
        tag: _tag,
      );
      return null;
    }

    if (bestClassIndex < 0 || bestClassIndex >= model.labels.length) {
      AppLogger.e(
        'classIndex ($bestClassIndex) di luar jangkauan labels (${model.labels.length}) '
        '— kemungkinan urutan output tensor SALAH, cek log TENSOR INFO saat model load',
        tag: _tag,
      );
      return null;
    }

    final label = model.labels[bestClassIndex];
    AppLogger.s(
      'Deteksi terbaik: "$label" (confidence: ${(bestScore * 100).toStringAsFixed(2)}%)',
      tag: _tag,
    );

    return DetectionResult(label: label, confidence: bestScore);
  }
}
```

## 3. Update `inference_isolate.dart` — Log Alur Preprocessing

```dart
// lib/features/ai_training/ml/inference/inference_isolate.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'inference_engine.dart';
import '../model/tflite_model_loader.dart';
import '../preprocessing/image_preprocessor.dart';
import '../../../../core/utils/app_logger.dart';

class InferenceService {
  static const String _tag = 'INFERENCE_SERVICE';

  static Future<DetectionResult?> detectFromCameraImage({
    required CameraImage cameraImage,
    required ModelCategory category,
  }) async {
    AppLogger.i(
      'Mulai deteksi | kategori: ${category.name} | frame: ${cameraImage.width}x${cameraImage.height}',
      tag: _tag,
    );

    final totalStopwatch = Stopwatch()..start();

    // Preprocessing di isolate terpisah
    final preprocessStopwatch = Stopwatch()..start();
    final inputData = await compute(_preprocessInIsolate, cameraImage);
    preprocessStopwatch.stop();
    AppLogger.i(
      'Preprocessing selesai (${preprocessStopwatch.elapsedMilliseconds}ms) - dijalankan di isolate',
      tag: _tag,
    );

    final model = await TFLiteModelLoader.load(category);

    final result = InferenceEngine.runInference(model, inputData);

    totalStopwatch.stop();
    AppLogger.i(
      'Total waktu deteksi (preprocessing + inference): ${totalStopwatch.elapsedMilliseconds}ms',
      tag: _tag,
    );

    if (result == null) {
      AppLogger.w('Tidak ada hasil deteksi yang valid', tag: _tag);
    }

    return result;
  }

  static Float32List _preprocessInIsolate(CameraImage cameraImage) {
    return ImagePreprocessor.preprocess(cameraImage);
  }
}
```

## Kenapa Logging Ini Penting Buat Kamu Sekarang

Saat kamu testing pertama kali di HP fisik, urutan log yang bakal muncul di console kira-kira begini:

```
[INFO][TFLITE_LOADER] Memuat model alphabet dari asset...
[SUCCESS][TFLITE_LOADER] Model alphabet berhasil dimuat (842ms), 26 label
[INFO][TFLITE_LOADER] === TENSOR INFO: alphabet ===
[INFO][TFLITE_LOADER] Input[0] name=serving_default_input:0 shape=[1, 320, 320, 3] type=float32
[INFO][TFLITE_LOADER] Output[0] name=StatefulPartitionedCall:0 shape=[1] type=float32
[INFO][TFLITE_LOADER] Output[1] name=StatefulPartitionedCall:1 shape=[1, 10] type=float32
[INFO][TFLITE_LOADER] Output[2] name=StatefulPartitionedCall:2 shape=[1, 10] type=float32
[INFO][TFLITE_LOADER] Output[3] name=StatefulPartitionedCall:3 shape=[1, 10, 4] type=float32
[WARNING][TFLITE_LOADER] Cocokkan urutan Output[i] di atas dengan urutan di InferenceEngine...
```

**Di sinilah kamu langsung tau kalau urutan `outputs` map di `inference_engine.dart` salah.** Bandingkan `shape` tiap `Output[i]` yang muncul di log dengan yang kamu hardcode:

- Kalau `Output[0]` shape-nya `[1]` (bukan `[1,10,4]`), berarti urutan sebenarnya adalah **num_detections dulu**, bukan **boxes** — dan kamu harus swap urutan di map `outputs` di `inference_engine.dart` supaya sesuai.

Begitu juga log inference (`Raw scores`, `Raw classes`) bakal langsung kelihatan kalau nilai-nilainya masuk akal (misal ada 1 nilai tinggi ~0.9x dan sisanya rendah) atau malah semua 0/aneh (tanda ada yang salah mapping).

## Update Kecil: `catch` Kurang Precise Sebelumnya

Aku juga sekalian benerin — sebelumnya kalau `runForMultipleInputs` throw error, itu bakal crash tanpa informasi jelas. Sekarang sudah dibungkus `try-catch` dengan log error lengkap (`stackTrace` termasuk), biar gampang di-debug kalau ada crash native dari TFLite interpreter.

Siap lanjut ke setup `CameraController` + integrasi penuh ke `AiTrainingNotifier`?
