import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/bookmark.dart';
import '../../models/novel.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../utils/error_message.dart';
import '../../widgets/bookshelf_card.dart';
import '../../widgets/category_pick_sheet.dart';
import '../../widgets/site_badge.dart';
import '../../widgets/tier_change_sheet.dart';

enum BookshelfSort { heatScore, updatedAt, title, createdAt }

class BookshelfScreen extends ConsumerStatefulWidget {
  final int? initialTier;

  const BookshelfScreen({super.key, this.initialTier});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  int? _selectedTier; // null = all, -1 = unsorted, 0-3 = tier
  BookmarkGenre? _genreFilter; // null = all genres
  bool _genreFilterActive = false; // true when unclassified is explicitly selected
  BookshelfSort _sort = BookshelfSort.heatScore;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showSearch = false;
  bool _longSeriesOnly = false; // 100+ episodes
  String? _stampFilter; // selected emoji or null
  Set<int> _selectedCategoryIds = {};
  Set<NovelSite> _siteFilter = {};

  static const _stampEmojis = ['🔥', '😭', '🌿', '😍', '🤯'];

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

  List<Bookmark> _filterAndSort(
      List<Bookmark> bookmarks, Map<int, Set<String>> stampMap) {
    var filtered = bookmarks.where((b) {
      if (b.tier == 0) return false; // always hide trash
      if (_selectedTier != null && b.tier != _selectedTier) return false;
      if (_genreFilterActive) {
        // 未分類フィルター
        if (b.genre != null) return false;
      } else if (_genreFilter != null && b.genre != _genreFilter) {
        return false;
      }

      if (_longSeriesOnly && (b.novel?.totalEpisodes ?? 0) < 100) return false;

      if (_stampFilter != null) {
        final emojis = stampMap[b.novelId];
        if (emojis == null || !emojis.contains(_stampFilter)) return false;
      }

      if (_selectedCategoryIds.isNotEmpty) {
        final bookmarkCategoryIds = b.categories.map((c) => c.id).toSet();
        if (bookmarkCategoryIds.intersection(_selectedCategoryIds).isEmpty) {
          return false;
        }
      }

      if (_siteFilter.isNotEmpty && !_siteFilter.contains(b.novel?.site)) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (b.novel?.title ?? '').toLowerCase();
        final author = (b.novel?.authorName ?? '').toLowerCase();
        if (!title.contains(query) && !author.contains(query)) return false;
      }

      return true;
    }).toList();

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

