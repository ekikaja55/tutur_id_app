Oke, lanjut ke **`features/notification/`** — Pusat Notifikasi, dengan subcollection `notifications/{uid}/messages/{messageId}` sesuai struktur Firestore yang kita sepakati.

## 1. Data Model

```dart
// lib/features/notification/data/models/notification_model.dart

enum NotificationType { system, gamification, transaction, reportResponse }

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
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
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
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
```

## 2. Repository

Karena ini subcollection (`notifications/{uid}/messages/{messageId}`), `FirebaseService` generik kita **gak cukup** — dia cuma handle path 1 level (`collection/docId`). Perlu sedikit extend, atau akses Firestore langsung di repository ini untuk kasus nested path.

### Update `core/services/firebase_service.dart` — Tambah Method untuk Subcollection

```dart
// lib/core/services/firebase_service.dart
// Tambahkan method baru di FirebaseService

Stream<List<Map<String, dynamic>>> streamSubcollection(
  String parentCollection,
  String parentId,
  String subcollection, {
  Query Function(Query)? queryBuilder,
}) {
  Query query = _firestore
      .collection(parentCollection)
      .doc(parentId)
      .collection(subcollection);
  if (queryBuilder != null) {
    query = queryBuilder(query);
  }
  return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
            .toList(),
      );
}

Future<void> setSubcollectionDocument(
  String parentCollection,
  String parentId,
  String subcollection,
  String docId,
  Map<String, dynamic> data,
) async {
  await _firestore
      .collection(parentCollection)
      .doc(parentId)
      .collection(subcollection)
      .doc(docId)
      .set(data, SetOptions(merge: true));
}

Future<void> updateSubcollectionDocument(
  String parentCollection,
  String parentId,
  String subcollection,
  String docId,
  Map<String, dynamic> data,
) async {
  await _firestore
      .collection(parentCollection)
      .doc(parentId)
      .collection(subcollection)
      .doc(docId)
      .update(data);
}
```

### `features/notification/data/repositories/notification_repository.dart`

```dart
// lib/features/notification/data/repositories/notification_repository.dart
import '../../../../core/services/firebase_service.dart';
import '../models/notification_model.dart';

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

  Future<void> markAllAsRead(String userId, List<String> notificationIds) async {
    for (final id in notificationIds) {
      await markAsRead(userId, id);
    }
  }
}
```

## 3. Provider

```dart
// lib/features/notification/logic/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/providers.dart';
import '../../auth/logic/auth_provider.dart';
import '../data/repositories/notification_repository.dart';
import '../data/models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firebaseServiceProvider));
});

// StreamProvider - real-time, sesuai konvensi kita untuk data yang sering berubah
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final profile = profileAsync.value;

  if (profile == null) return const Stream.empty();

  return ref.watch(notificationRepositoryProvider).streamNotifications(profile.uid);
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

    await ref.read(notificationRepositoryProvider).markAsRead(profile.uid, notificationId);
    // Gak perlu ref.invalidate() karena ini StreamProvider - otomatis update
  }

  Future<void> markAllAsRead() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile == null) return;

    final notifications = ref.read(notificationsProvider).value ?? [];
    final unreadIds = notifications.where((n) => !n.isRead).map((n) => n.id).toList();

    if (unreadIds.isEmpty) return;

    await ref.read(notificationRepositoryProvider).markAllAsRead(profile.uid, unreadIds);
  }
}

final notificationNotifierProvider = AsyncNotifierProvider<NotificationNotifier, void>(
  NotificationNotifier.new,
);
```

## 4. Screen: Notification List

```dart
// lib/features/notification/presentation/screens/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/notification_model.dart';
import '../../logic/notification_provider.dart';

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
```

## Update `pubspec.yaml` — Tambah `timeago`

Buat format waktu relatif ("5 menit lalu", bukan timestamp mentah):

```yaml
dependencies:
  timeago: ^3.7.0
```

## 5. Widget: Badge Notifikasi (Opsional tapi Berguna)

Karena kita punya `unreadNotificationCountProvider`, ini bisa dipakai buat badge counter di ikon notifikasi, misal di `LearningHomeScreen`:

```dart
// lib/core/widgets/notification_badge_icon.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/notification/logic/notification_provider.dart';

class NotificationBadgeIcon extends ConsumerWidget {
  const NotificationBadgeIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => context.push('/notifications'),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
```

Dipakai di `AppBar` mana pun yang butuh, misal:
```dart
// learning_home_screen.dart
AppBar(
  title: const Text('Belajar BISINDO'),
  actions: const [NotificationBadgeIcon()],
),
```

## Update Firestore Rules — Perlu Penyesuaian untuk Subcollection

Cek rules kita sebelumnya:
```javascript
1
```

Ini **sudah benar** — user cuma bisa baca notif miliknya sendiri, tapi **gak bisa create/update sendiri** (`isAdmin()` doang yang boleh write). Konsekuensinya: `markAsRead()` yang kita buat barusan **akan gagal** kalau dijalankan oleh user biasa, karena update itu tetap kena rule `allow write: if isAdmin()`.

**Perlu diperbaiki**, karena user harus bisa update `isRead` miliknya sendiri:

```javascript
match /notifications/{userId}/messages/{messageId} {
  allow read: if isOwner(userId);
  allow create: if isAdmin(); // cuma admin/system yang bisa BUAT notifikasi baru
  allow update: if isOwner(userId) &&
                   request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']);
                   // user cuma boleh ubah field isRead, gak field lain
  allow delete: if false;
}
```

Baris `affectedKeys().hasOnly(['isRead'])` ini penting — biar user **cuma bisa** toggle status baca, **gak bisa** mengubah `title`/`body`/`type` notifikasi (yang seharusnya cuma admin/sistem yang tentukan).

## Update `router.dart`

Route `/notifications` udah terdaftar dari awal di `_sharedPrefixes`, jadi gak perlu tambahan konfigurasi routing.

## Catatan: Siapa yang "Menulis" Notifikasi?

Sesuai rules di atas, notifikasi **dibuat oleh admin** (lewat fitur `admin/broadcast/` yang belum kita bangun) atau **sistem otomatis** — misalnya waktu report di-update statusnya, atau transaksi Midtrans berhasil. Untuk sekarang, `NotificationRepository` kita **belum ada method `createNotification()`** karena belum ada pemicu nyata dari sisi mana pun.

Ini akan otomatis terisi begitu kita bangun:
1. **`features/admin/broadcast/`** — admin kirim notifikasi manual/template
2. **Trigger dari report** — begitu admin update status report, otomatis kirim notifikasi ke user terkait
3. **Trigger dari transaksi** — begitu `confirmTransactionOptimistic()` di subscription selesai, kirim notifikasi juga

Aku catat di `TODO.txt` biar jelas dependency-nya:

```
[FITUR: NOTIFIKASI]
[x] Pusat notifikasi UI (real-time via StreamProvider)
[x] Provider: notificationProvider, unreadNotificationCountProvider
[x] Badge counter notifikasi belum dibaca
[ ] Trigger notifikasi dari update status report - PENDING, nyambung ke admin/feedback_report_review
[ ] Trigger notifikasi dari status transaksi Midtrans - PENDING, nyambung ke subscription
[ ] Broadcast notifikasi dari admin - PENDING, masuk fitur admin/broadcast
[ ] Notifikasi Daily Quest reminder - PENDING, butuh scheduled job (Cloud Functions)
```

Semua fitur **pelajar** yang punya UI mandiri sekarang udah selesai kerangkanya. Lanjut ke fitur **admin** — mulai dari `features/admin/dashboard/` sesuai yang kita rencanakan sebelumnya?
