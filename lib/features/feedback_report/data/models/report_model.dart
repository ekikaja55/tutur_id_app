import 'package:tutur_id_app/shared/enums/report_status.dart';

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
    required this.createdAt,
    required this.updatedAt,

    this.attachmentUrls = const [],
    this.status = ReportStatus.accepted,
    this.adminResponse,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: ReportCategory.fromMap(json['category'] as String?),
      description: json['description'] as String,
      attachmentUrls: List<String>.from(json['attachmentUrls'] as List? ?? []),
      status: ReportStatus.fromMap(json['status'] as String?),
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
