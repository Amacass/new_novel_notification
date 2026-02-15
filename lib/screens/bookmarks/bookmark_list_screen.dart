import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/bookmark_provider.dart';
import '../../providers/novel_provider.dart';
import '../../utils/url_parser.dart';
import '../../widgets/novel_card.dart';

class BookmarkListScreen extends ConsumerStatefulWidget {
  const BookmarkListScreen({super.key});

  @override
  ConsumerState<BookmarkListScreen> createState() =>
      _BookmarkListScreenState();
}

class _BookmarkListScreenState extends ConsumerState<BookmarkListScreen> {
  int? _ratingFilter;
  String _sortBy = 'updated';

  void _showAddBookmarkDialog() {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ブックマーク追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '小説URL',
                hintText: 'https://ncode.syosetu.com/...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Text(
              '対応サイト: 小説家になろう / ハーメルン / Arcadia',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              if (!NovelUrlParser.isSupported(url)) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('このURLは対応していません')),
                  );
                }
                return;
              }

              Navigator.pop(context);

              final messenger = ScaffoldMessenger.of(this.context);
              try {
                final service = ref.read(registerNovelProvider);
                final novel = await service.registerFromUrl(url);
                if (novel != null) {
                  await ref
                      .read(bookmarkListProvider.notifier)
                      .addBookmark(novelId: novel.id);
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            '「${novel.title}」をブックマークに追加しました')),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('追加に失敗しました: $e')),
                );
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ブックマーク'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'updated', child: Text('更新日順')),
              const PopupMenuItem(value: 'rating', child: Text('評価順')),
              const PopupMenuItem(value: 'title', child: Text('タイトル順')),
              const PopupMenuItem(value: 'created', child: Text('登録日順')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Rating filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: '全て',
                  selected: _ratingFilter == null,
                  onSelected: () =>
                      setState(() => _ratingFilter = null),
                ),
                for (int i = 5; i >= 1; i--)
                  _FilterChip(
                    label: '★' * i,
                    selected: _ratingFilter == i,
                    onSelected: () =>
                        setState(() => _ratingFilter = i),
                  ),
              ],
            ),
          ),
          Expanded(
            child: bookmarks.when(
              data: (list) {
                var filtered = list;

                // Apply rating filter
                if (_ratingFilter != null) {
                  filtered = filtered
                      .where(
                          (b) => b.review?.rating == _ratingFilter)
                      .toList();
                }

                // Apply sort
                filtered = List.of(filtered)
                  ..sort((a, b) {
                    switch (_sortBy) {
                      case 'rating':
                        return (b.review?.rating ?? 0)
                            .compareTo(a.review?.rating ?? 0);
                      case 'title':
                        return (a.novel?.title ?? '')
                            .compareTo(b.novel?.title ?? '');
                      case 'created':
                        return b.createdAt.compareTo(a.createdAt);
                      default: // updated
                        final aDate = a.novel?.siteUpdatedAt;
                        final bDate = b.novel?.siteUpdatedAt;
                        if (aDate == null && bDate == null) return 0;
                        if (aDate == null) return 1;
                        if (bDate == null) return -1;
                        return bDate.compareTo(aDate);
                    }
                  });

                if (filtered.isEmpty) {
                  return const Center(child: Text('該当するブックマークがありません'));
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(bookmarkListProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return NovelCard(
                        bookmark: filtered[index],
                        onTap: () {
                          context.push(
                              '/novel/${filtered[index].novelId}');
                        },
                        onDismissed: () {
                          ref
                              .read(bookmarkListProvider.notifier)
                              .removeBookmark(filtered[index].id);
                        },
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('エラー: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookmarkDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
