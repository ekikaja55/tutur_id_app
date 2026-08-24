import 'package:tutur_id_app/shared/enums/notification_type.dart';

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final bool isRead;
  final String body;
  final String? referenceId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    this.referenceId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      type: NotificationType.fromMap(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool? ?? false,
      referenceId: json['referenceId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'body': body,
      'isRead': isRead,
      'referenceId': referenceId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
