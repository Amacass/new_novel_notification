import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/amazon_link.dart';

final novelAmazonLinksProvider =
    FutureProvider.family<List<AmazonLink>, int>((ref, novelId) async {
  final rows = await supabase
      .from('amazon_links')
      .select()
      .eq('novel_id', novelId)
      .order('sort_order');
  return (rows as List).map((r) => AmazonLink.fromJson(r)).toList();
});
