// handling parsing output

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/ai_training/ml/model/tflite_model_loader.dart';

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

    // reshape list float 32 byte sesuai shape model
    final input = inputData.reshape([1, 320, 320, 3]);

    // setup var buat output buffer
    // Index 337 -> boxes [1, 10, 4]
    // Index 338 -> classes [1, 10]
    // Index 339 -> scores [1, 10]
    // Index 340 -> num_detections [1]

    final outputBoxes = List.generate(
      1,
      (_) => List.generate(10, (_) => List.filled(4, 0.0)),
    );
    final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
    final outputCount = List.filled(1, 0.0);

    // setup map sesuai index dari model harus sesuai dari index tensor asli via interpreter.getOutputTensors()
    final outputs = <int, Object>{
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    };

    try {
      interpreter.runForMultipleInputs([input], outputs);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Inference gagal dijalankan',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return null;
    }

    stopwatch.stop();

    final scores = outputScores[0];
    final classes = outputClasses[0];
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

    // cari deteksi dengan confidence tertinggi
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
