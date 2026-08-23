import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/profile/logic/profile_provider.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  File? _selectedImage;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profileState = ref.watch(profileNotifierProvider);

    ref.listen(profileNotifierProvider, (previous, next) {
      next.whenOrNull(
        error: (error, stack) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $error')));
        },
        data: (_) {
          if (previous is AsyncLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil berhasil diperbarui')),
            );
            Navigator.of(context).pop();
          }
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil tidak ditemukan'));
          }
          if (!_initialized) {
            _usernameController = TextEditingController(text: profile.username);
            _phoneController = TextEditingController(text: profile.phoneNumber);
            _initialized = true;
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!)
                                : (profile.photoUrl != null
                                          ? NetworkImage(profile.photoUrl!)
                                          : null)
                                      as ImageProvider?,
                            child:
                                _selectedImage == null &&
                                    profile.photoUrl == null
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Username minimal 3 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (!RegExp(r'^08\d{8,11}$').hasMatch(value)) {
                        return 'Format nomor telepon tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: profileState.isLoading ? null : _saveProfile,
                    child: profileState.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Simpan'),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage != null) {
      await ref
          .read(profileNotifierProvider.notifier)
          .updatePhoto(_selectedImage!);
    }

    await ref
        .read(profileNotifierProvider.notifier)
        .updateProfile(
          username: _usernameController.text,
          phoneNumber: _phoneController.text,
        );
  }

  @override
  void dispose() {
    if (_initialized) {
      _usernameController.dispose();
      _phoneController.dispose();
    }
    super.dispose();
  }
}
