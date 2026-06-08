import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/bookmark.dart';
import '../models/novel.dart';
import '../utils/url_parser.dart';

final novelDetailProvider =
    FutureProvider.family<Novel?, int>((ref, novelId) async {
  final response = await supabase
      .from('novels')
      .select()
      .eq('id', novelId)
      .maybeSingle();

  if (response == null) return null;
  return Novel.fromJson(response);
});

final novelReviewProvider =
    FutureProvider.family<Review?, int>((ref, novelId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await supabase
      .from('reviews')
      .select()
      .eq('user_id', userId)
      .eq('novel_id', novelId)
      .maybeSingle();

  if (response == null) return null;
  return Review.fromJson(response);
});

final registerNovelProvider = Provider<RegisterNovelService>((ref) {
  return RegisterNovelService();
});

class RegisterNovelService {
  final _dio = Dio();

  /// Returns (novel, isNewNovel). isNewNovel is false when the novel was
  /// already in the DB (registered by another user or a prior crawl).
  Future<(Novel?, bool)> registerFromUrl(String url) async {
    final parsed = NovelUrlParser.parse(url);
    if (parsed == null) return (null, false);

    // Check if novel already exists
    final existing = await supabase
        .from('novels')
        .select()
        .eq('site', parsed.site.name)
        .eq('site_novel_id', parsed.siteNovelId)
        .maybeSingle();

    if (existing != null) {
      final existingNovel = Novel.fromJson(existing);
      // If title/author are placeholders or episode count is missing, fix them
      if (existingNovel.title == '不明なタイトル' ||
          existingNovel.authorName == null ||
          existingNovel.totalEpisodes == 0) {
        final metadata =
            await _fetchMetadata(parsed.site, parsed.siteNovelId);
        if (metadata != null) {
          final updates = <String, dynamic>{
            if (existingNovel.title == '不明なタイトル' &&
                metadata['title'] != null)
              'title': metadata['title'],
            if (existingNovel.authorName == null &&
                metadata['author'] != null)
              'author_name': metadata['author'],
            if (existingNovel.totalEpisodes == 0 &&
                (metadata['total_episodes'] as int? ?? 0) > 0)
              'total_episodes': metadata['total_episodes'],
          };
          if (updates.isNotEmpty) {
            await supabase
                .from('novels')
                .update(updates)
                .eq('id', existingNovel.id);
            final updatedRows = await supabase
                .from('novels')
                .select()
                .eq('id', existingNovel.id)
                .limit(1);
            if (updatedRows.isNotEmpty) {
              return (Novel.fromJson(updatedRows.first), false);
            }
          }
        }
      }
      return (existingNovel, false);
    }

    // Fetch metadata from the novel site
    final metadata = await _fetchMetadata(parsed.site, parsed.siteNovelId);

    // Insert without chaining .select() to avoid PGRST116 bug in postgrest-dart
    // with non-GET requests and maybeSingle/single.
    await supabase.from('novels').insert({
      'site': parsed.site.name,
      'site_novel_id': parsed.siteNovelId,
      'url': parsed.normalizedUrl,
      'title': metadata?['title'] ?? '不明なタイトル',
      'author_name': metadata?['author'],
      'total_episodes': metadata?['total_episodes'] ?? 0,
      'last_crawled_at': DateTime.now().toIso8601String(),
    });

    // Fetch the newly inserted row via a regular GET
    final rows = await supabase
        .from('novels')
        .select()
        .eq('site', parsed.site.name)
        .eq('site_novel_id', parsed.siteNovelId)
        .limit(1);

    if (rows.isEmpty) throw Exception('小説の登録に失敗しました');
    return (Novel.fromJson(rows.first), true);
  }

