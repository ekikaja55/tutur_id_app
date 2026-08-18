import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/ai_training/ml/model/label_loader.dart';
import 'package:tutur_id_app/shared/enums/model_category.dart';

class LoadedModel {
  final Interpreter interpreter;
  final List<String> labels;

  LoadedModel({required this.interpreter, required this.labels});
}

class TFLiteModelLoader {
  static const String _tag = 'TFLITE_LOADER';
  // var buat nampung caching biar ga di load berkali kali
  static final Map<ModelCategory, LoadedModel> _cache = {};

  static const Map<ModelCategory, String> _modelPaths = {
    ModelCategory.alphabet: '',
    ModelCategory.number: '',
    ModelCategory.words: '',
  };

  static const Map<ModelCategory, String> _labelPaths = {
    ModelCategory.alphabet: '',
    ModelCategory.number: '',
    ModelCategory.words: '',
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
      // XNNPACK delegate otomatis dipakai tflite_flutter di banyak platform,
      // tapi bisa eksplisit ditambahkan kalau perlu tuning lebih lanjut nanti.

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

      // log tensor
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

  static void disposeAll() {
    for (final model in _cache.values) {
      model.interpreter.close();
    }
    _cache.clear();
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
}
