Oke, lanjut ke **preprocessing pipeline** — bagian yang mengubah `CameraImage` mentah jadi `Float32List` siap pakai model TFLite kamu (input shape `[1, 320, 320, 3]`, sesuai hasil test kamu).

## Konteks Penting Sebelum Mulai

Dari hasil testing Python kamu, modelmu expect:
- Input: `[1, 320, 320, 3]`, dtype `float32`, normalisasi `0_TO_1` (div 255.0)
- Karena kita sudah sepakat pakai **shutter-trigger** (bukan continuous per-frame), preprocessing ini cuma jalan **sekali per klik "Mulai"**, jadi kita punya waktu lebih longgar mengolahnya dibanding continuous stream.

## 1. `features/ai_training/ml/preprocessing/image_preprocessor.dart`

Ini bagian yang convert `CameraImage` (format YUV420 dari kamera Android) → `Float32List` RGB ternormalisasi.

```dart
// lib/features/ai_training/ml/preprocessing/image_preprocessor.dart
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const int inputSize = 320;

  /// Convert CameraImage (YUV420) ke Float32List siap pakai model TFLite
  /// Output shape: [1, 320, 320, 3], normalisasi 0.0-1.0
  static Float32List preprocess(CameraImage cameraImage) {
    // 1. Convert YUV420 -> RGB image
    final rgbImage = _convertYUV420ToImage(cameraImage);

    // 2. Resize ke 320x320
    final resized = img.copyResize(
      rgbImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // 3. Normalisasi + konversi ke Float32List
    return _imageToFloat32List(resized);
  }

  /// Konversi format kamera Android (YUV420) menjadi img.Image (RGB)
  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final image = img.Image(width: width, height: height);

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final yValue = yPlane.bytes[yIndex];
        final uValue = uPlane.bytes[uvIndex];
        final vValue = vPlane.bytes[uvIndex];

        // YUV -> RGB conversion (ITU-R BT.601)
        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  /// Normalisasi pixel (div 255.0) + susun jadi Float32List [1, 320, 320, 3]
  static Float32List _imageToFloat32List(img.Image image) {
    final buffer = Float32List(1 * inputSize * inputSize * 3);
    int bufferIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[bufferIndex++] = pixel.r / 255.0;
        buffer[bufferIndex++] = pixel.g / 255.0;
        buffer[bufferIndex++] = pixel.b / 255.0;
      }
    }

    return buffer;
  }
}
```

> **Catatan soal orientasi kamera**: kode di atas belum handle rotasi (kamera Android biasanya butuh rotasi 90°). Aku sengaja skip dulu — nanti kita tangani sesuai orientasi device pas testing di HP fisik, karena rotasi bisa beda-beda tergantung device & apakah pakai kamera depan/belakang.

## 2. `features/ai_training/ml/model/label_loader.dart`

Loader untuk `classes.txt`.

```dart
// lib/features/ai_training/ml/model/label_loader.dart
import 'package:flutter/services.dart';

class LabelLoader {
  static Future<List<String>> loadLabels(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
```

## 3. `features/ai_training/ml/model/tflite_model_loader.dart`

Ini singleton loader untuk `.tflite` — sesuai catatan kita sebelumnya, model **dimuat sekali**, bukan tiap kali masuk halaman training. Karena kamu punya **3 model berbeda** (alphabet, number, words berdasarkan hasil testing kamu), aku desain supaya bisa handle multiple model.

```dart
// lib/features/ai_training/ml/model/tflite_model_loader.dart
import 'package:tflite_flutter/tflite_flutter.dart';
import 'label_loader.dart';

enum ModelCategory { alphabet, number, words }

class LoadedModel {
  final Interpreter interpreter;
  final List<String> labels;

  LoadedModel({required this.interpreter, required this.labels});
}

class TFLiteModelLoader {
  // Cache supaya model gak di-load ulang tiap dipanggil
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
      return _cache[category]!;
    }

    final options = InterpreterOptions()..threads = 2;
    // XNNPACK delegate otomatis dipakai tflite_flutter di banyak platform,
    // tapi bisa eksplisit ditambahkan kalau perlu tuning lebih lanjut nanti.

    final interpreter = await Interpreter.fromAsset(
      _modelPaths[category]!,
      options: options,
    );

    final labels = await LabelLoader.loadLabels(_labelPaths[category]!);

    final loaded = LoadedModel(interpreter: interpreter, labels: labels);
    _cache[category] = loaded;
    return loaded;
  }

  static void disposeAll() {
    for (final model in _cache.values) {
      model.interpreter.close();
    }
    _cache.clear();
  }
}
```

