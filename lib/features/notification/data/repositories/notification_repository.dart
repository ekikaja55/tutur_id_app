import 'package:tutur_id_app/core/services/firebase_service.dart';
import 'package:tutur_id_app/features/notification/data/models/notification_model.dart';

class NotificationRepository {
  final FirebaseService _firebaseService;
  NotificationRepository(this._firebaseService);

  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _firebaseService
        .streamSubcollection(
          'notifications',
          userId,
          'messages',
          queryBuilder: (query) => query.orderBy('createdAt', descending: true),
        )
        .map((data) => data.map((e) => NotificationModel.fromJson(e)).toList());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firebaseService.updateSubcollectionDocument(
      'notifications',
      userId,
      'messages',
      notificationId,
      {'isRead': true},
    );
  }

  Future<void> markAllAsRead(
    String userId,
    List<String> notificationIds,
  ) async {
    for (final id in notificationIds) {
      await markAsRead(userId, id);
    }
  }
}
