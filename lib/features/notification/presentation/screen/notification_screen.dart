import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:tutur_id_app/features/notification/logic/notification_provider.dart';
import 'package:tutur_id_app/shared/enums/notification_type.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: () => ref.read(notificationNotifierProvider.notifier).markAllAsRead(),
            child: const Text('Tandai Semua Dibaca'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('Belum ada notifikasi'));
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return ListTile(
                leading: Icon(
                  _iconFor(notif.type),
                  color: notif.isRead ? Colors.grey : Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  notif.title,
                  style: TextStyle(
                    fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(notif.body),
                trailing: Text(
                  timeago.format(notif.createdAt, locale: 'id'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                tileColor: notif.isRead ? null : Colors.blue[50],
                onTap: () {
                  if (!notif.isRead) {
                    ref.read(notificationNotifierProvider.notifier).markAsRead(notif.id);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.system:
        return Icons.campaign;
      case NotificationType.gamification:
        return Icons.emoji_events;
      case NotificationType.transaction:
        return Icons.receipt_long;
      case NotificationType.reportResponse:
        return Icons.reply;
    }
  }
}
