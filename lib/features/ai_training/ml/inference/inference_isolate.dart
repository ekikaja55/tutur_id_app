import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/ai_training/ml/inference/inference_engine.dart';
import 'package:tutur_id_app/features/ai_training/ml/model/tflite_model_loader.dart';
import 'package:tutur_id_app/features/ai_training/ml/preprocessing/image_preprocessor.dart';
import 'package:tutur_id_app/shared/enums/model_category.dart';

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

    // Preprocessing dilakukan di compute() - jalan di isolate terpisah
    final preprocessStopwatch = Stopwatch()..start();
    final inputData = await compute(_preprocessInIsolate, cameraImage);
    preprocessStopwatch.stop();
    AppLogger.i(
      'Preprocessing selesai (${preprocessStopwatch.elapsedMilliseconds}ms) - dijalankan di isolate',
      tag: _tag,
    );

    // Load model (sudah di-cache, jadi cepat kalau sudah pernah load)
    final model = await TFLiteModelLoader.load(category);

    // NOTE: inference TFLite interpreter TIDAK BISA dijalankan di compute()
    // biasa karena Interpreter object gak bisa di-pass lintas isolate.
    // Untuk saat ini di jalankan di main isolate tapi SETELAH preprocessing
    // berat sudah selesai di isolate terpisah - ini mengurangi beban signifikan
    // karena preprocessing (resize, YUV->RGB conversion) adalah bagian TERBERAT.
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
