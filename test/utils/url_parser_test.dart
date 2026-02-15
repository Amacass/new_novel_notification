import 'package:flutter_test/flutter_test.dart';
import 'package:novel_notification/utils/url_parser.dart';
import 'package:novel_notification/models/novel.dart';

void main() {
  group('NovelUrlParser.parse', () {
    group('narou', () {
      test('parses standard narou URL', () {
        final result =
            NovelUrlParser.parse('https://ncode.syosetu.com/n1234ab/');
        expect(result, isNotNull);
        expect(result!.site, NovelSite.narou);
        expect(result.siteNovelId, 'n1234ab');
        expect(result.normalizedUrl,
            'https://ncode.syosetu.com/n1234ab/');
      });

      test('parses narou URL without trailing slash', () {
        final result =
            NovelUrlParser.parse('https://ncode.syosetu.com/n1234ab');
        expect(result, isNotNull);
        expect(result!.site, NovelSite.narou);
        expect(result.siteNovelId, 'n1234ab');
      });

      test('lowercases uppercase ncode', () {
        final result =
            NovelUrlParser.parse('https://ncode.syosetu.com/N1234AB/');
        expect(result, isNotNull);
        expect(result!.siteNovelId, 'n1234ab');
      });

      test('parses narou URL with episode path', () {
        final result =
            NovelUrlParser.parse('https://ncode.syosetu.com/n1234ab/5/');
        expect(result, isNotNull);
        expect(result!.siteNovelId, 'n1234ab');
      });
    });

    group('hameln', () {
      test('parses standard hameln URL', () {
        final result =
            NovelUrlParser.parse('https://syosetu.org/novel/123456/');
        expect(result, isNotNull);
        expect(result!.site, NovelSite.hameln);
        expect(result.siteNovelId, '123456');
        expect(result.normalizedUrl,
            'https://syosetu.org/novel/123456/');
      });

      test('parses hameln URL without trailing slash', () {
        final result =
            NovelUrlParser.parse('https://syosetu.org/novel/123456');
        expect(result, isNotNull);
        expect(result!.siteNovelId, '123456');
      });
    });

    group('arcadia', () {
      test('parses standard arcadia URL', () {
        final result = NovelUrlParser.parse(
            'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=naruto&all=12345');
        expect(result, isNotNull);
        expect(result!.site, NovelSite.arcadia);
        expect(result.siteNovelId, 'naruto_12345');
        expect(result.normalizedUrl,
            'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=naruto&all=12345');
      });

      test('returns null when missing all param', () {
        final result = NovelUrlParser.parse(
            'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=naruto');
        expect(result, isNull);
      });

      test('returns null when missing cate param', () {
        final result = NovelUrlParser.parse(
            'http://www.mai-net.net/bbs/sst/sst.php?act=dump&all=12345');
        expect(result, isNull);
      });
    });

    group('unsupported', () {
      test('returns null for unsupported URL', () {
        final result =
            NovelUrlParser.parse('https://example.com/novel/123');
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = NovelUrlParser.parse('');
        expect(result, isNull);
      });

      test('returns null for invalid URL', () {
        final result = NovelUrlParser.parse('not a url');
        expect(result, isNull);
      });
    });
  });

  group('NovelUrlParser.isSupported', () {
    test('returns true for supported URL', () {
      expect(
        NovelUrlParser.isSupported('https://ncode.syosetu.com/n1234ab/'),
        isTrue,
      );
    });

    test('returns false for unsupported URL', () {
      expect(
        NovelUrlParser.isSupported('https://example.com/'),
        isFalse,
      );
    });
  });

  group('NovelUrlParser.getSiteName', () {
    test('returns site name for narou', () {
      expect(
        NovelUrlParser.getSiteName('https://ncode.syosetu.com/n1234ab/'),
        '小説家になろう',
      );
    });

    test('returns null for unsupported URL', () {
      expect(
        NovelUrlParser.getSiteName('https://example.com/'),
        isNull,
      );
    });
  });
}
