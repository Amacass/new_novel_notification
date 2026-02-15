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

    // Insert new novel
    final response = await supabase.from('novels').insert({
      'site': parsed.site.name,
      'site_novel_id': parsed.siteNovelId,
      'url': parsed.normalizedUrl,
      'title': '取得中...',
    }).select().single();

    return Novel.fromJson(response);
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
