Oke, lanjut ke **`features/feedback_report/`** — Report (kendala) & Feedback (ulasan), sesuai requirement: kategori, upload 2 foto bukti, tombol WhatsApp, dan star rating.

## 1. Data Models

### `features/feedback_report/data/models/report_model.dart`

```dart
// lib/features/feedback_report/data/models/report_model.dart

enum ReportCategory { aiCamera, payment, material }
enum ReportStatus { diterima, diproses, selesai }

class ReportModel {
  final String id;
  final String userId;
  final ReportCategory category;
  final String description;
  final List<String> attachmentUrls;
  final ReportStatus status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    this.attachmentUrls = const [],
    this.status = ReportStatus.diterima,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: ReportCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ReportCategory.material,
      ),
      description: json['description'] as String,
      attachmentUrls: List<String>.from(json['attachmentUrls'] as List? ?? []),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReportStatus.diterima,
      ),
      adminResponse: json['adminResponse'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category.name,
      'description': description,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'adminResponse': adminResponse,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
```

### `features/feedback_report/data/models/feedback_model.dart`

```dart
// lib/features/feedback_report/data/models/feedback_model.dart

class FeedbackModel {
  final String id;
  final String userId;
  final int rating; // 1-5
  final String description;
  final String? adminResponse;
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.userId,
    required this.rating,
    required this.description,
    this.adminResponse,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      rating: json['rating'] as int,
      description: json['description'] as String,
      adminResponse: json['adminResponse'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'rating': rating,
      'description': description,
      'adminResponse': adminResponse,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
```

## 2. Repository

```dart
// lib/features/feedback_report/data/repositories/feedback_report_repository.dart
import 'dart:io';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/report_model.dart';
import '../models/feedback_model.dart';

const _tag = 'FEEDBACK_REPORT_REPO';

class FeedbackReportRepository {
  final FirebaseService _firebaseService;
  final CloudinaryService _cloudinaryService;

  FeedbackReportRepository(this._firebaseService, this._cloudinaryService);

  // ---------- REPORT ----------

  Future<void> submitReport({
    required String userId,
    required ReportCategory category,
    required String description,
    required List<File> attachments,
  }) async {
    AppLogger.i('Mengirim report kategori ${category.name}', tag: _tag);

    // Upload maksimal 2 foto ke Cloudinary
    final urls = <String>[];
    for (final file in attachments.take(2)) {
      final url = await _cloudinaryService.uploadImage(file, folder: 'tutur_id/reports');
      urls.add(url);
    }

    final reportId = 'report_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final report = ReportModel(
      id: reportId,
      userId: userId,
      category: category,
      description: description,
      attachmentUrls: urls,
      status: ReportStatus.diterima,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firebaseService.setDocument('reports', reportId, report.toJson());
    AppLogger.s('Report berhasil dikirim: $reportId', tag: _tag);
  }

  Future<List<ReportModel>> getUserReports(String userId) async {
    final data = await _firebaseService.getCollection(
      'reports',
      queryBuilder: (query) =>
          query.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true),
    );
    return data.map((e) => ReportModel.fromJson(e)).toList();
  }

  // ---------- FEEDBACK ----------

  Future<void> submitFeedback({
    required String userId,
    required int rating,
    required String description,
  }) async {
    final feedbackId = 'feedback_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final feedback = FeedbackModel(
      id: feedbackId,
      userId: userId,
      rating: rating,
      description: description,
      createdAt: DateTime.now(),
    );

    await _firebaseService.setDocument('feedback', feedbackId, feedback.toJson());
    AppLogger.s('Feedback berhasil dikirim: $feedbackId', tag: _tag);
  }

  Future<List<FeedbackModel>> getUserFeedbacks(String userId) async {
    final data = await _firebaseService.getCollection(
      'feedback',
      queryBuilder: (query) =>
          query.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true),
    );
    return data.map((e) => FeedbackModel.fromJson(e)).toList();
  }
}
```

## 3. Provider

```dart
// lib/features/feedback_report/logic/feedback_report_provider.dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../../core/utils/app_logger.dart';
import '../../auth/logic/auth_provider.dart';
import '../data/repositories/feedback_report_repository.dart';
import '../data/models/report_model.dart';
import '../data/models/feedback_model.dart';

const _tag = 'FEEDBACK_REPORT';

final feedbackReportRepositoryProvider = Provider<FeedbackReportRepository>((ref) {
  return FeedbackReportRepository(
    ref.watch(firebaseServiceProvider),
    ref.watch(cloudinaryServiceProvider),
  );
});

final userReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(feedbackReportRepositoryProvider).getUserReports(profile.uid);
});

final userFeedbacksProvider = FutureProvider<List<FeedbackModel>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref.watch(feedbackReportRepositoryProvider).getUserFeedbacks(profile.uid);
});

class FeedbackReportNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitReport({
    required ReportCategory category,
    required String description,
    required List<File> attachments,
  }) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(feedbackReportRepositoryProvider).submitReport(
            userId: profile.uid,
            category: category,
            description: description,
            attachments: attachments,
          );
    });

    ref.invalidate(userReportsProvider);
  }

  Future<void> submitFeedback({
    required int rating,
    required String description,
  }) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(feedbackReportRepositoryProvider).submitFeedback(
            userId: profile.uid,
            rating: rating,
            description: description,
          );
    });

    ref.invalidate(userFeedbacksProvider);
  }
}

final feedbackReportNotifierProvider =
    AsyncNotifierProvider<FeedbackReportNotifier, void>(FeedbackReportNotifier.new);
```

