import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/app_notification.dart';

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