  bool get _isFilterActive =>
      _selectedTier != null ||
      _genreFilter != null ||
      _genreFilterActive ||
      _longSeriesOnly ||
      _stampFilter != null ||
      _selectedCategoryIds.isNotEmpty ||
      _siteFilter.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);
    final stampMapAsync = ref.watch(allUserStampsProvider);
    final stampMap = stampMapAsync.valueOrNull ?? {};

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
                _filterChip('全て', !_isFilterActive, () {
                  setState(() {
                    _selectedTier = null;
                    _genreFilter = null;
                    _genreFilterActive = false;
                    _longSeriesOnly = false;
                    _stampFilter = null;
                    _selectedCategoryIds = {};
                    _siteFilter = {};
                  });
                }),
                // Category filter
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                const SizedBox(width: 4),
                _categoryFilterChip(),
                // Site filter
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                const SizedBox(width: 4),
                for (final site in NovelSite.values) _siteFilterChip(site),
                // Genre filters
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                const SizedBox(width: 4),
                _filterChip('📖 オリジナル', _genreFilter == BookmarkGenre.original, () {
                  setState(() {
                    _genreFilterActive = false;
                    _genreFilter = _genreFilter == BookmarkGenre.original
                        ? null
                        : BookmarkGenre.original;
                  });
                }),
                _filterChip('🎭 二次創作', _genreFilter == BookmarkGenre.derivative, () {
                  setState(() {
                    _genreFilterActive = false;
                    _genreFilter = _genreFilter == BookmarkGenre.derivative
                        ? null
                        : BookmarkGenre.derivative;
                  });
                }),
                // Tier / series filters
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                const SizedBox(width: 4),
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
                _filterChip('長編(100話+)', _longSeriesOnly, () {
                  setState(() => _longSeriesOnly = !_longSeriesOnly);
                }),
                _filterChip('❓ 未分類', _genreFilterActive, () {
                  setState(() {
                    _genreFilter = null;
                    _genreFilterActive = !_genreFilterActive;
                  });
                }),
                // Stamp emoji filter (single chip)
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                const SizedBox(width: 4),
                _stampFilterChip(),
              ],
            ),
          ),

          // List
          Expanded(
            child: bookmarksAsync.when(
              data: (bookmarks) {
                final filtered = _filterAndSort(bookmarks, stampMap);
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
                        onReadTap: bookmark.novel != null
                            ? () => _openReadUrl(bookmark)
                            : null,
                        onLongPress: () async {
                          final result =
                              await TierChangeSheet.showWithDelete(
                            context,
                            currentTier: bookmark.tier,
                          );
                          if (result == null) return;
                          if (result.delete) {
                            if (!context.mounted) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('ブックマークを削除'),
                                content: Text(
                                    '「${bookmark.novel?.title ?? "この作品"}」を本棚から削除しますか？'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('キャンセル'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                    child: const Text('削除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              ref
                                  .read(bookmarkListProvider.notifier)
                                  .removeBookmark(bookmark.id);
                            }
                          } else if (result.tier != null) {
                            ref
                                .read(bookmarkListProvider.notifier)
                                .updateTier(bookmark.id, result.tier!);
                          }
                        },
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(errorMessage(e))),
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

  Widget _siteFilterChip(NovelSite site) {
    final selected = _siteFilter.contains(site);
    final label = switch (site) {
      NovelSite.narou => 'なろう',
      NovelSite.hameln => 'ハーメルン',
      NovelSite.arcadia => 'Arcadia',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: SizedBox(
          width: 16,
          height: 16,
          child: SiteBadge(site: site, size: 16),
        ),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (selected) {
              _siteFilter = Set.from(_siteFilter)..remove(site);
            } else {
              _siteFilter = Set.from(_siteFilter)..add(site);
            }
          });
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _categoryFilterChip() {
    final isActive = _selectedCategoryIds.isNotEmpty;
    final label = isActive
        ? 'カテゴリ (${_selectedCategoryIds.length})'
        : 'カテゴリ';

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isActive,
        avatar: const Icon(Icons.label_outline, size: 14),
        onSelected: (_) async {
          final result = await CategoryPickSheet.show(
            context,
            initialSelectedIds: Set.from(_selectedCategoryIds),
            mode: CategoryPickMode.filter,
          );
          if (result != null) {
            setState(() => _selectedCategoryIds = result);
          }
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _stampFilterChip() {
    final isActive = _stampFilter != null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(
          isActive ? _stampFilter! : 'スタンプ',
          style: const TextStyle(fontSize: 12),
        ),
        selected: isActive,
        avatar: isActive ? null : const Icon(Icons.emoji_emotions_outlined, size: 14),
        onSelected: (_) async {
          if (isActive) {
            setState(() => _stampFilter = null);
            return;
          }
          final picked = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('スタンプで絞り込む',
                        style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _stampEmojis
                          .map((e) => GestureDetector(
                                onTap: () => Navigator.pop(ctx, e),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 36)),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
          if (picked != null) setState(() => _stampFilter = picked);
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _openReadUrl(Bookmark bookmark) async {
    final novel = bookmark.novel!;
    final url = bookmark.lastReadEpisode > 0
        ? novel.episodeUrl(bookmark.lastReadEpisode)
        : novel.url;
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
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
