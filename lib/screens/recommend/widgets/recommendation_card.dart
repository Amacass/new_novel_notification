import 'package:flutter/material.dart';

import '../../../models/recommendation.dart';
import '../../../widgets/tier_badge.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final bool showMine;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onTogglePublic;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const RecommendationCard({
    super.key,
    required this.rec,
    this.showMine = false,
    this.onTap,
    this.onLike,
    this.onTogglePublic,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final novel = rec.novel;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 審査状態バッジ（自分のおすすめタブのみ）
              if (showMine) _StatusBadge(status: rec.moderationStatus),
              if (showMine) const SizedBox(height: 6),

              // 見出し
              Text(
                rec.heading,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // 小説情報行
              if (novel != null)
                Row(
                  children: [
                    TierBadge(tier: rec.sourceTier),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        novel.title ?? '（タイトル不明）',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 6),

              // 本文抜粋
              Text(
                rec.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // フッター行
              Row(
                children: [
                  // 却下理由（自分のおすすめタブで却下時のみ）
                  if (showMine &&
                      rec.moderationStatus == ModerationStatus.rejected &&
                      rec.moderationReason != null)
                    Expanded(
                      child: Text(
                        '却下: ${rec.moderationReason!.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  else if (rec.author != null)
                    Expanded(
                      child: Text(
                        '${rec.author!.displayName ?? '匿名'}  ♡ ${_formatCount(rec.author!.totalRecommendLikes)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(),

                  // 公開/非公開トグル（自分のおすすめタブ）
                  if (showMine && onTogglePublic != null)
                    IconButton(
                      iconSize: 20,
                      tooltip: rec.isPublic ? '非公開にする' : '公開する',
                      icon: Icon(
                        rec.isPublic
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: rec.isPublic
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      onPressed: onTogglePublic,
                    ),

                  // いいねボタン
                  if (onLike != null)
                    _LikeButton(
                      count: rec.likeCount,
                      liked: rec.isLikedByMe ?? false,
                      onTap: onLike!,
                    )
                  else
                    _LikeCount(count: rec.likeCount),

                  // メニュー
                  if (onReport != null || onDelete != null)
                    _MenuButton(
                      onReport: onReport,
                      onDelete: onDelete,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatusBadge extends StatelessWidget {
  final ModerationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case ModerationStatus.pending:
        color = Colors.orange;
      case ModerationStatus.approved:
        color = theme.colorScheme.primary;
      case ModerationStatus.rejected:
        color = theme.colorScheme.error;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final int count;
  final bool liked;
  final VoidCallback onTap;

  const _LikeButton({required this.count, required this.liked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = liked
        ? Colors.pink
        : Theme.of(context).colorScheme.onSurface.withAlpha(150);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(liked ? Icons.favorite : Icons.favorite_outline,
                size: 18, color: color),
            const SizedBox(width: 3),
            Text('$count',
                style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}

class _LikeCount extends StatelessWidget {
  final int count;

  const _LikeCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 3),
          Text('$count',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback? onReport;
  final VoidCallback? onDelete;

  const _MenuButton({this.onReport, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      iconSize: 20,
      itemBuilder: (_) => [
        if (onReport != null)
          const PopupMenuItem(value: 'report', child: Text('通報')),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
      onSelected: (v) {
        if (v == 'report') onReport?.call();
        if (v == 'delete') onDelete?.call();
      },
    );
  }
}
