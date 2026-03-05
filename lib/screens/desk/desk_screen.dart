import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/bookmark_provider.dart';
import '../../providers/triage_provider.dart';
import '../../screens/stamp/stamp_sheet.dart';
import '../../utils/haptics.dart';
import 'widgets/card_counter.dart';
import 'widgets/card_stack.dart';
import 'widgets/completion_overlay.dart';
import 'widgets/desk_background.dart';
import 'widgets/magnetic_guide.dart';
import 'widgets/trash_bin_3d.dart';
import 'widgets/tray_3d.dart';

class DeskScreen extends ConsumerStatefulWidget {
  const DeskScreen({super.key});

  @override
  ConsumerState<DeskScreen> createState() => _DeskScreenState();
}

class _DeskScreenState extends ConsumerState<DeskScreen> {
  int? _highlightedTier;
  int? _receivingTier;

  // Track sort stats for completion overlay
  final Map<int, int> _sessionSortCounts = {0: 0, 1: 0, 2: 0, 3: 0};

  void _onCardSorted(int tier) {
    _sessionSortCounts[tier] = (_sessionSortCounts[tier] ?? 0) + 1;

    // Trigger tray pulse
    setState(() => _receivingTier = tier);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _receivingTier = null);
    });

    // Stamp nudge for high-tier sorts
    if (tier >= 2) {
      final triageState = ref.read(triageProvider);
      final currentIdx = triageState.currentIndex - 1;
      if (currentIdx >= 0 && currentIdx < triageState.cards.length) {
        final sortedBookmark = triageState.cards[currentIdx];
        final novelId = sortedBookmark.novelId;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('スタンプを付けますか？（あとでもOK）'),
              backgroundColor: Colors.black87,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'つける',
                textColor: Colors.amber,
                onPressed: () {
                  StampSheet.show(context, novelId: novelId);
                },
              ),
            ),
          );
        });
      }
    }
  }

  /// Tray tap: if the last card was just sorted to this tray, undo it.
  /// Otherwise navigate to bookshelf filtered by tier.
  void _onTrayTap(int tier) {
    final triageState = ref.read(triageProvider);
    // Check if last sort was to this tier (pull-back undo)
    if (triageState.lastResultBookmarkId != null) {
      final lastIdx = triageState.currentIndex - 1;
      if (lastIdx >= 0 && lastIdx < triageState.cards.length) {
        final lastCard = triageState.cards[lastIdx];
        if (lastCard.tier == tier || triageState.lastResult != null) {
          // Undo last sort - pull card back from this tray
          _onUndo();
          return;
        }
      }
    }
    context.go('/bookshelf?tier=$tier');
  }

  void _onUndo() {
    final triageState = ref.read(triageProvider);
    if (triageState.lastResultBookmarkId == null) return;

    // Decrease session sort count for the undone tier
    // We need to figure out which tier was last sorted - check bookmark's current tier
    final lastIdx = triageState.currentIndex - 1;
    if (lastIdx >= 0 && lastIdx < triageState.cards.length) {
      final lastCard = triageState.cards[lastIdx];
      final lastTier = lastCard.tier;
      if (lastTier >= 0 && (_sessionSortCounts[lastTier] ?? 0) > 0) {
        _sessionSortCounts[lastTier] = _sessionSortCounts[lastTier]! - 1;
      }
    }

    AppHaptics.undo();
    ref.read(triageProvider.notifier).undoLast();
    setState(() {});
  }

  /// Get paper count for a tray from DB tier counts + session sort counts
  /// Session counts provide immediate feedback before DB refresh completes
  int _trayPaperCount(int tier, Map<int, int> dbTierCounts) {
    // Use the higher of DB count or session count to avoid showing 0
    // after sorting (before DB refresh) while avoiding double-counting
    final dbCount = dbTierCounts[tier] ?? 0;
    final sessionCount = _sessionSortCounts[tier] ?? 0;
    // If DB already reflects the sorts, dbCount >= sessionCount
    // If DB hasn't refreshed yet, sessionCount is the only source
    return dbCount > 0 ? dbCount : sessionCount;
  }

  @override
  Widget build(BuildContext context) {
    final triageState = ref.watch(triageProvider);
    final bookmarks = ref.watch(bookmarkListProvider);

    final dbTierCounts = <int, int>{};
    for (final b in bookmarks.valueOrNull ?? []) {
      if (b.tier >= 0) {
        dbTierCounts[b.tier] = (dbTierCounts[b.tier] ?? 0) + 1;
      }
    }

    final unsortedCount =
        (bookmarks.valueOrNull ?? []).where((b) => b.tier < 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('デスク'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (unsortedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '未仕分け $unsortedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DeskBackground(
        child: SafeArea(
          child: triageState.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(
                        'カードを準備中...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : triageState.error != null
                  ? _buildErrorState(triageState.error!)
                  : _buildContent(triageState, dbTierCounts),
        ),
      ),
    );
  }

  Widget _buildContent(TriageState triageState, Map<int, int> dbTierCounts) {
    if (triageState.cards.isEmpty && !triageState.isComplete) {
      return _buildEmptyState();
    }

    final canUndo = triageState.lastResult != null ||
        triageState.lastResultBookmarkId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            const SizedBox.expand(),

            // Magnetic guide overlay
            MagneticGuide(activeTier: _highlightedTier),

            // === 3D DESK SCENE ===

            // Gold tray - top center (far on desk)
            Positioned(
              top: 4,
              left: (w - 110 * 0.8) / 2,
              child: Transform.scale(
                scale: 0.8,
                alignment: Alignment.topCenter,
                child: Tray3D(
                  tier: 3,
                  count: _trayPaperCount(3, dbTierCounts),
                  isHighlighted: _highlightedTier == 3,
                  isReceiving: _receivingTier == 3,
                  onTap: () => _onTrayTap(3),
                ),
              ),
            ),

            // Bronze tray - upper left
            Positioned(
              top: h * 0.12,
              left: 8,
              child: Transform.scale(
                scale: 0.85,
                alignment: Alignment.topLeft,
                child: Tray3D(
                  tier: 1,
                  count: _trayPaperCount(1, dbTierCounts),
                  isHighlighted: _highlightedTier == 1,
                  isReceiving: _receivingTier == 1,
                  onTap: () => _onTrayTap(1),
                ),
              ),
            ),

            // Silver tray - upper right
            Positioned(
              top: h * 0.12,
              right: 8,
              child: Transform.scale(
                scale: 0.85,
                alignment: Alignment.topRight,
                child: Tray3D(
                  tier: 2,
                  count: _trayPaperCount(2, dbTierCounts),
                  isHighlighted: _highlightedTier == 2,
                  isReceiving: _receivingTier == 2,
                  onTap: () => _onTrayTap(2),
                ),
              ),
            ),

            // Card counter
            if (!triageState.isComplete)
              Positioned(
                top: h * 0.28,
                left: 0,
                right: 0,
                child: Center(
                  child: CardCounter(
                    remaining: triageState.remaining,
                    total: triageState.total,
                  ),
                ),
              ),

            // Card stack - center
            Positioned(
              top: h * 0.25,
              left: 0,
              right: 0,
              bottom: h * 0.18,
              child: Center(
                child: triageState.isComplete
                    ? SingleChildScrollView(
                        child: CompletionOverlay(
                          sortCounts: _sessionSortCounts,
                          totalSorted: triageState.total,
                          onNewSession: () {
                            _sessionSortCounts.updateAll((_, _) => 0);
                            ref
                                .read(triageProvider.notifier)
                                .startNewSession();
                          },
                          onGoToBookshelf: () {
                            context.go('/bookshelf');
                          },
                        ),
                      )
                    : CardStack(
                        cards: triageState.cards,
                        currentIndex: triageState.currentIndex,
                        onDragTierChanged: (tier) {
                          setState(() => _highlightedTier = tier);
                        },
                        onCardSorted: _onCardSorted,
                      ),
              ),
            ),

            // Trash bin - bottom center
            Positioned(
              bottom: 36,
              left: (w - 70) / 2,
              child: TrashBin3D(
                count: _trayPaperCount(0, dbTierCounts),
                isHighlighted: _highlightedTier == 0,
                isReceiving: _receivingTier == 0,
                onTap: () => _onTrayTap(0),
              ),
            ),

            // Bottom actions (undo / skip) - overlaid at very bottom
            if (!triageState.isComplete)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Undo button (left side, near trash)
                    if (canUndo)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _ActionButton(
                          icon: Icons.undo,
                          label: '戻す',
                          onTap: _onUndo,
                        ),
                      )
                    else
                      const SizedBox(width: 80),
                    // Skip button (right side)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _ActionButton(
                        icon: Icons.skip_next,
                        label: 'スキップ',
                        onTap: () {
                          ref.read(triageProvider.notifier).skipCard();
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            const Text(
              '読み込みに失敗しました',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.read(triageProvider.notifier).startNewSession();
              },
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'ブックマークがありません',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '小説をブックマークに追加して\n仕分けを始めましょう',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/bookshelf'),
            icon: const Icon(Icons.library_books),
            label: const Text('本棚へ'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
