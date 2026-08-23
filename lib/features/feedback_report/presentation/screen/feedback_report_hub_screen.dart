import 'package:flutter/material.dart';
import 'package:tutur_id_app/features/feedback_report/presentation/screen/feedback_form_screen.dart';
import 'package:tutur_id_app/features/feedback_report/presentation/screen/report_form_screen.dart';

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
                subtitle: const Text(
                  'Ada masalah dengan AI kamera, pembayaran, atau materi?',
                ),
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
                subtitle: const Text(
                  'Bagikan kesan dan saranmu untuk Tutur.id',
                ),
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