## 4. Screen: Hub (Pilih Report atau Feedback)

```dart
// lib/features/feedback_report/presentation/screens/feedback_report_hub_screen.dart
import 'package:flutter/material.dart';
import 'report_form_screen.dart';
import 'feedback_form_screen.dart';

class FeedbackReportHubScreen extends StatelessWidget {
  const FeedbackReportHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report & Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: const Text('Laporkan Kendala'),
                subtitle: const Text('Ada masalah dengan AI kamera, pembayaran, atau materi?'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportFormScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Beri Feedback'),
                subtitle: const Text('Bagikan kesan dan saranmu untuk Tutur.id'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FeedbackFormScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 5. Screen: Report Form

```dart
// lib/features/feedback_report/presentation/screens/report_form_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/report_model.dart';
import '../../logic/feedback_report_provider.dart';

class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ReportCategory? _selectedCategory;
  final List<File> _attachments = [];

  static const _categoryLabels = {
    ReportCategory.aiCamera: 'Kendala AI Kamera',
    ReportCategory.payment: 'Masalah Pembayaran',
    ReportCategory.material: 'Kesalahan Materi',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_attachments.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 2 foto bukti')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _attachments.add(File(picked.path)));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori kendala terlebih dahulu')),
      );
      return;
    }
    if (_attachments.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wajib melampirkan 2 foto sebagai bukti pendukung')),
      );
      return;
    }

    await ref.read(feedbackReportNotifierProvider.notifier).submitReport(
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
          attachments: _attachments,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan berhasil dikirim')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _openWhatsApp() async {
    // Ganti dengan nomor admin sungguhan
    final uri = Uri.parse('https://wa.me/6281234567890?text=Halo, saya butuh bantuan mendesak terkait Tutur.id');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(feedbackReportNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan Kendala')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Kategori Kendala', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._categoryLabels.entries.map((entry) => RadioListTile<ReportCategory>(
                    title: Text(entry.value),
                    value: entry.key,
                    groupValue: _selectedCategory,
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  )),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Masalah',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Deskripsi minimal 10 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Foto Bukti (wajib 2)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._attachments.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, size: 20),
                                onPressed: () => setState(() => _attachments.removeAt(entry.key)),
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_attachments.length < 2)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_a_photo),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: reportState.isLoading ? null : _submit,
                child: reportState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kirim Laporan'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat),
                label: const Text('Kendala Mendesak? Hubungi via WhatsApp'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 6. Screen: Feedback Form

```dart
// lib/features/feedback_report/presentation/screens/feedback_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/feedback_report_provider.dart';

class FeedbackFormScreen extends ConsumerStatefulWidget {
  const FeedbackFormScreen({super.key});

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  final _descriptionController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beri rating bintang terlebih dahulu')),
      );
      return;
    }

    await ref.read(feedbackReportNotifierProvider.notifier).submitFeedback(
          rating: _rating,
          description: _descriptionController.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terima kasih atas feedback-mu!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackState = ref.watch(feedbackReportNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Beri Feedback')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Bagaimana pengalamanmu menggunakan Tutur.id?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Ceritakan lebih lanjut (opsional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: feedbackState.isLoading ? null : _submit,
                child: feedbackState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kirim Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Update `pubspec.yaml` — Tambah `url_launcher`

```yaml
dependencies:
  url_launcher: ^6.3.1
```

## Update `router.dart`

```dart
GoRoute(
  path: '/feedback-report',
  builder: (context, state) => const FeedbackReportHubScreen(),
),
```

Masukkan `/feedback-report` ke `_studentOnlyPrefixes`.

## Update Firestore Rules

Cek lagi rules kemarin — `reports` dan `feedback` udah kita siapin dari awal (`allow create` dengan validasi `userId` sesuai auth), jadi **gak perlu perubahan** di rules untuk fitur ini.

## Update `TODO.txt`

```
[FITUR: REPORT & FEEDBACK]
[x] Form report (kategori: AI Kamera, Pembayaran, Materi)
[x] Upload 2 foto bukti ke Cloudinary (wajib)
[x] Tombol "Hubungi via WhatsApp" (wa.me link)
[x] Form feedback (star rating + deskripsi)
[x] Provider: reportRepositoryProvider, submitReportProvider
```

## Catatan: Nomor WhatsApp Masih Placeholder

`_openWhatsApp()` masih pakai nomor dummy `6281234567890` — perlu kamu ganti ke nomor admin sungguhan pas udah fix.

Lanjut ke `features/notification/` sesuai urutan TODO?
