import 'dart:io';

import 'package:tutur_id_app/core/services/cloudinary_service.dart';
import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/core/utils/app_logger.dart';
import 'package:tutur_id_app/features/feedback_report/data/models/feedback_model.dart';
import 'package:tutur_id_app/features/feedback_report/data/models/report_model.dart';
import 'package:tutur_id_app/shared/enums/report_status.dart';

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
      final url = await _cloudinaryService.uploadImage(
        file,
        folder: 'tutur_id/reports',
      );
      urls.add(url);
    }

    final reportId =
        'report_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final report = ReportModel(
      id: reportId,
      userId: userId,
      category: category,
      description: description,
      attachmentUrls: urls,
      status: ReportStatus.accepted,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _firebaseService.setDocument('reports', reportId, report.toJson());
    AppLogger.s('Report berhasil dikirim: $reportId', tag: _tag);
  }

  Future<List<ReportModel>> getUserReports(String userId) async {
    final data = await _firebaseService.getCollection(
      'reports',
      queryBuilder: (query) => query
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
    );
    return data.map((e) => ReportModel.fromJson(e)).toList();
  }

  // ---------- FEEDBACK ----------

  Future<void> submitFeedback({
    required String userId,
    required int rating,
    required String description,
  }) async {
    final feedbackId =
        'feedback_${userId}_${DateTime.now().millisecondsSinceEpoch}';
    final feedback = FeedbackModel(
      id: feedbackId,
      userId: userId,
      rating: rating,
      description: description,
      createdAt: DateTime.now(),
    );

    await _firebaseService.setDocument(
      'feedback',
      feedbackId,
      feedback.toJson(),
    );
    AppLogger.s('Feedback berhasil dikirim: $feedbackId', tag: _tag);
  }

  Future<List<FeedbackModel>> getUserFeedbacks(String userId) async {
    final data = await _firebaseService.getCollection(
      'feedback',
      queryBuilder: (query) => query
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true),
    );
    return data.map((e) => FeedbackModel.fromJson(e)).toList();
  }
}
