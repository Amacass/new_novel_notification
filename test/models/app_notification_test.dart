import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/models/app_notification.dart';

void main() {
  group('NotificationType', () {
    test('displayName returns Japanese text', () {
      expect(NotificationType.newEpisode.displayName, '新エピソード公開');
      expect(NotificationType.newNovelByAuthor.displayName, 'お気に入り作者の新作');
      expect(NotificationType.novelCompleted.displayName, '小説完結');
    });
  });

  group('AppNotification.fromJson', () {
    test('parses new_episode type', () {
      final json = {
        'id': 1,
        'user_id': 'user-123',
        'type': 'new_episode',
        'novel_id': 10,
        'author_id': null,
        'title': '新エピソード',
        'body': '第50話が公開されました',
        'is_read': false,
        'created_at': '2026-01-15T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 1);
      expect(notification.type, NotificationType.newEpisode);
      expect(notification.novelId, 10);
      expect(notification.title, '新エピソード');
      expect(notification.body, '第50話が公開されました');
      expect(notification.isRead, false);
    });

    test('parses new_novel_by_author type', () {
      final json = {
        'id': 2,
        'user_id': 'user-123',
        'type': 'new_novel_by_author',
        'novel_id': 20,
        'author_id': 5,
        'title': '新作公開',
        'body': null,
        'is_read': true,
        'created_at': '2026-01-15T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.type, NotificationType.newNovelByAuthor);
      expect(notification.authorId, 5);
      expect(notification.isRead, true);
      expect(notification.body, isNull);
    });

    test('parses novel_completed type', () {
      final json = {
        'id': 3,
        'user_id': 'user-123',
        'type': 'novel_completed',
        'title': '完結',
        'created_at': '2026-01-15T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.type, NotificationType.novelCompleted);
    });

    test('defaults unknown type to newEpisode', () {
      final json = {
        'id': 4,
        'user_id': 'user-123',
        'type': 'unknown_type',
        'title': 'テスト',
        'created_at': '2026-01-15T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.type, NotificationType.newEpisode);
    });

    test('defaults is_read to false when missing', () {
      final json = {
        'id': 5,
        'user_id': 'user-123',
        'type': 'new_episode',
        'title': 'テスト',
        'created_at': '2026-01-15T10:00:00Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.isRead, false);
    });
  });
}
