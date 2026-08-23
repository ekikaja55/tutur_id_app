import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';

const _tag = 'PROFILE';

class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile({String? username, String? phoneNumber}) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) {
      AppLogger.e("Data profile null ", tag: _tag);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = <String, dynamic>{};
      if (username != null) {
        data['username'] = username.trim().isEmpty ? null : username.trim();
      }

      if (phoneNumber != null) {
        data['phoneNumber'] = phoneNumber.trim().isEmpty
            ? null
            : phoneNumber.trim();
      }

      if (data.isEmpty) return;

      await ref
          .read(authRepositoryProvider)
          .updateUserProfile(profile.uid, data);
      AppLogger.s("Profil berhasil diperbarui ", tag: _tag);
    });
    ref.invalidate(userProfileProvider);
  }

  Future<void> updatePhoto(File imageFile) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) {
      AppLogger.e("Data profile null", tag: _tag);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final cloudinaryService = ref.read(cloudinaryServiceProvider);
      final photoUrl = await cloudinaryService.uploadImage(
        imageFile,
        folder: 'tutur_id/profile_photos',
      );

      await ref.read(authRepositoryProvider).updateUserProfile(profile.uid, {
        'photoUrl': photoUrl,
      });

      AppLogger.s("Foto profil berhasil diupdate", tag: _tag);
    });
    ref.invalidate(userProfileProvider);
  }
}

final profileNotifierProvider = AsyncNotifierProvider<ProfileNotifier, void>(
  ProfileNotifier.new,
);
