import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/feedback_report/data/models/feedback_model.dart';
import 'package:tutur_id_app/features/feedback_report/data/models/report_model.dart';
import 'package:tutur_id_app/features/feedback_report/data/repositories/feedback_report_repository.dart';
import 'package:tutur_id_app/shared/enums/report_status.dart';

// const _tag = 'FEEDBACK_REPORT';

final feedbackReportRepositoryProvider = Provider<FeedbackReportRepository>((
  ref,
) {
  return FeedbackReportRepository(
    ref.watch(firebaseServiceProvider),
    ref.watch(cloudinaryServiceProvider),
  );
});

final userReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref
      .watch(feedbackReportRepositoryProvider)
      .getUserReports(profile.uid);
});

final userFeedbacksProvider = FutureProvider<List<FeedbackModel>>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  if (profile == null) return [];
  return ref
      .watch(feedbackReportRepositoryProvider)
      .getUserFeedbacks(profile.uid);
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
      await ref
          .read(feedbackReportRepositoryProvider)
          .submitReport(
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
      await ref
          .read(feedbackReportRepositoryProvider)
          .submitFeedback(
            userId: profile.uid,
            rating: rating,
            description: description,
          );
    });

    ref.invalidate(userFeedbacksProvider);
  }
}

final feedbackReportNotifierProvider =
    AsyncNotifierProvider<FeedbackReportNotifier, void>(
      FeedbackReportNotifier.new,
    );