> **Sesuaikan nama file asset** (`alphabet_model.tflite`, dst) dengan nama file asli dari repo Patuli-ML kamu. Kalau modelnya cuma 1 file gabungan (bukan 3 terpisah), kabari aku biar aku sesuaikan strukturnya.

## 4. Update `pubspec.yaml` — Daftarkan Asset Model

```yaml
flutter:
  assets:
    - assets/models/alphabet_model.tflite
    - assets/models/alphabet_classes.txt
    - assets/models/number_model.tflite
    - assets/models/number_classes.txt
    - assets/models/words_model.tflite
    - assets/models/words_classes.txt
```

## 5. `features/ai_training/ml/inference/inference_engine.dart`

Ini logic parsing output — berdasarkan hasil testing Python kamu, output modelmu punya **4 tensor** (khas SSD MobileNet: boxes, classes, scores, jumlah deteksi):

```dart
// lib/features/ai_training/ml/inference/inference_engine.dart
import 'dart:typed_data';
import '../model/tflite_model_loader.dart';

class DetectionResult {
  final String label;
  final double confidence;

  DetectionResult({required this.label, required this.confidence});
}

class InferenceEngine {
  static const double confidenceThreshold = 0.40; // sesuai kesepakatan kita

  /// Jalankan inference, return deteksi dengan confidence tertinggi (atau null kalau di bawah threshold)
  static DetectionResult? runInference(
    LoadedModel model,
    Float32List inputData,
  ) {
    final interpreter = model.interpreter;

    // Reshape input sesuai shape [1, 320, 320, 3]
    final input = inputData.reshape([1, 320, 320, 3]);

    // Siapkan output buffer sesuai shape dari hasil test kamu:
    // Index 337 -> boxes [1, 10, 4]
    // Index 338 -> classes [1, 10]
    // Index 339 -> scores [1, 10]
    // Index 340 -> num_detections [1]
    final outputBoxes = List.generate(1, (_) => List.generate(10, (_) => List.filled(4, 0.0)));
    final outputClasses = List.generate(1, (_) => List.filled(10, 0.0));
    final outputScores = List.generate(1, (_) => List.filled(10, 0.0));
    final outputCount = List.filled(1, 0.0);

    // Urutan output map harus sesuai index tensor asli model kamu
    final outputs = <int, Object>{
      0: outputBoxes,   // sesuaikan index sesuai urutan asli interpreter.getOutputTensors()
      1: outputClasses,
      2: outputScores,
      3: outputCount,
    };

    interpreter.runForMultipleInputs([input], outputs);

    // Cari deteksi dengan confidence tertinggi
    double bestScore = 0;
    int bestClassIndex = -1;

    final scores = outputScores[0];
    final classes = outputClasses[0];

    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > bestScore) {
        bestScore = scores[i];
        bestClassIndex = classes[i].toInt();
      }
    }

    if (bestScore < confidenceThreshold || bestClassIndex < 0 || bestClassIndex >= model.labels.length) {
      return null; // gak ada deteksi yang cukup yakin
    }

    return DetectionResult(
      label: model.labels[bestClassIndex],
      confidence: bestScore,
    );
  }
}
```

> ⚠️ **Penting**: urutan `outputs` map (index 0, 1, 2, 3) di atas **harus dicocokkan manual** dengan urutan asli dari model kamu. Dari hasil test Python kamu, urutan index tensor adalah `337, 338, 339, 340` — tapi `tflite_flutter` di Dart biasanya reindex ke `0, 1, 2, 3` berdasarkan urutan yang dikembalikan `interpreter.getOutputTensors()`, **bukan** index asli dari Python. Ini perlu divalidasi langsung waktu testing pertama kali karena bisa beda urutan antara Python interpreter dan Dart interpreter untuk model yang sama. Kalau hasil test nanti ternyata salah urutan (confidence selalu 0 atau box selalu aneh), kita debug bareng dengan print `interpreter.getOutputTensors()` buat lihat urutan aslinya di Dart.

## 6. Jalankan di Isolate — `features/ai_training/ml/inference/inference_isolate.dart`

Sesuai kesepakatan awal kita, inference **wajib** di isolate terpisah biar gak nge-freeze UI.

