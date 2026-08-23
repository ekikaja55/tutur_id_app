import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/features/feedback_report/logic/feedback_report_provider.dart';

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

    await ref
        .read(feedbackReportNotifierProvider.notifier)
        .submitFeedback(
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
