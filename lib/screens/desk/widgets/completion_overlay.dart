import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import '../../../utils/haptics.dart';

class CompletionOverlay extends StatefulWidget {
  final Map<int, int> sortCounts;
  final int totalSorted;
  final VoidCallback? onNewSession;
  final VoidCallback? onGoToBookshelf;

  const CompletionOverlay({
    super.key,
    required this.sortCounts,
    required this.totalSorted,
    this.onNewSession,
    this.onGoToBookshelf,
  });

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
    AppHaptics.complete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: DeskTheme.goldPrimary.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy
              const Text('🏆', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              const Text(
                '仕分け完了！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.totalSorted}作品を仕分けました',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Sort breakdown
              _buildSortStats(),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onNewSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('もう一回'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: widget.onGoToBookshelf,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.library_books, size: 18),
                    label: const Text('本棚を見る'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortStats() {
    final entries = [
      (tier: 3, icon: '👑', label: '殿堂入り', color: DeskTheme.goldPrimary),
      (tier: 2, icon: '⭐', label: '良作', color: DeskTheme.silverPrimary),
      (tier: 1, icon: '📌', label: 'キープ', color: DeskTheme.bronzePrimary),
      (tier: 0, icon: '🗑️', label: 'ゴミ箱', color: DeskTheme.trashColor),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: entries.map((e) {
          final count = widget.sortCounts[e.tier] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Text(e.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: count > 0 ? Colors.white : Colors.white38,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  e.label,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