```dart
// lib/features/ai_training/ml/inference/inference_isolate.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'inference_engine.dart';
import '../model/tflite_model_loader.dart';
import '../preprocessing/image_preprocessor.dart';
import 'package:camera/camera.dart';

class InferenceService {
  /// Jalankan preprocessing + inference tanpa blocking UI thread
  static Future<DetectionResult?> detectFromCameraImage({
    required CameraImage cameraImage,
    required ModelCategory category,
  }) async {
    // Preprocessing dilakukan di compute() - jalan di isolate terpisah
    final inputData = await compute(_preprocessInIsolate, cameraImage);

    // Load model (sudah di-cache, jadi cepat kalau sudah pernah load)
    final model = await TFLiteModelLoader.load(category);

      // NOTE: inference TFLite interpreter TIDAK BISA dijalankan di compute()
      // biasa karena Interpreter object gak bisa di-pass lintas isolate.
      // Untuk saat ini kita jalankan di main isolate tapi SETELAH preprocessing
      // berat sudah selesai di isolate terpisah - ini mengurangi beban signifikan
      // karena preprocessing (resize, YUV->RGB conversion) adalah bagian TERBERAT.
    return InferenceEngine.runInference(model, inputData);
  }

  static Float32List _preprocessInIsolate(CameraImage cameraImage) {
    return ImagePreprocessor.preprocess(cameraImage);
  }
}
```

## ⚠️ Catatan Teknis Penting: Batasan Isolate untuk TFLite

Ini perlu aku jelasin jujur karena ini keterbatasan nyata di ekosistem `tflite_flutter`:

**`Interpreter` dari `tflite_flutter` tidak bisa di-pass langsung ke isolate lain** (karena dia wrap native pointer C++, bukan objek Dart murni yang bisa di-serialize). Jadi ada 2 opsi realistis:

1. **Preprocessing di isolate (via `compute()`), inference tetap di main isolate** — ini yang aku terapkan di atas. Karena preprocessing (resize + YUV→RGB conversion, yang paling berat secara komputasi) sudah dipindah ke isolate, sementara inference-nya sendiri (dari hasil testing kamu cuma ~65-107ms) dijalankan di main isolate tapi **cuma sekali per klik shutter**, bukan continuous — jadi dampaknya ke UI freeze jauh lebih kecil dibanding kalau semua (termasuk preprocessing) dijalankan di main thread.

2. **Pakai `Isolate.spawn()` manual dengan re-load interpreter di isolate baru tiap kali** — secara teori memungkinkan model di-load ulang di isolate terpisah, tapi ini berarti **model kena re-load tiap inference** (bukan cached), yang justru kontraproduktif sama tujuan kita (model harus di-load sekali, bukan berulang).

**Rekomendasi aku**: pakai opsi 1 dulu (yang sudah aku implementasikan), karena dengan sistem shutter-trigger yang cuma jalan sekali per klik, freeze singkat 65-107ms **sekali per klik tombol** itu jauh lebih acceptable dibanding continuous inference yang jadi masalah awal kamu. Kalau nanti setelah testing di HP fisik ternyata freeze-nya masih kerasa ganggu, kita eksplor opsi 2 atau `flutter_isolate` package (yang punya cara khusus handle native resources lintas isolate).

## Alur Lengkap Sekarang

```
User klik "Mulai"
   → shutter countdown 4 detik
   → capture 1 frame dari CameraController
   → InferenceService.detectFromCameraImage()
       → compute() [ISOLATE]: YUV->RGB, resize 320x320, normalize
       → main isolate: load model (cached), run inference (~65-107ms)
   → return DetectionResult (label + confidence)
   → cocokkan dengan expectedLabel
   → tampilkan popup hasil
```

## Yang Masih Perlu Dilengkapi

1. **Integrasi ke `AiTrainingNotifier`** — `_runInference()` yang masih dummy di kode sebelumnya perlu diganti manggil `InferenceService.detectFromCameraImage()` beneran.
2. **`CameraController` setup** — capture frame asli dari kamera belum kita buat, masih placeholder `Container(color: Colors.black87)` di UI.
3. **Konfirmasi urutan output tensor** — perlu ditest langsung di device karena seperti dicatat di atas, urutan index bisa beda antara Python dan Dart interpreter.
4. **Rotasi frame kamera** — belum dihandle di `ImagePreprocessor`.

Mau aku lanjut sekarang ke setup `CameraController` + integrasi penuh ke `AiTrainingNotifier`, atau kamu mau coba compile dulu bagian ini buat pastikan gak ada error dasar sebelum lanjut?
