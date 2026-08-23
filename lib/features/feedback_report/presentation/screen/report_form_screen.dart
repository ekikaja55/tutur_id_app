import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tutur_id_app/features/feedback_report/logic/feedback_report_provider.dart';
import 'package:tutur_id_app/shared/enums/report_status.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maksimal 2 foto bukti')));
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
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
        const SnackBar(
          content: Text('Wajib melampirkan 2 foto sebagai bukti pendukung'),
        ),
      );
      return;
    }

    await ref
        .read(feedbackReportNotifierProvider.notifier)
        .submitReport(
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
          attachments: _attachments,
        );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Laporan berhasil dikirim')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _openWhatsApp() async {
    // Ganti dengan nomor admin sungguhan
    final uri = Uri.parse(
      'https://wa.me/6285739761999?text=Halo, saya butuh bantuan mendesak terkait Tutur.id',
    );
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
              const Text(
                'Kategori Kendala',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._categoryLabels.entries.map(
                (entry) => RadioListTile<ReportCategory>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _selectedCategory,
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
              ),
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
              const Text(
                'Foto Bukti (wajib 2)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ..._attachments.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              entry.value,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: const Icon(Icons.cancel, size: 20),
                              onPressed: () => setState(
                                () => _attachments.removeAt(entry.key),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
