Oke, lanjut ke **`features/profile/`** — Manage Profile (edit data, lihat saldo baterai, riwayat aktivitas).

## 1. Repository

Karena kebanyakan operasi CRUD profile udah kepegang oleh `AuthRepository` (`updateUserProfile`, `getUserProfile`), fitur ini **gak butuh repository baru** — cukup reuse yang sudah ada. Ini konsisten sama prinsip kita: gak bikin duplikasi kalau udah ada yang bisa dipakai ulang.

## 2. Provider

### `features/profile/logic/profile_provider.dart`

```dart
// lib/features/profile/logic/profile_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/logic/auth_provider.dart';

const _tag = 'PROFILE';

class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile({
    String? username,
    String? phoneNumber,
  }) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final data = <String, dynamic>{};
      if (username != null && username.trim().isNotEmpty) {
        data['username'] = username.trim();
      }
      if (phoneNumber != null) {
        data['phoneNumber'] = phoneNumber.trim().isEmpty ? null : phoneNumber.trim();
      }

      if (data.isEmpty) return;

      await ref.read(authRepositoryProvider).updateUserProfile(profile.uid, data);
      AppLogger.s('Profil berhasil diperbarui', tag: _tag);
    });

    ref.invalidate(userProfileProvider);
  }

  Future<void> updatePhoto(File imageFile) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

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
      AppLogger.s('Foto profil berhasil diupdate', tag: _tag);
    });

    ref.invalidate(userProfileProvider);
  }
}

final profileNotifierProvider = AsyncNotifierProvider<ProfileNotifier, void>(
  ProfileNotifier.new,
);
```

## 3. Screen: Profile

### `features/profile/presentation/screens/profile_screen.dart`

```dart
// lib/features/profile/presentation/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../gamification/logic/gamification_provider.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profil tidak ditemukan'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage:
                          profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                      child: profile.photoUrl == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile.username ?? 'Belum ada nama',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Center(child: Text(profile.email, style: const TextStyle(color: Colors.grey))),
              const SizedBox(height: 24),

              _InfoCard(
                icon: Icons.battery_full,
                label: 'Baterai',
                value: '${profile.battery}',
              ),
              _InfoCard(
                icon: Icons.workspace_premium,
                label: 'Paket Langganan',
                value: profile.subscriptionTier.name.toUpperCase(),
              ),
              _InfoCard(
                icon: Icons.star,
                label: 'Total XP',
                value: '${profile.xp}',
              ),
              _InfoCard(
                icon: Icons.local_fire_department,
                label: 'Streak Belajar',
                value: '${profile.streak} hari',
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
                icon: const Icon(Icons.edit),
                label: const Text('Edit Profil'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
```

## 4. Screen: Edit Profile

```dart
// lib/features/profile/presentation/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../logic/profile_provider.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan: $error')),
          );
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
          if (profile == null) return const Center(child: Text('Profil tidak ditemukan'));

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
                                    : null) as ImageProvider?,
                            child: _selectedImage == null && profile.photoUrl == null
                                ? const Icon(Icons.person, size: 48)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage != null) {
      await ref.read(profileNotifierProvider.notifier).updatePhoto(_selectedImage!);
    }

    await ref.read(profileNotifierProvider.notifier).updateProfile(
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
```

## Update `pubspec.yaml` — Tambah `image_picker`

```yaml
dependencies:
  image_picker: ^1.1.2
```

## Permission Tambahan

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Tutur.id membutuhkan akses galeri untuk mengganti foto profil</string>
```

Android biasanya gak butuh permission tambahan untuk `image_picker` versi modern (pakai scoped storage), tapi kalau muncul masalah nanti, kita cek bareng saat testing.

## Menutup "Utang" Foto Profil Onboarding

Ingat di awal kita skip foto profil upload waktu bikin `OnboardingScreen` (masih ada komentar `// TODO`)? Sekarang karena `ProfileNotifier.updatePhoto()` udah ada, sebenarnya **gak perlu** buat ulang logic serupa di onboarding — cukup update `TODO.txt` biar jelas foto profil di onboarding **tetap ditunda** ke fase polish (user bisa upload foto lewat halaman **Edit Profile** yang baru kita buat ini, jadi fungsionalitasnya udah tersedia, cuma belum terintegrasi di alur onboarding awal).

## Update `router.dart`

Route `/profile` udah terdaftar dari awal (di `_sharedPrefixes`), jadi gak perlu perubahan tambahan — `ProfileScreen` bisa diakses baik `student` maupun `admin`.

## Update `TODO.txt`

```
[FITUR: PROFILE]
[x] Screen manage profile (edit data kecuali email)
[x] Provider: profileProvider (update data + foto)
[x] Tampilkan sisa saldo baterai, XP, streak
[ ] Riwayat aktivitas belajar - PENDING, butuh agregasi data dari xp_logs & user_progress

[POLISH & DESIGN]
[ ] Upload foto profil saat onboarding - SKIP, sudah tercover lewat Edit Profile
```

## Catatan: "Riwayat Aktivitas Belajar" Sengaja Ditunda

Requirement awal nyebut user bisa "melihat riwayat aktivitas belajar" — ini butuh **agregasi data** dari beberapa collection (`xp_logs`, `user_progress`, `daily_quests`) buat ditampilkan sebagai timeline/history yang readable. Karena ini murni **UI tambahan tanpa logic baru** (semua data sourcenya udah ada), aku sarankan ini masuk ke fase polish nanti, biar sekarang bisa lanjut ke `features/feedback_report/` yang levelnya masih "fitur inti belum ada sama sekali".

Lanjut ke `features/feedback_report/`?
