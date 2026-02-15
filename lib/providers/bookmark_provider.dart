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
        .select('*, novels(*), reviews(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchBookmarks);
  }

  Future<void> addBookmark({
    required int novelId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('bookmarks').insert({
      'user_id': userId,
      'novel_id': novelId,
    });

    await refresh();
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
}
