import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';

const _tag = "CAMERA";

// list kamera yang tersedia entah depan atau belakang
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((
  ref,
) async {
  try {
    final cameras = await availableCameras();
    AppLogger.i('Ditemukan ${cameras.length} kamera', tag: _tag);

    for (final cam in cameras) {
      AppLogger.i('- ${cam.name} (${cam.lensDirection})', tag: _tag);
    }

    return cameras;
  } catch (error, stackTrace) {
    AppLogger.e(
      'Gagal mengambil daftar kamera',
      error: error,
      stackTrace: stackTrace,
      tag: _tag,
    );
    return [];
  }
});

class CameraControllerNotifier extends AsyncNotifier<CameraController?> {
  @override
  Future<CameraController?> build() async {
    ref.onDispose(() {
      state.value?.dispose();
      AppLogger.i('CameraController di-dispose', tag: _tag);
    });
    return null;
  }

  Future<void> initialize({
    CameraLensDirection direction = CameraLensDirection.back,
  }) async {
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

      AppLogger.i('Inisialisasi kamera: ${selectedCamera.name}', tag: _tag);

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset
            .medium, // cukup untuk 320x320 input model, hemat resource
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

    final newDirection =
        current.description.lensDirection == CameraLensDirection.back
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
