import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/bookmark.dart';
import 'site_badge.dart';
import 'rating_stars.dart';

class NovelCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback? onTap;
  final VoidCallback? onDismissed;

  const NovelCard({
    super.key,
    required this.bookmark,
    this.onTap,
    this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final novel = bookmark.novel;
    if (novel == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final unread = bookmark.unreadCount;

    return Dismissible(
      key: ValueKey(bookmark.id),
      direction:
          onDismissed != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => onDismissed?.call(),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ブックマーク削除'),
            content: Text('「${novel.title}」をブックマークから削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除'),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SiteBadge(site: novel.site),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        novel.title ?? '不明な小説',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${novel.authorName ?? '不明な作者'}  ${novel.totalEpisodes}話',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RatingStars(
                            rating: bookmark.review?.rating,
                            size: 16,
                          ),
                          if (unread > 0) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '未読 $unread話',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (novel.siteUpdatedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(novel.siteUpdatedAt!, locale: 'ja'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
