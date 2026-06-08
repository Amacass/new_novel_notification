import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/recommendation.dart';

// --------- フィードタブ ---------
enum RecommendTab { omakase, daily, weekly, monthly, total, mine }

// --------- おすすめ設定（profiles カラム） ---------
class RecommendSettings {
  final bool viewEnabled;
  final bool createEnabled;
  final int totalLikes;

  const RecommendSettings({
    this.viewEnabled = true,
    this.createEnabled = true,
    this.totalLikes = 0,
  });
}

final recommendSettingsProvider =
    AsyncNotifierProvider<RecommendSettingsNotifier, RecommendSettings>(
  RecommendSettingsNotifier.new,
);

class RecommendSettingsNotifier extends AsyncNotifier<RecommendSettings> {
  @override
  Future<RecommendSettings> build() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return const RecommendSettings();
    final row = await supabase
        .from('profiles')
        .select('recommend_view_enabled, recommend_create_enabled, total_recommend_likes')
        .eq('id', userId)
        .single();
    return RecommendSettings(
      viewEnabled: row['recommend_view_enabled'] as bool? ?? true,
      createEnabled: row['recommend_create_enabled'] as bool? ?? true,
      totalLikes: row['total_recommend_likes'] as int? ?? 0,
    );
  }

  Future<void> setViewEnabled(bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase
        .from('profiles')
        .update({'recommend_view_enabled': value})
        .eq('id', userId);
    state = AsyncData(RecommendSettings(
      viewEnabled: value,
      createEnabled: state.value?.createEnabled ?? true,
      totalLikes: state.value?.totalLikes ?? 0,
    ));
  }

  Future<void> setCreateEnabled(bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await supabase
        .from('profiles')
        .update({'recommend_create_enabled': value})
        .eq('id', userId);
    state = AsyncData(RecommendSettings(
      viewEnabled: state.value?.viewEnabled ?? true,
      createEnabled: value,
      totalLikes: state.value?.totalLikes ?? 0,
    ));
  }
}

// --------- フィード（ランキング / 自分のおすすめ） ---------

final recommendFeedProvider = AsyncNotifierProviderFamily<
    RecommendFeedNotifier, List<Recommendation>, RecommendTab>(
  RecommendFeedNotifier.new,
);

class RecommendFeedNotifier
    extends FamilyAsyncNotifier<List<Recommendation>, RecommendTab> {
  @override
  Future<List<Recommendation>> build(RecommendTab tab) async {
    return _fetch(tab, reset: true);
  }

  static const _pageSize = 20;
  int _page = 0;
  bool _hasMore = true;

  Future<List<Recommendation>> _fetch(RecommendTab tab,
      {bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return state.value ?? [];

    final userId = supabase.auth.currentUser?.id;

    List<Map<String, dynamic>> rows;

    switch (tab) {
      case RecommendTab.total:
      case RecommendTab.omakase:
        final res = await supabase
            .from('recommendations')
            .select('*, novels(*), author:public_profiles(*)')
            .eq('is_public', true)
            .eq('moderation_status', 'approved')
            .order('like_count', ascending: false)
            .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
        rows = (res as List).cast<Map<String, dynamic>>();

      case RecommendTab.daily:
      case RecommendTab.weekly:
      case RecommendTab.monthly:
        final period = tab.name;
        final res = await supabase
            .from('recommendation_ranking_snapshots')
            .select(
              'rank, likes_in_period, recommendations(*, novels(*), author:public_profiles(*))',
            )
            .eq('period', period)
            .order('rank')
            .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
        rows = (res as List)
            .cast<Map<String, dynamic>>()
            .where((r) => r['recommendations'] != null)
            .map((r) => r['recommendations'] as Map<String, dynamic>)
            .toList();

      case RecommendTab.mine:
        if (userId == null) return [];
        final res = await supabase
            .from('recommendations')
            .select('*, novels(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .range(_page * _pageSize, (_page + 1) * _pageSize - 1);
        rows = (res as List).cast<Map<String, dynamic>>();
    }

    _hasMore = rows.length == _pageSize;
    _page++;

    final recs = rows.map(Recommendation.fromJson).toList();
    if (reset) return recs;
    return [...(state.value ?? []), ...recs];
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final next = await _fetch(arg);
    state = AsyncData(next);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg, reset: true));
  }

  // いいね toggle（楽観的更新）
  Future<void> toggleLike(Recommendation rec) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final liked = rec.isLikedByMe ?? false;
    final updated = rec.copyWith(
      likeCount: rec.likeCount + (liked ? -1 : 1),
      isLikedByMe: !liked,
    );
    state = AsyncData(_replace(updated));

    if (liked) {
      await supabase
          .from('recommendation_likes')
          .delete()
          .eq('recommendation_id', rec.id)
          .eq('user_id', userId);
    } else {
      await supabase.from('recommendation_likes').insert({
        'recommendation_id': rec.id,
        'user_id': userId,
      });
    }
  }

  // 公開/非公開 toggle（自分のおすすめタブ用）
  Future<void> togglePublic(Recommendation rec) async {
    final next = !rec.isPublic;
    await supabase
        .from('recommendations')
        .update({'is_public': next})
        .eq('id', rec.id);
    state = AsyncData(_replace(rec.copyWith(isPublic: next)));
  }

  Future<void> delete(int id) async {
    await supabase.from('recommendations').delete().eq('id', id);
    state = AsyncData((state.value ?? []).where((r) => r.id != id).toList());
  }

  List<Recommendation> _replace(Recommendation rec) {
    return (state.value ?? [])
        .map((r) => r.id == rec.id ? rec : r)
        .toList();
  }
}

// --------- 特定小説へのおすすめ一覧（詳細画面用） ---------
final novelRecommendationsProvider = FutureProviderFamily<
    List<Recommendation>, int>((ref, novelId) async {
  final userId = supabase.auth.currentUser?.id;
  final res = await supabase
      .from('recommendations')
      .select('*, author:public_profiles(*)')
      .eq('novel_id', novelId)
      .eq('is_public', true)
      .eq('moderation_status', 'approved')
      .order('like_count', ascending: false)
      .limit(20);

  final recs = (res as List)
      .cast<Map<String, dynamic>>()
      .map(Recommendation.fromJson)
      .toList();

  if (userId == null) return recs;

  // 自分がいいね済みかを確認
  final ids = recs.map((r) => r.id).toList();
  if (ids.isEmpty) return recs;

  final liked = await supabase
      .from('recommendation_likes')
      .select('recommendation_id')
      .eq('user_id', userId)
      .inFilter('recommendation_id', ids);

  final likedIds = (liked as List)
      .cast<Map<String, dynamic>>()
      .map((r) => r['recommendation_id'] as int)
      .toSet();

  return recs
      .map((r) => r.copyWith(isLikedByMe: likedIds.contains(r.id)))
      .toList();
});

// 自分の特定小説へのおすすめ
final myNovelRecommendationProvider =
    FutureProviderFamily<Recommendation?, int>((ref, novelId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final res = await supabase
      .from('recommendations')
      .select()
      .eq('user_id', userId)
      .eq('novel_id', novelId)
      .maybeSingle();

  if (res == null) return null;
  return Recommendation.fromJson(res);
});
