import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  late final CloudinaryPublic _cloudinary;

  CloudinaryService() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPresetName = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    if (cloudName == null || uploadPresetName == null) {
      throw Exception("cannot find cloudName or uploadPresetName");
    }
    _cloudinary = CloudinaryPublic(cloudName, uploadPresetName, cache: false);
  }

  Future<String> uploadImage(File file, {String folder = 'tutur_id'}) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
      ),
    );
    return response.secureUrl;
  }

  Future<String> uploadVideo(File file, {String folder = 'tutur_id'}) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Video,
      ),
    );
    return response.secureUrl;
  }
}
