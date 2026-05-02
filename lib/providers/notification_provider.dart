import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/app_notification.dart';

/// タイムライン用の通知データ（novel情報をJOIN）
class TimelineItem {
  final AppNotification notification;
  final String? novelUrl;
  final String? novelTitle;
  final String? authorName;
  final int? totalEpisodes;
  final String? site;

  const TimelineItem({
    required this.notification,
    this.novelUrl,
    this.novelTitle,
    this.authorName,
    this.totalEpisodes,
    this.site,
  });
}

final timelineProvider =
    AsyncNotifierProvider<TimelineNotifier, List<TimelineItem>>(
  TimelineNotifier.new,
);

class TimelineNotifier extends AsyncNotifier<List<TimelineItem>> {
  @override
  Future<List<TimelineItem>> build() async {
    return _fetchTimeline();
  }

  Future<List<TimelineItem>> _fetchTimeline() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('notifications')
        .select('*, novels(url, title, author_name, total_episodes, site)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List).map((json) {
      final notificationJson = Map<String, dynamic>.from(json as Map<String, dynamic>);
      final novelData = notificationJson.remove('novels') as Map<String, dynamic>?;

      return TimelineItem(
        notification: AppNotification.fromJson(notificationJson),
        novelUrl: novelData?['url'] as String?,
        novelTitle: novelData?['title'] as String?,
        authorName: novelData?['author_name'] as String?,
        totalEpisodes: novelData?['total_episodes'] as int?,
        site: novelData?['site'] as String?,
      );
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchTimeline);
  }

  Future<void> markAsRead(int notificationId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);

    // Also refresh the notification list provider
    ref.invalidate(notificationListProvider);
    await refresh();
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<AppNotification>>(
  NotificationListNotifier.new,
);

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationListProvider);
  return notifications.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

class NotificationListNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    return _fetchNotifications();
  }

  Future<List<AppNotification>> _fetchNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchNotifications);
  }

  Future<void> markAsRead(int notificationId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);

    await refresh();
  }

  Future<void> markAllAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);

    await refresh();
  }
}
