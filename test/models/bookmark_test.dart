import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/models/bookmark.dart';
import 'package:novel_notification/models/novel.dart';

void main() {
  final baseNovelJson = {
    'id': 1,
    'site': 'narou',
    'site_novel_id': 'n1234ab',
    'url': 'https://ncode.syosetu.com/n1234ab/',
    'title': 'テスト小説',
    'total_episodes': 100,
    'created_at': '2025-12-01T00:00:00Z',
    'updated_at': '2025-12-01T00:00:00Z',
  };

  group('Bookmark.fromJson', () {
    test('parses complete JSON with nested novel', () {
      final json = {
        'id': 1,
        'user_id': 'user-123',
        'novel_id': 1,
        'last_read_episode': 80,
        'memo': 'おもしろい',
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
        'novels': baseNovelJson,
        'reviews': {
          'id': 1,
          'user_id': 'user-123',
          'novel_id': 1,
          'rating': 4,
          'comment': '良い',
          'created_at': '2025-12-01T00:00:00Z',
          'updated_at': '2025-12-01T00:00:00Z',
        },
      };

      final bookmark = Bookmark.fromJson(json);

      expect(bookmark.id, 1);
      expect(bookmark.userId, 'user-123');
      expect(bookmark.lastReadEpisode, 80);
      expect(bookmark.memo, 'おもしろい');
      expect(bookmark.novel, isNotNull);
      expect(bookmark.novel!.title, 'テスト小説');
      expect(bookmark.review, isNotNull);
      expect(bookmark.review!.rating, 4);
    });

    test('handles null novel and review', () {
      final json = {
        'id': 2,
        'user_id': 'user-456',
        'novel_id': 1,
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final bookmark = Bookmark.fromJson(json);

      expect(bookmark.novel, isNull);
      expect(bookmark.review, isNull);
      expect(bookmark.lastReadEpisode, 0);
      expect(bookmark.memo, isNull);
    });
  });

  group('Bookmark.unreadCount', () {
    test('calculates unread count correctly', () {
      final bookmark = Bookmark(
        id: 1,
        userId: 'user-123',
        novelId: 1,
        lastReadEpisode: 80,
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
        novel: Novel(
          id: 1,
          site: NovelSite.narou,
          siteNovelId: 'n1234ab',
          url: 'https://ncode.syosetu.com/n1234ab/',
          totalEpisodes: 100,
          createdAt: DateTime(2025, 12, 1),
          updatedAt: DateTime(2025, 12, 1),
        ),
      );

      expect(bookmark.unreadCount, 20);
    });

    test('returns 0 when novel is null', () {
      final bookmark = Bookmark(
        id: 1,
        userId: 'user-123',
        novelId: 1,
        lastReadEpisode: 80,
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
      );

      expect(bookmark.unreadCount, 0);
    });

    test('returns 0 when fully caught up', () {
      final bookmark = Bookmark(
        id: 1,
        userId: 'user-123',
        novelId: 1,
        lastReadEpisode: 100,
        createdAt: DateTime(2025, 12, 1),
        updatedAt: DateTime(2025, 12, 1),
        novel: Novel(
          id: 1,
          site: NovelSite.narou,
          siteNovelId: 'n1234ab',
          url: 'https://ncode.syosetu.com/n1234ab/',
          totalEpisodes: 100,
          createdAt: DateTime(2025, 12, 1),
          updatedAt: DateTime(2025, 12, 1),
        ),
      );

      expect(bookmark.unreadCount, 0);
    });
  });

  group('Review.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 1,
        'user_id': 'user-123',
        'novel_id': 1,
        'rating': 5,
        'comment': '最高の作品',
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final review = Review.fromJson(json);

      expect(review.id, 1);
      expect(review.rating, 5);
      expect(review.comment, '最高の作品');
    });

    test('handles null rating and comment', () {
      final json = {
        'id': 2,
        'user_id': 'user-123',
        'novel_id': 1,
        'rating': null,
        'comment': null,
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final review = Review.fromJson(json);

      expect(review.rating, isNull);
      expect(review.comment, isNull);
    });
  });
}
