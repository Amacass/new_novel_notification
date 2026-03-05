import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/bookmark.dart';
import '../../providers/bookmark_provider.dart';
import '../../widgets/bookshelf_card.dart';

enum BookshelfSort { heatScore, updatedAt, title, createdAt }

class BookshelfScreen extends ConsumerStatefulWidget {
  final int? initialTier;

  const BookshelfScreen({super.key, this.initialTier});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  int? _selectedTier; // null = all, -1 = unsorted, 0-3 = tier
  BookshelfSort _sort = BookshelfSort.heatScore;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showSearch = false;

  // Additional filter flags
  bool _completedOnly = false;
  bool _longSeriesOnly = false; // 100+ episodes

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialTier;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Bookmark> _filterAndSort(List<Bookmark> bookmarks) {
    var filtered = bookmarks.where((b) {
      // Tier filter
      if (_selectedTier != null && b.tier != _selectedTier) return false;

      // Completed filter
      if (_completedOnly && b.novel?.serialStatus.name != 'completed') {
        return false;
      }

      // Long series filter
      if (_longSeriesOnly && (b.novel?.totalEpisodes ?? 0) < 100) {
        return false;
      }

      // Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (b.novel?.title ?? '').toLowerCase();
        final author = (b.novel?.authorName ?? '').toLowerCase();
        if (!title.contains(query) && !author.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sort
    switch (_sort) {
      case BookshelfSort.heatScore:
        filtered.sort((a, b) => b.heatScore.compareTo(a.heatScore));
      case BookshelfSort.updatedAt:
        filtered.sort((a, b) {
          final aDate = a.novel?.siteUpdatedAt ?? a.updatedAt;
          final bDate = b.novel?.siteUpdatedAt ?? b.updatedAt;
          return bDate.compareTo(aDate);
        });
      case BookshelfSort.title:
        filtered.sort((a, b) {
          final aTitle = a.novel?.title ?? '';
          final bTitle = b.novel?.title ?? '';
          return aTitle.compareTo(bTitle);
        });
      case BookshelfSort.createdAt:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'タイトル・作者名で検索',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('本棚'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          PopupMenuButton<BookshelfSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => [
              _sortItem(BookshelfSort.heatScore, '熱量順'),
              _sortItem(BookshelfSort.updatedAt, '更新日'),
              _sortItem(BookshelfSort.title, 'タイトル'),
              _sortItem(BookshelfSort.createdAt, '登録日'),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _filterChip('全て', _selectedTier == null, () {
                  setState(() => _selectedTier = null);
                }),
                _filterChip('👑 殿堂入り', _selectedTier == 3, () {
                  setState(() => _selectedTier = _selectedTier == 3 ? null : 3);
                }),
                _filterChip('⭐ 良作', _selectedTier == 2, () {
                  setState(() => _selectedTier = _selectedTier == 2 ? null : 2);
                }),
                _filterChip('📌 キープ', _selectedTier == 1, () {
                  setState(() => _selectedTier = _selectedTier == 1 ? null : 1);
                }),
                _filterChip('📋 未仕分け', _selectedTier == -1, () {
                  setState(
                      () => _selectedTier = _selectedTier == -1 ? null : -1);
                }),
                _filterChip('完結済', _completedOnly, () {
                  setState(() => _completedOnly = !_completedOnly);
                }),
                _filterChip('長編(100話+)', _longSeriesOnly, () {
                  setState(() => _longSeriesOnly = !_longSeriesOnly);
                }),
              ],
            ),
          ),

          // List
          Expanded(
            child: bookmarksAsync.when(
              data: (bookmarks) {
                final filtered = _filterAndSort(bookmarks);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('該当する作品がありません'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(bookmarkListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final bookmark = filtered[index];
                      return BookshelfCard(
                        bookmark: bookmark,
                        onTap: () =>
                            context.push('/novel/${bookmark.novelId}'),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  PopupMenuItem<BookshelfSort> _sortItem(BookshelfSort sort, String label) {
    return PopupMenuItem(
      value: sort,
      child: Row(
        children: [
          if (_sort == sort)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
