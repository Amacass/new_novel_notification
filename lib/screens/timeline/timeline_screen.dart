import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  NotificationType? _selectedFilter;

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

  Color _getIconColor(NotificationType type, BuildContext context) {
    switch (type) {
      case NotificationType.newEpisode:
        return Colors.blue;
      case NotificationType.newNovelByAuthor:
        return Colors.green;
      case NotificationType.novelCompleted:
        return Colors.orange;
    }
  }

  Future<void> _openNovelUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(timelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('すべて'),
                    selected: _selectedFilter == null,
                    onSelected: (_) => setState(() => _selectedFilter = null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('新話'),
                    selected: _selectedFilter == NotificationType.newEpisode,
                    onSelected: (_) => setState(
                      () => _selectedFilter = NotificationType.newEpisode,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('新作'),
                    selected:
                        _selectedFilter == NotificationType.newNovelByAuthor,
                    onSelected: (_) => setState(
                      () => _selectedFilter = NotificationType.newNovelByAuthor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('完結'),
                    selected:
                        _selectedFilter == NotificationType.novelCompleted,
                    onSelected: (_) => setState(
                      () => _selectedFilter = NotificationType.novelCompleted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Timeline list
          Expanded(
            child: timeline.when(
              data: (items) {
                final filtered = _selectedFilter == null
                    ? items
                    : items
                        .where(
                          (item) =>
                              item.notification.type == _selectedFilter,
                        )
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '更新はありません',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(timelineProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final notification = item.notification;
                      final iconColor =
                          _getIconColor(notification.type, context);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: notification.isRead
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : iconColor.withValues(alpha: 0.15),
                          child: Icon(
                            _getIcon(notification.type),
                            color: notification.isRead
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                : iconColor,
                          ),
                        ),
                        title: Text(
                          item.novelTitle ?? notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${item.authorName ?? ''} · ${timeago.format(notification.createdAt, locale: 'ja')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: notification.isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        onTap: () async {
                          if (!notification.isRead) {
                            ref
                                .read(timelineProvider.notifier)
                                .markAsRead(notification.id);
                          }
                          final url = item.novelUrl;
                          if (url != null) {
                            await _openNovelUrl(url);
                          }
                        },
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('エラー: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