  Future<Map<String, dynamic>?> _fetchMetadata(
      NovelSite site, String siteNovelId) async {
    try {
      switch (site) {
        case NovelSite.narou:
          return await _fetchNarouMetadata(siteNovelId);
        case NovelSite.hameln:
          return await _fetchHamelnMetadata(siteNovelId);
        case NovelSite.arcadia:
          return await _fetchArcadiaMetadata(siteNovelId);
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchNarouMetadata(String ncode) async {
    final response = await _dio.get(
      'https://api.syosetu.com/novelapi/api/',
      queryParameters: {
        'ncode': ncode,
        'of': 't-w-ga',
        'out': 'json',
        'lim': '1',
      },
    );

    final data = response.data;
    final List<dynamic> list =
        data is String ? jsonDecode(data) : data;
    if (list.length < 2) return null;

    final novel = list[1];
    return {
      'title': novel['title'] as String?,
      'author': novel['writer'] as String?,
      'total_episodes': novel['general_all_no'] as int? ?? 0,
    };
  }

  Future<Map<String, dynamic>?> _fetchHamelnMetadata(String novelId) async {
    final response = await _dio.get(
      'https://syosetu.org/novel/$novelId/',
      options: Options(
        headers: {
          'User-Agent': 'NovelmarkApp/1.0',
          'Cookie': 'over18=off',
        },
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data as String;

    // Extract title from og:title (format: "小説名 - ハーメルン")
    String? title;
    final ogTitleMatch =
        RegExp(r'<meta\s+property="og:title"\s+content="(.+?)"')
            .firstMatch(html);
    if (ogTitleMatch != null) {
      title = _decodeHtmlEntities(ogTitleMatch.group(1)!);
      // Remove " - ハーメルン" suffix
      final suffixIdx = title.lastIndexOf(' - ハーメルン');
      if (suffixIdx > 0) {
        title = title.substring(0, suffixIdx);
      }
    }

    // Fallback: try <title> tag
    if (title == null || title.isEmpty) {
      final titleTagMatch =
          RegExp(r'<title>(.+?)</title>').firstMatch(html);
      if (titleTagMatch != null) {
        title = _decodeHtmlEntities(titleTagMatch.group(1)!);
        final suffixIdx = title.lastIndexOf(' - ハーメルン');
        if (suffixIdx > 0) {
          title = title.substring(0, suffixIdx);
        }
      }
    }

    // Extract author: try itemprop="author" span first, then 作者：<a>
    String? author;
    final authorSpanMatch =
        RegExp(r'<span\s+itemprop="author">(.+?)</span>')
            .firstMatch(html);
    if (authorSpanMatch != null) {
      author = _decodeHtmlEntities(authorSpanMatch.group(1)!);
    } else {
      final authorLinkMatch =
          RegExp(r'作者：(?:<span[^>]*>)?<a[^>]*>(.+?)</a>')
              .firstMatch(html);
      if (authorLinkMatch != null) {
        author = _decodeHtmlEntities(authorLinkMatch.group(1)!);
      }
    }

    // Count episodes
    final episodeMatches =
        RegExp(r'<a\s+href="/novel/\d+/(\d+)\.html"').allMatches(html);
    final totalEpisodes = episodeMatches.length;

    return {
      'title': title,
      'author': author,
      'total_episodes': totalEpisodes,
    };
  }

  Future<Map<String, dynamic>?> _fetchArcadiaMetadata(String siteNovelId) async {
    // siteNovelId format: "{cate}_{storyId}"
    final parts = siteNovelId.split('_');
    if (parts.length < 2) return null;
    final cate = parts[0];
    final storyId = parts.sublist(1).join('_');
    final url =
        'http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=$cate&all=$storyId';

    final response = await _dio.get(
      url,
      options: Options(
        headers: {'User-Agent': 'NovelmarkApp/1.0'},
        responseType: ResponseType.bytes,
      ),
    );
    final bytes = response.data as List<int>;
    final html = utf8.decode(bytes);

    // Title: link text in the [0] row
    String? title;
    final titleMatch = RegExp(
      r'\[0\]</td><td[^>]*>(?:<b>)?(?:\s|<br\s*/?>)*<a[^>]+>(.+?)</a>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      title = _decodeHtmlEntities(titleMatch.group(1)!).trim();
    } else {
      // Fallback: plain text after [0]</td><td>
      final plainMatch =
          RegExp(r'\[0\]</td><td[^>]*>(?:<b>)?([^<\n]+)').firstMatch(html);
      if (plainMatch != null) {
        title = _decodeHtmlEntities(plainMatch.group(1)!).trim();
      }
    }

    // Author: "Name: 作者名◆ID" pattern in post body
    String? author;
    final nameMatch = RegExp(r'<tt>Name:\s*([^◆<\n]+)').firstMatch(html);
    if (nameMatch != null) {
      author = _decodeHtmlEntities(nameMatch.group(1)!).trim();
    } else {
      final bracketMatch = RegExp(
        r'\[0\]</td><td[^>]*>.*?</td><td[^>]*>\[([^\]]+)\]',
        dotAll: true,
      ).firstMatch(html);
      if (bracketMatch != null) {
        author = _decodeHtmlEntities(bracketMatch.group(1)!).trim();
      }
    }

    // Episode count from [N]</td> pattern
    final episodeMatches =
        RegExp(r'\[(\d+)\]</td>').allMatches(html);
    final episodeNumbers = episodeMatches
        .map((m) => int.tryParse(m.group(1)!) ?? 0)
        .where((n) => n > 0)
        .toList();
    final totalEpisodes =
        episodeNumbers.isNotEmpty ? episodeNumbers.reduce((a, b) => a > b ? a : b) : 0;

    return {
      'title': title,
      'author': author,
      'total_episodes': totalEpisodes,
    };
  }

  String _decodeHtmlEntities(String str) {
    return str
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  Future<void> upsertReview({
    required int novelId,
    int? rating,
    String? comment,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('reviews').upsert({
      'user_id': userId,
      'novel_id': novelId,
      'rating': rating,
      'comment': comment,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,novel_id');
  }
}
