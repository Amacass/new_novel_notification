import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/models/novel.dart';

void main() {
  group('NovelSite', () {
    test('displayName returns Japanese name', () {
      expect(NovelSite.narou.displayName, '小説家になろう');
      expect(NovelSite.hameln.displayName, 'ハーメルン');
      expect(NovelSite.arcadia.displayName, 'Arcadia');
    });

    test('shortLabel returns single letter', () {
      expect(NovelSite.narou.shortLabel, 'N');
      expect(NovelSite.hameln.shortLabel, 'H');
      expect(NovelSite.arcadia.shortLabel, 'A');
    });
  });

  group('SerialStatus', () {
    test('displayName returns Japanese status', () {
      expect(SerialStatus.ongoing.displayName, '連載中');
      expect(SerialStatus.completed.displayName, '完結');
      expect(SerialStatus.hiatus.displayName, '長期未更新');
    });
  });

  group('Novel.fromJson', () {
    test('parses complete JSON', () {
      final json = {
        'id': 1,
        'site': 'narou',
        'site_novel_id': 'n1234ab',
        'url': 'https://ncode.syosetu.com/n1234ab/',
        'title': 'テスト小説',
        'author_name': 'テスト作者',
        'author_id': 10,
        'synopsis': 'あらすじ',
        'total_episodes': 50,
        'latest_episode_id': '50',
        'latest_episode_title': '第50話',
        'serial_status': 'ongoing',
        'site_updated_at': '2026-01-01T00:00:00Z',
        'last_crawled_at': '2026-01-01T12:00:00Z',
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2026-01-01T12:00:00Z',
      };

      final novel = Novel.fromJson(json);

      expect(novel.id, 1);
      expect(novel.site, NovelSite.narou);
      expect(novel.siteNovelId, 'n1234ab');
      expect(novel.title, 'テスト小説');
      expect(novel.authorName, 'テスト作者');
      expect(novel.totalEpisodes, 50);
      expect(novel.serialStatus, SerialStatus.ongoing);
      expect(novel.siteUpdatedAt, isNotNull);
    });

    test('handles null optional fields', () {
      final json = {
        'id': 2,
        'site': 'hameln',
        'site_novel_id': '999',
        'url': 'https://syosetu.org/novel/999/',
        'title': null,
        'author_name': null,
        'total_episodes': null,
        'serial_status': null,
        'site_updated_at': null,
        'last_crawled_at': null,
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final novel = Novel.fromJson(json);

      expect(novel.title, isNull);
      expect(novel.authorName, isNull);
      expect(novel.totalEpisodes, 0);
      expect(novel.serialStatus, SerialStatus.ongoing);
      expect(novel.siteUpdatedAt, isNull);
    });

    test('defaults serial_status to ongoing for unknown value', () {
      final json = {
        'id': 3,
        'site': 'arcadia',
        'site_novel_id': 'test_1',
        'url': 'http://www.mai-net.net/bbs/sst/sst.php',
        'serial_status': 'unknown_status',
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final novel = Novel.fromJson(json);
      expect(novel.serialStatus, SerialStatus.ongoing);
    });

    test('parses completed serial status', () {
      final json = {
        'id': 4,
        'site': 'narou',
        'site_novel_id': 'n9999zz',
        'url': 'https://ncode.syosetu.com/n9999zz/',
        'serial_status': 'completed',
        'created_at': '2025-12-01T00:00:00Z',
        'updated_at': '2025-12-01T00:00:00Z',
      };

      final novel = Novel.fromJson(json);
      expect(novel.serialStatus, SerialStatus.completed);
    });
  });
}
