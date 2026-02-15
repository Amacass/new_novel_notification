import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/bookmark_provider.dart';
import '../../providers/novel_provider.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/site_badge.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  final int novelId;

  const NovelDetailScreen({super.key, required this.novelId});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final novelAsync = ref.watch(novelDetailProvider(widget.novelId));
    final reviewAsync = ref.watch(novelReviewProvider(widget.novelId));
    final bookmarks = ref.watch(bookmarkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('小説詳細'),
      ),
      body: novelAsync.when(
        data: (novel) {
          if (novel == null) {
            return const Center(child: Text('小説が見つかりません'));
          }

          final bookmark = bookmarks.valueOrNull
              ?.where((b) => b.novelId == widget.novelId)
              .firstOrNull;
          final review = reviewAsync.valueOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    SiteBadge(site: novel.site, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            novel.title ?? '不明な小説',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            novel.authorName ?? '不明な作者',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(label: Text(novel.serialStatus.displayName)),
                    const SizedBox(width: 8),
                    Text('全${novel.totalEpisodes}話'),
                  ],
                ),

                const Divider(height: 32),

                // Bookmark info (reading progress)
                if (bookmark != null) ...[
                  _SectionTitle(title: 'しおり'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text('既読: 第${bookmark.lastReadEpisode}話まで'),
                      subtitle: bookmark.unreadCount > 0
                          ? Text('未読 ${bookmark.unreadCount}話')
                          : const Text('最新話まで読了'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEpisodeDialog(bookmark.id, bookmark.lastReadEpisode, novel.totalEpisodes),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Review
                _SectionTitle(title: '評価・感想'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingStars(
                          rating: review?.rating,
                          size: 32,
                          interactive: true,
                          onChanged: (rating) {
                            ref.read(registerNovelProvider).upsertReview(
                                  novelId: widget.novelId,
                                  rating: rating,
                                  comment: review?.comment,
                                );
                            ref.invalidate(
                                novelReviewProvider(widget.novelId));
                          },
                        ),
                        const SizedBox(height: 12),
                        if (review?.comment != null &&
                            review!.comment!.isNotEmpty)
                          Text(review.comment!)
                        else
                          Text(
                            '感想を追加...',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('編集'),
                            onPressed: () =>
                                _showCommentDialog(review?.comment),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Memo
                if (bookmark != null) ...[
                  _SectionTitle(title: 'メモ'),
                  Card(
                    child: ListTile(
                      title: Text(
                        bookmark.memo?.isNotEmpty == true
                            ? bookmark.memo!
                            : 'メモを追加...',
                        style: bookmark.memo?.isNotEmpty != true
                            ? TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                            : null,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showMemoDialog(bookmark.id, bookmark.memo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Open in browser
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('サイトで読む'),
                    onPressed: () => _openUrl(novel.url),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('エラー: $error')),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEpisodeDialog(int bookmarkId, int current, int total) {
    final controller = TextEditingController(text: current.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('既読話数を更新'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '既読話数',
            hintText: '0〜$total',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0 && value <= total) {
                ref
                    .read(bookmarkListProvider.notifier)
                    .updateLastReadEpisode(bookmarkId, value);
                Navigator.pop(context);
              }
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(String? currentComment) {
    final controller = TextEditingController(text: currentComment);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('感想を編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '感想を入力...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final reviewAsync =
                  ref.read(novelReviewProvider(widget.novelId));
              ref.read(registerNovelProvider).upsertReview(
                    novelId: widget.novelId,
                    rating: reviewAsync.valueOrNull?.rating,
                    comment: controller.text,
                  );
              ref.invalidate(novelReviewProvider(widget.novelId));
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showMemoDialog(int bookmarkId, String? currentMemo) {
    final controller = TextEditingController(text: currentMemo);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'キャラ名、伏線の記録など...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(bookmarkListProvider.notifier)
                  .updateMemo(bookmarkId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
