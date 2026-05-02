import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

final realtimeProvider = Provider<void>((ref) {
  final authState = ref.watch(authStateProvider);
  final userId = authState.valueOrNull?.user.id;

  if (userId == null) return;

  final channel = supabase.channel('notifications_$userId')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        ref.invalidate(timelineProvider);
        ref.invalidate(notificationListProvider);
      },
    )
    ..subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });
});
