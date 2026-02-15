import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newEpisode:
        return Icons.new_releases_outlined;
      case NotificationType.newNovelByAuthor:
        return Icons.auto_stories_outlined;
      case NotificationType.novelCompleted:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationListProvider.notifier).markAllAsRead();
            },
            child: const Text('全て既読'),
          ),
        ],
      ),
      body: notifications.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '通知はありません',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationListProvider.notifier).refresh(),
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final notification = list[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notification.isRead
                        ? Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                        : Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                    child: Icon(
                      _getIcon(notification.type),
                      color: notification.isRead
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notification.body != null)
                        Text(notification.body!),
                      Text(
                        timeago.format(notification.createdAt, locale: 'ja'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!notification.isRead) {
                      ref
                          .read(notificationListProvider.notifier)
                          .markAsRead(notification.id);
                    }
                    if (notification.novelId != null) {
                      context.push('/novel/${notification.novelId}');
                    }
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('エラー: $error')),
      ),
    );
  }
}
