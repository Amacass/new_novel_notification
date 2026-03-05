import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/charm_tag.dart';

/// All available charm tags (system + user's own)
final charmTagsProvider = FutureProvider<List<CharmTag>>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('charm_tags')
      .select('*')
      .or('is_system.eq.true,user_id.eq.$userId')
      .order('is_system', ascending: false)
      .order('name');

  return (response as List)
      .map((json) => CharmTag.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Tags for a specific novel (aggregated from all stamps)
final novelTagsProvider =
    FutureProvider.family<List<CharmTag>, int>((ref, novelId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];

  final response = await supabase
      .from('stamp_charm_tags')
      .select('charm_tags(*), stamps!inner(novel_id, user_id)')
      .eq('stamps.novel_id', novelId)
      .eq('stamps.user_id', userId);

  final tagMap = <int, CharmTag>{};
  for (final row in response as List) {
    final tagJson = (row as Map<String, dynamic>)['charm_tags'];
    if (tagJson != null) {
      final tag = CharmTag.fromJson(tagJson as Map<String, dynamic>);
      tagMap[tag.id] = tag;
    }
  }

  return tagMap.values.toList();
});

/// Count of unique tags user has applied (for progressive disclosure)
final userTagCountProvider = FutureProvider<int>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;

  final response = await supabase
      .from('stamp_charm_tags')
      .select('charm_tag_id, stamps!inner(user_id)')
      .eq('stamps.user_id', userId);

  final uniqueTagIds = (response as List)
      .map((r) => (r as Map<String, dynamic>)['charm_tag_id'] as int)
      .toSet();

  return uniqueTagIds.length;
});

final charmTagServiceProvider = Provider<CharmTagService>((ref) {
  return CharmTagService(ref);
});

class CharmTagService {
  final Ref _ref;

  CharmTagService(this._ref);

  Future<CharmTag> createUserTag(String name) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await supabase.from('charm_tags').insert({
      'name': name,
      'is_system': false,
      'user_id': userId,
    }).select().single();

    _ref.invalidate(charmTagsProvider);
    return CharmTag.fromJson(response);
  }

  Future<void> deleteUserTag(int tagId) async {
    await supabase.from('charm_tags').delete().eq('id', tagId);
    _ref.invalidate(charmTagsProvider);
  }

  Future<void> addTagToStamp(int stampId, int tagId) async {
    await supabase.from('stamp_charm_tags').insert({
      'stamp_id': stampId,
      'charm_tag_id': tagId,
    });
  }

  Future<void> removeTagFromStamp(int stampId, int tagId) async {
    await supabase
        .from('stamp_charm_tags')
        .delete()
        .eq('stamp_id', stampId)
        .eq('charm_tag_id', tagId);
  }
}
