import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

// belum handle rotasi biasanya android butuh rotasi 90 derajat
class ImagePreprocessor {
  static const int inputSize = 320;

  // convert CameraImage (YUV420) -> Float32List dari model
  // output shape [1,320,320,3], normalisasi 0.0-1.0
  static Float32List preprocess(CameraImage cameraImage) {
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

  // Konversi format kamera Android (YUV420) menjadi img.Image (RGB)
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
        final g =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0, 255)
                .toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  // normalisasi pixel jadi div 255.0 lalu susun jadi Float32list [1,320,320,3]
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
