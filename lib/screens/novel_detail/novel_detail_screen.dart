import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/charm_tag_provider.dart';
import '../../providers/novel_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/site_badge.dart';
import '../../widgets/tier_badge.dart';
import '../stamp/promo_card_screen.dart';
import '../stamp/stamp_sheet.dart';

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
    final stampsAsync = ref.watch(novelStampsProvider(widget.novelId));
    final tagsAsync = ref.watch(novelTagsProvider(widget.novelId));
    final userStampCount = ref.watch(userStampCountProvider);
    final userTagCount = ref.watch(userTagCountProvider);

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
          final stamps = stampsAsync.valueOrNull ?? [];
          final tags = tagsAsync.valueOrNull ?? [];
          final stampCount = userStampCount.valueOrNull ?? 0;
          final tagCount = userTagCount.valueOrNull ?? 0;

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
                    const Spacer(),
                    // Tier badge
                    if (bookmark != null && bookmark.tier >= 0) ...[
                      TierBadge(tier: bookmark.tier, size: 28),
                      const SizedBox(width: 4),
                      Text(
                        DeskTheme.tierLabel(bookmark.tier),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),

                const Divider(height: 32),

                // Stamp button
                if (bookmark != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Text('📝', style: TextStyle(fontSize: 18)),
                      label: const Text('スタンプを押す'),
                      onPressed: () => StampSheet.show(
                        context,
                        novelId: widget.novelId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Stamp history
                if (stamps.isNotEmpty) ...[
                  _SectionTitle(title: 'スタンプ履歴'),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: stamps.length,
                      itemBuilder: (context, index) {
                        final stamp = stamps[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Text(
                                stamp.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              Text(
                                _formatDate(stamp.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tags section
                if (tags.isNotEmpty) ...[
                  _SectionTitle(title: '魅力タグ'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) {
                      return Chip(
                        label: Text(tag.name,
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Progressive disclosure: suggest tags after 3+ stamps
                if (stamps.isNotEmpty &&
                    stamps.length >= 3 &&
                    stampCount >= 3 &&
                    tags.isEmpty) ...[
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.3),
                    child: ListTile(
                      leading: const Text('🏷️', style: TextStyle(fontSize: 24)),
                      title: const Text('魅力タグを付けてみませんか？'),
                      subtitle: const Text('この作品の魅力を記録しましょう'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Open tag sheet for the latest stamp
                        // TagSheet.show(context, stampId: stamps.first.id, novelId: widget.novelId);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Promo card button (progressive disclosure: 5+ tags)
                if (tagCount >= 5 && bookmark != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      icon: const Text('📣', style: TextStyle(fontSize: 16)),
                      label: const Text('布教カードを作る'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PromoCardScreen(bookmark: bookmark),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                        onPressed: () => _showEpisodeDialog(
                            bookmark.id,
                            bookmark.lastReadEpisode,
                            novel.totalEpisodes),
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
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
