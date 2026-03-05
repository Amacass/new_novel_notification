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

  Future<Novel?> registerFromUrl(String url) async {
    final parsed = NovelUrlParser.parse(url);
    if (parsed == null) return null;

    // Check if novel already exists
    final existing = await supabase
        .from('novels')
        .select()
        .eq('site', parsed.site.name)
        .eq('site_novel_id', parsed.siteNovelId)
        .maybeSingle();

    if (existing != null) {
      return Novel.fromJson(existing);
    }

    // Fetch metadata from the novel site
    final metadata = await _fetchMetadata(parsed.site, parsed.siteNovelId);

    // Insert new novel with fetched metadata
    final response = await supabase.from('novels').insert({
      'site': parsed.site.name,
      'site_novel_id': parsed.siteNovelId,
      'url': parsed.normalizedUrl,
      'title': metadata?['title'] ?? '不明なタイトル',
      'author_name': metadata?['author'],
      'total_episodes': metadata?['total_episodes'] ?? 0,
      'last_crawled_at': DateTime.now().toIso8601String(),
    }).select().single();

    return Novel.fromJson(response);
  }

  Future<Map<String, dynamic>?> _fetchMetadata(
      NovelSite site, String siteNovelId) async {
    try {
      switch (site) {
        case NovelSite.narou:
          return _fetchNarouMetadata(siteNovelId);
        case NovelSite.hameln:
          return _fetchHamelnMetadata(siteNovelId);
        case NovelSite.arcadia:
          return null; // Arcadia is HTTP only, skip for now
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
          'User-Agent': 'NovelNotificationApp/1.0',
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
