// enum pilihan state deteksi
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/ai_training/data/repositories/battery_repository.dart';
import 'package:tutur_id_app/features/ai_training/logic/camera_controller_provider.dart';
import 'package:tutur_id_app/features/ai_training/ml/inference/inference_capture_helper.dart';
import 'package:tutur_id_app/features/ai_training/ml/inference/inference_engine.dart';
import 'package:tutur_id_app/features/ai_training/ml/inference/inference_isolate.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/gamification/logic/gamification_provider.dart';
import 'package:tutur_id_app/shared/enums/model_category.dart';
import 'package:tutur_id_app/shared/enums/quest_type.dart';
import 'package:tutur_id_app/shared/enums/xp_source.dart';

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

    await ref
        .read(batteryRepositoryProvider)
        .consumeBattery(userId: profile.uid, amount: 2);
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
      final frame = await FrameCaptureHelper.captureSingleFrame(
        cameraController,
      );

      // 2. Preprocessing (isolate) + inference
      final result = await InferenceService.detectFromCameraImage(
        cameraImage: frame,
        category: category,
      );

      final isCorrect =
          result != null &&
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
      AppLogger.e(
        'Gagal capture & deteksi',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      // Balik ke idle supaya user bisa coba lagi, bukan stuck di processing
      state = state.copyWith(detectionState: DetectionState.idle);
    }
  }

  void reset() {
    _timer?.cancel();
    state = AiTrainingState();
    AppLogger.i('State direset ke idle', tag: _tag);
  }

  Future<void> completeSession() async {
    await ref
        .read(gamificationNotifierProvider.notifier)
        .addXp(amount: 50, source: XpSource.aiSession);
    await ref
        .read(gamificationNotifierProvider.notifier)
        .updateQuestProgress(QuestType.persistentLearner);
  }
}

final aiTrainingProvider =
    NotifierProvider<AiTrainingNotifier, AiTrainingState>(
      AiTrainingNotifier.new,
    );
