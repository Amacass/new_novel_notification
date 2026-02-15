import 'package:flutter_test/flutter_test.dart';

import 'package:novel_notification/utils/url_parser.dart';
import 'package:novel_notification/models/novel.dart';

void main() {
  group('NovelUrlParser', () {
    test('parses narou URL correctly', () {
      final result =
          NovelUrlParser.parse('https://ncode.syosetu.com/n1234ab/');
      expect(result, isNotNull);
      expect(result!.site, NovelSite.narou);
      expect(result.siteNovelId, 'n1234ab');
    });

    test('parses hameln URL correctly', () {
      final result =
          NovelUrlParser.parse('https://syosetu.org/novel/123456/');
      expect(result, isNotNull);
      expect(result!.site, NovelSite.hameln);
      expect(result.siteNovelId, '123456');
    });

    test('parses arcadia URL correctly', () {
      final result = NovelUrlParser.parse(
          'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=naruto&all=12345');
      expect(result, isNotNull);
      expect(result!.site, NovelSite.arcadia);
      expect(result.siteNovelId, 'naruto_12345');
    });

    test('returns null for unsupported URL', () {
      final result =
          NovelUrlParser.parse('https://example.com/novel/123');
      expect(result, isNull);
    });
  });
}
