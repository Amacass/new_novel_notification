import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/stamp.dart';
import '../providers/bookmark_provider.dart';

/// Provider for stamps of a specific novel
final novelStampsProvider =
    FutureProvider.family<List<EmotionStamp>, int>((ref, novelId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('stamps')
      .select('*, stamp_charm_tags(charm_tags(*))')
      .eq('user_id', userId)
      .eq('novel_id', novelId)
      .order('created_at', ascending: false);

  return (response as List)
      .map((json) => EmotionStamp.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// All stamps for the current user: novelId → set of emojis
final allUserStampsProvider =
    FutureProvider<Map<int, Set<String>>>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return {};

  final response = await supabase
      .from('stamps')
      .select('novel_id, emoji')
      .eq('user_id', userId);

  final Map<int, Set<String>> result = {};
  for (final row in response as List) {
    final novelId = row['novel_id'] as int;
    final emoji = row['emoji'] as String;
    result.putIfAbsent(novelId, () => {}).add(emoji);
  }
  return result;
});

/// Total stamp count for the user
final userStampCountProvider = FutureProvider<int>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;

  final response = await supabase
      .from('stamps')
      .select('id')
      .eq('user_id', userId);

  return (response as List).length;
});

/// Stamp CRUD operations
final stampServiceProvider = Provider<StampService>((ref) {
  return StampService(ref);
});

class StampService {
  final Ref _ref;

  StampService(this._ref);

  /// Toggle: if stamp with this emoji already exists for novel, remove it.
  /// Otherwise add it. Returns true if stamp was added, false if removed.
  Future<bool> toggleStamp({
    required int novelId,
    required String emoji,
    int? episodeNumber,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Check if stamp already exists for this emoji/novel
    final existing = await supabase
        .from('stamps')
        .select('id')
        .eq('user_id', userId)
        .eq('novel_id', novelId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      await supabase.from('stamps').delete().eq('id', existing['id'] as int);
      _ref.invalidate(novelStampsProvider(novelId));
      _ref.invalidate(userStampCountProvider);
      _ref.invalidate(allUserStampsProvider);
      return false;
    }

    await supabase.from('stamps').insert({
      'user_id': userId,
      'novel_id': novelId,
      'emoji': emoji,
      // ignore: use_null_aware_elements
      if (episodeNumber != null) 'episode_number': episodeNumber,
    });

    // Update bookmark's last_stamped_at
    final bookmarks = _ref.read(bookmarkListProvider).valueOrNull ?? [];
    final bookmark = bookmarks.where((b) => b.novelId == novelId).firstOrNull;
    if (bookmark != null) {
      await _ref
          .read(bookmarkListProvider.notifier)
          .updateLastStampedAt(bookmark.id);
    }

    _ref.invalidate(novelStampsProvider(novelId));
    _ref.invalidate(userStampCountProvider);
    _ref.invalidate(allUserStampsProvider);
    return true;
  }

  Future<void> deleteStamp(int stampId, int novelId) async {
    await supabase.from('stamps').delete().eq('id', stampId);
    _ref.invalidate(novelStampsProvider(novelId));
    _ref.invalidate(userStampCountProvider);
  }
}
