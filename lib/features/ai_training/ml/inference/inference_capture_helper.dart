import 'dart:async';

import 'package:camera/camera.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';

class FrameCaptureHelper {
  static const _tag = 'FRAME_CAPTURE';

  /// Ambil SATU frame dari camera stream, lalu langsung stop stream-nya.
  /// Dipakai sekali per shutter trigger, bukan continuous.
  static Future<CameraImage> captureSingleFrame(
    CameraController controller,
  ) async {
    final completer = Completer<CameraImage>();
    bool frameReceived = false;

    AppLogger.i('Memulai image stream untuk capture 1 frame...', tag: _tag);

    await controller.startImageStream((CameraImage image) {
      if (!frameReceived) {
        frameReceived = true;
        AppLogger.i(
          'Frame diterima: ${image.width}x${image.height}',
          tag: _tag,
        );
        completer.complete(image);

        // Stop stream segera setelah dapat 1 frame
        controller
            .stopImageStream()
            .then((_) {
              AppLogger.i('Image stream dihentikan', tag: _tag);
            })
            .catchError((error) {
              AppLogger.e(
                'Gagal menghentikan image stream',
                error: error,
                tag: _tag,
              );
            });
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        AppLogger.e(
          'Timeout: tidak ada frame diterima dalam 5 detik',
          tag: _tag,
        );
        controller.stopImageStream();
        throw Exception('Gagal mengambil frame dari kamera (timeout)');
      },
    );
  }
}
