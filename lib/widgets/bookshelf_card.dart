import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../widgets/site_badge.dart';
import '../widgets/tier_badge.dart';

class BookshelfCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback? onTap;

  const BookshelfCard({
    super.key,
    required this.bookmark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final novel = bookmark.novel;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Site badge
              if (novel != null)
                SiteBadge(site: novel.site, size: 32),
              const SizedBox(width: 12),

              // Title, author, info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novel?.title ?? '不明な小説',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      novel?.authorName ?? '不明な作者',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (bookmark.tier >= 0) ...[
                          TierBadge(tier: bookmark.tier, size: 20),
                          const SizedBox(width: 8),
                        ],
                        if (bookmark.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '未読 ${bookmark.unreadCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onError,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
