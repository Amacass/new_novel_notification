import 'package:flutter/material.dart';

import '../../../models/bookmark.dart';
import '../../../models/charm_tag.dart';
import '../../../config/theme.dart';
import '../../../widgets/tier_badge.dart';

class PromoCardCanvas extends StatelessWidget {
  final Bookmark bookmark;
  final List<CharmTag> tags;
  final String? latestStampEmoji;

  const PromoCardCanvas({
    super.key,
    required this.bookmark,
    required this.tags,
    this.latestStampEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final novel = bookmark.novel;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: DeskTheme.cardDecoration(isDark: isDark).copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2C2820) : const Color(0xFFF5F0E1),
            isDark ? const Color(0xFF3A3025) : const Color(0xFFFFF8E7),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with tier badge
          Row(
            children: [
              if (bookmark.tier >= 0) ...[
                TierBadge(tier: bookmark.tier, size: 28),
                const SizedBox(width: 8),
              ],
              Text(
                DeskTheme.tierLabel(bookmark.tier),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (latestStampEmoji != null)
                Text(latestStampEmoji!, style: const TextStyle(fontSize: 24)),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            novel?.title ?? '不明な小説',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Author
          Text(
            novel?.authorName ?? '',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),

          // Tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.take(5).map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Text(
                '全${novel?.totalEpisodes ?? 0}話',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                novel?.serialStatus.displayName ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Footer
          Text(
            '📚 Web小説通知アプリから布教',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }
}
