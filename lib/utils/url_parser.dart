import '../models/novel.dart';

class ParsedNovelUrl {
  final NovelSite site;
  final String siteNovelId;
  final String normalizedUrl;
  final int? episodeNumber;

  const ParsedNovelUrl({
    required this.site,
    required this.siteNovelId,
    required this.normalizedUrl,
    this.episodeNumber,
  });
}

class NovelUrlParser {
  static ParsedNovelUrl? parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // 小説家になろう
    if (uri.host == 'ncode.syosetu.com') {
      final match =
          RegExp(r'/([nN]\d+[a-zA-Z]+)(?:/(\d+))?').firstMatch(uri.path);
      if (match != null) {
        final ncode = match.group(1)!.toLowerCase();
        final episode =
            match.group(2) != null ? int.tryParse(match.group(2)!) : null;
        return ParsedNovelUrl(
          site: NovelSite.narou,
          siteNovelId: ncode,
          normalizedUrl: 'https://ncode.syosetu.com/$ncode/',
          episodeNumber: episode,
        );
      }
    }

    // ハーメルン
    if (uri.host == 'syosetu.org') {
      final match =
          RegExp(r'/novel/(\d+)(?:/(\d+)\.html)?').firstMatch(uri.path);
      if (match != null) {
        final novelId = match.group(1)!;
        final episode =
            match.group(2) != null ? int.tryParse(match.group(2)!) : null;
        return ParsedNovelUrl(
          site: NovelSite.hameln,
          siteNovelId: novelId,
          normalizedUrl: 'https://syosetu.org/novel/$novelId/',
          episodeNumber: episode,
        );
      }
    }

    // Arcadia
    if (uri.host == 'www.mai-net.net') {
      final all = uri.queryParameters['all'];
      final cate = uri.queryParameters['cate'];
      if (all != null && cate != null) {
        final n = uri.queryParameters['n'];
        final episode = n != null ? int.tryParse(n) : null;
        return ParsedNovelUrl(
          site: NovelSite.arcadia,
          siteNovelId: '${cate}_$all',
          normalizedUrl:
              'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=$cate&all=$all',
          episodeNumber: episode,
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
