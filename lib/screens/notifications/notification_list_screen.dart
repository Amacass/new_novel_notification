import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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

                if (notification.type == NotificationType.crawlBatch &&
                    notification.batchItems != null &&
                    notification.batchItems!.length > 1) {
                  return _BatchNotificationTile(
                    notification: notification,
                    ref: ref,
                  );
                }

                return _SingleNotificationTile(
                  notification: notification,
                  ref: ref,
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

// 単体通知（new_episode / new_novel_by_author / novel_completed / crawl_batch 1件）
class _SingleNotificationTile extends StatelessWidget {
  const _SingleNotificationTile({
    required this.notification,
    required this.ref,
  });

  final AppNotification notification;
  final WidgetRef ref;

  IconData _getIcon(NotificationType type) {
    switch (type) {
      case NotificationType.newEpisode:
        return Icons.new_releases_outlined;
      case NotificationType.newNovelByAuthor:
        return Icons.auto_stories_outlined;
      case NotificationType.novelCompleted:
        return Icons.check_circle_outline;
      case NotificationType.crawlBatch:
        return Icons.new_releases_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
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
          fontWeight:
              notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.body != null) Text(notification.body!),
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
        // crawl_batch 1件のときは batchItems[0].novelId を優先
        final targetId = notification.batchItems?.firstOrNull?.novelId ??
            notification.novelId;
        if (targetId != null) {
          context.push('/novel/$targetId');
        }
      },
    );
  }
}

// バッチ通知（crawl_batch で複数件）― 展開すると小説一覧が出る
class _BatchNotificationTile extends StatelessWidget {
  const _BatchNotificationTile({
    required this.notification,
    required this.ref,
  });

  final AppNotification notification;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final items = notification.batchItems!;
    final colorScheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        child: Icon(
          Icons.library_books_outlined,
          color: notification.isRead
              ? colorScheme.onSurfaceVariant
              : colorScheme.primary,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        timeago.format(notification.createdAt, locale: 'ja'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onExpansionChanged: (expanded) {
        if (expanded && !notification.isRead) {
          ref
              .read(notificationListProvider.notifier)
              .markAsRead(notification.id);
        }
      },
      children: items
          .map(
            (item) => ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
              leading:
                  const Icon(Icons.new_releases_outlined, size: 20),
              title: Text(
                item.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              trailing: Text(
                '第${item.newTotal}話',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              onTap: () => context.push('/novel/${item.novelId}'),
            ),
          )
          .toList(),
    );
  }
}
