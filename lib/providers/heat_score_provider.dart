import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bookmark.dart';
import '../models/stamp.dart';
import '../providers/bookmark_provider.dart';
import '../providers/stamp_provider.dart';

final heatScoreServiceProvider = Provider<HeatScoreService>((ref) {
  return HeatScoreService(ref);
});

class HeatScoreService {
  final Ref _ref;

  HeatScoreService(this._ref);

  /// Calculate heat score for a bookmark.
  ///
  /// heat_score =
  ///   3.0 * (30 - days_since_last_stamp).clamp(0,30) / 30
  /// + 2.0 * stamps_last_30_days.clamp(0,10) / 10
  /// + 2.5 * (7 - days_since_site_update).clamp(0,7) / 7
  /// + 1.5 * unread_count.clamp(0,20) / 20
  /// - 1.0 * days_since_last_read.clamp(0,60) / 60
  double calculateScore(Bookmark bookmark, List<EmotionStamp> stamps) {
    final now = DateTime.now();

    // Days since last stamp
    final daysSinceLastStamp = bookmark.lastStampedAt != null
        ? now.difference(bookmark.lastStampedAt!).inDays
        : 30;

    // Stamps in last 30 days
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final stampsLast30 =
        stamps.where((s) => s.createdAt.isAfter(thirtyDaysAgo)).length;

    // Days since site update
    final daysSinceSiteUpdate = bookmark.novel?.siteUpdatedAt != null
        ? now.difference(bookmark.novel!.siteUpdatedAt!).inDays
        : 7;

    // Unread count
    final unreadCount = bookmark.unreadCount;

    // Days since last read (approximated by updatedAt)
    final daysSinceLastRead = now.difference(bookmark.updatedAt).inDays;

    final score = 3.0 * (30 - daysSinceLastStamp).clamp(0, 30) / 30 +
        2.0 * stampsLast30.clamp(0, 10) / 10 +
        2.5 * (7 - daysSinceSiteUpdate).clamp(0, 7) / 7 +
        1.5 * unreadCount.clamp(0, 20) / 20 -
        1.0 * daysSinceLastRead.clamp(0, 60) / 60;

    return score;
  }

  /// Recalculate heat scores for all bookmarks
  Future<void> recalculateAll() async {
    final bookmarks = _ref.read(bookmarkListProvider).valueOrNull ?? [];
    if (bookmarks.isEmpty) return;

    for (final bookmark in bookmarks) {
      final stamps =
          await _ref.read(novelStampsProvider(bookmark.novelId).future);
      final score = calculateScore(bookmark, stamps);
      await _ref
          .read(bookmarkListProvider.notifier)
          .updateHeatScore(bookmark.id, score);
    }
  }
}
