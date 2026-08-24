import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutur_id_app/core/services/providers.dart';
import 'package:tutur_id_app/features/auth/logic/auth_provider.dart';
import 'package:tutur_id_app/features/notification/data/models/notification_model.dart';
import 'package:tutur_id_app/features/notification/data/repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firebaseServiceProvider));
});

// StreamProvider - real-time, sesuai konvensi kita untuk data yang sering berubah
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final profile = profileAsync.value;

  if (profile == null) return const Stream.empty();

  return ref
      .watch(notificationRepositoryProvider)
      .streamNotifications(profile.uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;
});

class NotificationNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markAsRead(String notificationId) async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    await ref
        .read(notificationRepositoryProvider)
        .markAsRead(profile.uid, notificationId);
    // Gak perlu ref.invalidate() karena ini StreamProvider - otomatis update
  }

  Future<void> markAllAsRead() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    final notifications = ref.read(notificationsProvider).value ?? [];
    final unreadIds = notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    await ref
        .read(notificationRepositoryProvider)
        .markAllAsRead(profile.uid, unreadIds);
  }
}

final notificationNotifierProvider =
    AsyncNotifierProvider<NotificationNotifier, void>(NotificationNotifier.new);
