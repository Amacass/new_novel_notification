import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/bookmark.dart';

final bookmarkListProvider =
    AsyncNotifierProvider<BookmarkListNotifier, List<Bookmark>>(
  BookmarkListNotifier.new,
);

class BookmarkListNotifier extends AsyncNotifier<List<Bookmark>> {
  @override
  Future<List<Bookmark>> build() async {
    return _fetchBookmarks();
  }

  Future<List<Bookmark>> _fetchBookmarks() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('bookmarks')
        .select('*, novels(*), bookmark_categories(category_id, user_categories(*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final bookmarks = (response as List)
        .map((json) => json as Map<String, dynamic>)
        .toList();

    // Fetch reviews separately (no direct FK between bookmarks and reviews)
    if (bookmarks.isNotEmpty) {
      final novelIds = bookmarks
          .map((b) => b['novel_id'] as int)
          .toSet()
          .toList();

      final reviewsResponse = await supabase
          .from('reviews')
          .select('*')
          .eq('user_id', userId)
          .inFilter('novel_id', novelIds);

      final reviewsByNovelId = <int, Map<String, dynamic>>{};
      for (final r in reviewsResponse as List) {
        final review = r as Map<String, dynamic>;
        reviewsByNovelId[review['novel_id'] as int] = review;
      }

      // Attach reviews to bookmark JSON
      for (final b in bookmarks) {
        final novelId = b['novel_id'] as int;
        if (reviewsByNovelId.containsKey(novelId)) {
          b['reviews'] = reviewsByNovelId[novelId];
        }
      }
    }

    return bookmarks
        .map((json) => Bookmark.fromJson(json))
        .toList();
  }

  Future<void> refresh() async {
    // Don't set AsyncLoading: preserve current data while fetching to avoid counts flashing to 0
    state = await AsyncValue.guard(_fetchBookmarks);
  }

  /// Returns true if bookmark was newly added or restored from trash,
  /// false if it already exists with tier != 0.
  Future<bool> addBookmark({required int novelId}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final existing = await supabase
        .from('bookmarks')
        .select('id, tier')
        .eq('user_id', userId)
        .eq('novel_id', novelId)
        .maybeSingle();

    if (existing != null) {
      if ((existing['tier'] as int?) == 0) {
        // Restore from trash as unsorted
        await supabase.from('bookmarks').update({
          'tier': -1,
          'last_read_episode': 0,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id']);
        await refresh();
        return true;
      }
      await refresh();
      return false;
    }

    await supabase.from('bookmarks').insert({
      'user_id': userId,
      'novel_id': novelId,
    });

    await refresh();
    return true;
  }

  Future<void> removeBookmark(int bookmarkId) async {
    await supabase.from('bookmarks').delete().eq('id', bookmarkId);
    await refresh();
  }

  Future<void> updateLastReadEpisode(int bookmarkId, int episode) async {
    await supabase.from('bookmarks').update({
      'last_read_episode': episode,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookmarkId);

    await refresh();
  }

  Future<void> updateMemo(int bookmarkId, String memo) async {
    await supabase.from('bookmarks').update({
      'memo': memo,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookmarkId);

    await refresh();
  }

  Future<void> updateTier(int bookmarkId, int tier) async {
    await supabase.from('bookmarks').update({
      'tier': tier,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookmarkId);

    await refresh();
  }

  Future<void> updateGenre(int bookmarkId, BookmarkGenre? genre) async {
    await supabase.from('bookmarks').update({
      'genre': genre?.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookmarkId);

    await refresh();
  }

  Future<void> updateHeatScore(int bookmarkId, double score) async {
    await supabase.from('bookmarks').update({
      'heat_score': score,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookmarkId);

    // Update local state without full refresh
    state = state.whenData((bookmarks) => bookmarks.map((b) {
          if (b.id == bookmarkId) return b.copyWith(heatScore: score);
          return b;
        }).toList());
  }

  Future<void> assignCategory(int bookmarkId, int categoryId) async {
    await supabase.from('bookmark_categories').insert({
      'bookmark_id': bookmarkId,
      'category_id': categoryId,
    });
  }

  Future<void> unassignCategory(int bookmarkId, int categoryId) async {
    await supabase
        .from('bookmark_categories')
        .delete()
        .eq('bookmark_id', bookmarkId)
        .eq('category_id', categoryId);
  }

  Future<void> syncCategories(
    int bookmarkId,
    Set<int> oldIds,
    Set<int> newIds,
  ) async {
    final toAdd = newIds.difference(oldIds);
    final toRemove = oldIds.difference(newIds);

    for (final id in toAdd) {
      await assignCategory(bookmarkId, id);
    }
    for (final id in toRemove) {
      await unassignCategory(bookmarkId, id);
    }

    if (toAdd.isNotEmpty || toRemove.isNotEmpty) {
      await refresh();
    }
  }

  Future<void> updateLastStampedAt(int bookmarkId) async {
    final now = DateTime.now().toIso8601String();
    await supabase.from('bookmarks').update({
      'last_stamped_at': now,
      'updated_at': now,
    }).eq('id', bookmarkId);

    await refresh();
  }
}
