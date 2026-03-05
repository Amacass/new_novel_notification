import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../models/bookmark.dart';
import '../../../widgets/site_badge.dart';

class TriageCard extends StatelessWidget {
  final Bookmark bookmark;
  final double offsetX;
  final double offsetY;
  final double rotation;
  final double opacity;
  final bool isTop;

  const TriageCard({
    super.key,
    required this.bookmark,
    this.offsetX = 0,
    this.offsetY = 0,
    this.rotation = 0,
    this.opacity = 1.0,
    this.isTop = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final novel = bookmark.novel;
    final theme = Theme.of(context);

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: 220,
            height: 280,
            decoration: DeskTheme.cardDecoration(isDark: isDark),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DeskTheme.cardBorderRadius),
              child: Stack(
                children: [
                  // Paper texture lines
                  if (!isDark)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PaperLinesPainter(),
                      ),
                    ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Site badge + status
                        if (novel != null)
                          Row(
                            children: [
                              SiteBadge(site: novel.site, size: 28),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  novel.serialStatus.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Previous tier hint
                              if (bookmark.tier >= 0)
                                Text(
                                  DeskTheme.tierIcon(bookmark.tier),
                                  style: const TextStyle(fontSize: 18),
                                ),
                            ],
                          ),
                        const SizedBox(height: 14),

                        // Title (largest, boldest - visual hierarchy)
                        Text(
                          novel?.title ?? '不明な小説',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Author (secondary - smaller, lighter)
                        Text(
                          novel?.authorName ?? '不明な作者',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const Spacer(),

                        // Previous stamp hint (if any)
                        if (bookmark.lastStampedAt != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 14,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'スタンプ済み',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Stats row
                        Row(
                          children: [
                            Icon(
                              Icons.menu_book,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '全${novel?.totalEpisodes ?? 0}話',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const Spacer(),
                            if (bookmark.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.error
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '未読 ${bookmark.unreadCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onError,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Drag indicator for top card
                  if (isTop)
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle horizontal lines for paper texture
class _PaperLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08000000)
      ..strokeWidth = 0.5;

    for (double y = 40; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(20, y),
        Offset(size.width - 20, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
