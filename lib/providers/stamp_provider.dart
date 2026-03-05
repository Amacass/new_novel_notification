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

/// Total stamp count for the user (for progressive disclosure)
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

  Future<EmotionStamp> addStamp({
    required int novelId,
    required String emoji,
    int? episodeNumber,
    List<int> charmTagIds = const [],
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Insert stamp
    final stampResponse = await supabase.from('stamps').insert({
      'user_id': userId,
      'novel_id': novelId,
      'emoji': emoji,
      if (episodeNumber != null) 'episode_number': episodeNumber,
    }).select('*, stamp_charm_tags(charm_tags(*))').single();

    // Attach charm tags
    if (charmTagIds.isNotEmpty) {
      final stampId = stampResponse['id'] as int;
      await supabase.from('stamp_charm_tags').insert(
        charmTagIds.map((tagId) => {
              'stamp_id': stampId,
              'charm_tag_id': tagId,
            }).toList(),
      );
    }

    // Update bookmark's last_stamped_at
    final bookmarks = _ref.read(bookmarkListProvider).valueOrNull ?? [];
    final bookmark = bookmarks.where((b) => b.novelId == novelId).firstOrNull;
    if (bookmark != null) {
      await _ref
          .read(bookmarkListProvider.notifier)
          .updateLastStampedAt(bookmark.id);
    }

    // Invalidate stamp providers
    _ref.invalidate(novelStampsProvider(novelId));
    _ref.invalidate(userStampCountProvider);

    return EmotionStamp.fromJson(stampResponse);
  }

  Future<void> deleteStamp(int stampId, int novelId) async {
    await supabase.from('stamps').delete().eq('id', stampId);
    _ref.invalidate(novelStampsProvider(novelId));
    _ref.invalidate(userStampCountProvider);
  }
}
