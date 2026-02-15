import '../models/novel.dart';

class ParsedNovelUrl {
  final NovelSite site;
  final String siteNovelId;
  final String normalizedUrl;

  const ParsedNovelUrl({
    required this.site,
    required this.siteNovelId,
    required this.normalizedUrl,
  });
}

class NovelUrlParser {
  static ParsedNovelUrl? parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // 小説家になろう
    if (uri.host == 'ncode.syosetu.com') {
      final match = RegExp(r'/([nN]\d+[a-zA-Z]+)').firstMatch(uri.path);
      if (match != null) {
        final ncode = match.group(1)!.toLowerCase();
        return ParsedNovelUrl(
          site: NovelSite.narou,
          siteNovelId: ncode,
          normalizedUrl: 'https://ncode.syosetu.com/$ncode/',
        );
      }
    }

    // ハーメルン
    if (uri.host == 'syosetu.org') {
      final match = RegExp(r'/novel/(\d+)').firstMatch(uri.path);
      if (match != null) {
        final novelId = match.group(1)!;
        return ParsedNovelUrl(
          site: NovelSite.hameln,
          siteNovelId: novelId,
          normalizedUrl: 'https://syosetu.org/novel/$novelId/',
        );
      }
    }

    // Arcadia
    if (uri.host == 'www.mai-net.net') {
      final all = uri.queryParameters['all'];
      final cate = uri.queryParameters['cate'];
      if (all != null && cate != null) {
        return ParsedNovelUrl(
          site: NovelSite.arcadia,
          siteNovelId: '${cate}_$all',
          normalizedUrl:
              'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=$cate&all=$all',
        );
      }
    }

    return null;
  }

  static bool isSupported(String url) {
    return parse(url) != null;
  }

  static String? getSiteName(String url) {
    return parse(url)?.site.displayName;
  }
}
