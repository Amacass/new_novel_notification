import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase.dart';
import '../models/category.dart';

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<BookshelfCategory>>(
  CategoryListNotifier.new,
);

class CategoryListNotifier extends AsyncNotifier<List<BookshelfCategory>> {
  @override
  Future<List<BookshelfCategory>> build() async {
    return _fetch();
  }

  Future<List<BookshelfCategory>> _fetch() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await supabase
        .from('user_categories')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => BookshelfCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<BookshelfCategory> create(String name, String color) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('ログインが必要です');

    final response = await supabase
        .from('user_categories')
        .insert({'user_id': userId, 'name': name, 'color': color})
        .select()
        .single();

    final category = BookshelfCategory.fromJson(response);
    state = state.whenData((cats) => [...cats, category]);
    return category;
  }

  Future<void> rename(int id, String name) async {
    await supabase
        .from('user_categories')
        .update({'name': name}).eq('id', id);
    state = state.whenData(
      (cats) => cats
          .map((c) => c.id == id ? c.copyWith(name: name) : c)
          .toList(),
    );
  }

  Future<void> updateColor(int id, String color) async {
    await supabase
        .from('user_categories')
        .update({'color': color}).eq('id', id);
    state = state.whenData(
      (cats) => cats
          .map((c) => c.id == id ? c.copyWith(color: color) : c)
          .toList(),
    );
  }

  Future<void> delete(int id) async {
    await supabase.from('user_categories').delete().eq('id', id);
    state = state.whenData((cats) => cats.where((c) => c.id != id).toList());
  }
}
