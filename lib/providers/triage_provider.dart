import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/bookmark.dart';
import '../models/triage_session.dart';
import '../providers/bookmark_provider.dart';

class TriageState {
  final TriageSession? session;
  final List<Bookmark> cards;
  final int currentIndex;
  final TriageResult? lastResult;
  final int? lastResultBookmarkId;
  final bool isComplete;
  final bool isLoading;
  final String? error;

  const TriageState({
    this.session,
    this.cards = const [],
    this.currentIndex = 0,
    this.lastResult,
    this.lastResultBookmarkId,
    this.isComplete = false,
    this.isLoading = true,
    this.error,
  });

  int get remaining => cards.length - currentIndex;
  int get total => cards.length;

  TriageState copyWith({
    TriageSession? session,
    List<Bookmark>? cards,
    int? currentIndex,
    TriageResult? lastResult,
    int? lastResultBookmarkId,
    bool? isComplete,
    bool? isLoading,
    String? error,
    bool clearLastResult = false,
    bool clearError = false,
  }) {
    return TriageState(
      session: session ?? this.session,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      lastResultBookmarkId: clearLastResult
          ? null
          : (lastResultBookmarkId ?? this.lastResultBookmarkId),
      isComplete: isComplete ?? this.isComplete,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final triageProvider =
    StateNotifierProvider<TriageNotifier, TriageState>((ref) {
  return TriageNotifier(ref);
});

class TriageNotifier extends StateNotifier<TriageState> {
  final Ref _ref;
  static const int maxCards = 20;
  Set<int> _knownBookmarkIds = {};
  bool _isListening = false;

  TriageNotifier(this._ref) : super(const TriageState()) {
    _init();
  }

  /// Watch bookmarkListProvider for newly added bookmarks.
  /// Called after initial load is complete.
  void _startListeningForNewBookmarks() {
    if (_isListening) return;
    _isListening = true;
    _ref.listen<AsyncValue<List<Bookmark>>>(bookmarkListProvider, (prev, next) {
      if (state.isLoading) return;
      final newList = next.valueOrNull;
      if (newList == null) return;

      for (final bookmark in newList) {
        if (!_knownBookmarkIds.contains(bookmark.id) &&
            bookmark.tier < 0 &&
            !state.cards.any((c) => c.id == bookmark.id)) {
          // New unsorted bookmark detected - add to triage
          addNewBookmark(bookmark);
        }
      }

      // Update known IDs
      _knownBookmarkIds = newList.map((b) => b.id).toSet();
    });
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(isLoading: false);
        _startListeningForNewBookmarks();
        return;
      }

      final bookmarks = await _waitForBookmarks();
      if (bookmarks.isEmpty) {
        _knownBookmarkIds = {};
        state = state.copyWith(isLoading: false);
        _startListeningForNewBookmarks();
        return;
      }

      // Try to check for incomplete session (table may not exist yet)
      Map<String, dynamic>? sessionResponse;
      try {
        sessionResponse = await supabase
            .from('triage_sessions')
            .select('*')
            .eq('user_id', userId)
            .eq('is_complete', false)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        // triage_sessions table not yet migrated - local-only mode (expected)
        _loadCardsWithoutSession(bookmarks);
        _startListeningForNewBookmarks();
        return;
      }

      if (sessionResponse != null) {
        await _resumeSession(sessionResponse, bookmarks);
      } else {
        await _createNewSession(bookmarks);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }

    // Start listening for new bookmarks after initial load
    _startListeningForNewBookmarks();
  }

  Future<List<Bookmark>> _waitForBookmarks() async {
    // If bookmarks are already loaded, use them
    final current = _ref.read(bookmarkListProvider);
    if (current.hasValue && current.value != null && current.value!.isNotEmpty) {
      return current.value!;
    }

    // Otherwise wait for bookmarkListProvider to load with timeout
    try {
      final bookmarks = await _ref
          .read(bookmarkListProvider.future)
          .timeout(const Duration(seconds: 10));
      return bookmarks;
    } catch (_) {
      // Timeout or error - try to return whatever we have
      final fallback = _ref.read(bookmarkListProvider);
      if (fallback.hasValue && fallback.value != null) {
        return fallback.value!;
      }
      return [];
    }
  }

  void _loadCardsWithoutSession(List<Bookmark> bookmarks) {
    _knownBookmarkIds = bookmarks.map((b) => b.id).toSet();

    // Only include unsorted bookmarks (tier < 0)
    final unsorted = bookmarks.where((b) => b.tier < 0).toList()
      ..sort((a, b) => b.heatScore.compareTo(a.heatScore));
    final cards = unsorted.take(maxCards).toList();

    state = TriageState(
      session: null,
      cards: cards,
      currentIndex: 0,
      isComplete: cards.isEmpty,
      isLoading: false,
    );
  }

  Future<void> _resumeSession(
    Map<String, dynamic> sessionResponse,
    List<Bookmark> bookmarks,
  ) async {
    final session = TriageSession.fromJson(sessionResponse);

    // Get already sorted bookmark IDs
    Set<int> sortedIds = {};
    try {
      final resultsResponse = await supabase
          .from('triage_results')
          .select('bookmark_id')
          .eq('session_id', session.id);
      sortedIds = (resultsResponse as List)
          .map((r) => (r as Map<String, dynamic>)['bookmark_id'] as int)
          .toSet();
    } catch (_) {
      // Ignore if triage_results table doesn't exist
    }

    // Filter out already-sorted cards
    _knownBookmarkIds = bookmarks.map((b) => b.id).toSet();

    final unsorted = bookmarks
        .where((b) => !sortedIds.contains(b.id))
        .toList();
    unsorted.sort((a, b) => b.heatScore.compareTo(a.heatScore));
    final cards = unsorted.take(maxCards).toList();

    state = TriageState(
      session: session,
      cards: cards,
      currentIndex: 0,
      isComplete: cards.isEmpty,
      isLoading: false,
    );
  }

  Future<void> _createNewSession(List<Bookmark> allBookmarks) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Only include unsorted bookmarks (tier < 0)
    final unsorted = allBookmarks.where((b) => b.tier < 0).toList()
      ..sort((a, b) => b.heatScore.compareTo(a.heatScore));
    final cards = unsorted.take(maxCards).toList();
    if (cards.isEmpty) {
      state = state.copyWith(isLoading: false, isComplete: true);
      return;
    }

    // Try to create session in DB, fall back to local-only if table doesn't exist
    TriageSession? session;
    try {
      final response = await supabase.from('triage_sessions').insert({
        'user_id': userId,
        'total_cards': cards.length,
        'sorted_cards': 0,
      }).select().single();
      session = TriageSession.fromJson(response);
    } catch (_) {
      // Table not migrated - proceed without session tracking
    }

    _knownBookmarkIds = allBookmarks.map((b) => b.id).toSet();

    state = TriageState(
      session: session,
      cards: cards,
      currentIndex: 0,
      isComplete: false,
      isLoading: false,
    );
  }

  Future<void> sortCard(int tier) async {
    if (state.isComplete) return;
    if (state.currentIndex >= state.cards.length) return;

    final bookmark = state.cards[state.currentIndex];

    // Save result to DB if session exists
    TriageResult? result;
    if (state.session != null) {
      try {
        final resultResponse = await supabase.from('triage_results').insert({
          'session_id': state.session!.id,
          'bookmark_id': bookmark.id,
          'tier': tier,
        }).select().single();
        result = TriageResult.fromJson(resultResponse);

        // Update session progress
        final newSorted = state.session!.sortedCards + 1;
        await supabase.from('triage_sessions').update({
          'sorted_cards': newSorted,
        }).eq('id', state.session!.id);
      } catch (_) {
        // DB not available, continue locally
      }
    }

    // Update bookmark tier in DB
    await _ref
        .read(bookmarkListProvider.notifier)
        .updateTier(bookmark.id, tier);

    final nextIndex = state.currentIndex + 1;
    final isComplete = nextIndex >= state.cards.length;

    if (isComplete && state.session != null) {
      try {
        await supabase.from('triage_sessions').update({
          'is_complete': true,
          'completed_at': DateTime.now().toIso8601String(),
        }).eq('id', state.session!.id);
      } catch (_) {
        // Ignore
      }
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      lastResult: result,
      lastResultBookmarkId: bookmark.id,
      isComplete: isComplete,
    );
  }

  void skipCard() {
    if (state.isComplete || state.currentIndex >= state.cards.length) return;

    final cards = List<Bookmark>.from(state.cards);
    final skipped = cards.removeAt(state.currentIndex);
    cards.add(skipped);

    state = state.copyWith(cards: cards, clearLastResult: true);
  }

  Future<void> undoLast() async {
    if (state.lastResultBookmarkId == null) return;
    if (state.currentIndex <= 0) return;

    // Delete the triage result from DB
    if (state.lastResult != null) {
      try {
        await supabase
            .from('triage_results')
            .delete()
            .eq('id', state.lastResult!.id);
      } catch (_) {}
    }

    // Revert bookmark tier
    try {
      await _ref
          .read(bookmarkListProvider.notifier)
          .updateTier(state.lastResultBookmarkId!, -1);
    } catch (_) {}

    // Update session progress
    if (state.session != null) {
      try {
        final newSorted = (state.session!.sortedCards - 1).clamp(0, 999);
        await supabase.from('triage_sessions').update({
          'sorted_cards': newSorted,
          'is_complete': false,
          'completed_at': null,
        }).eq('id', state.session!.id);
      } catch (_) {}
    }

    state = state.copyWith(
      currentIndex: state.currentIndex - 1,
      isComplete: false,
      clearLastResult: true,
    );
  }

  Future<void> startNewSession() async {
    state = state.copyWith(isLoading: true);
    final bookmarks = await _waitForBookmarks();
    await _createNewSession(bookmarks);
  }

  /// Add a newly registered bookmark to the current triage session.
  void addNewBookmark(Bookmark bookmark) {
    if (state.isLoading) return;

    // Don't add duplicates
    if (state.cards.any((c) => c.id == bookmark.id)) return;

    final cards = List<Bookmark>.from(state.cards);
    // Insert after current index so it appears soon
    final insertAt = state.currentIndex + 1;
    if (insertAt <= cards.length) {
      cards.insert(insertAt, bookmark);
    } else {
      cards.add(bookmark);
    }

    state = state.copyWith(
      cards: cards,
      isComplete: false,
    );
  }
}
