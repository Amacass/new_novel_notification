import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Result from the tier change sheet.
/// [tier] is the new tier, or null if delete was selected.
class TierChangeResult {
  final int? tier;
  final bool delete;

  const TierChangeResult.changeTier(int this.tier) : delete = false;
  const TierChangeResult.deleteBookmark() : tier = null, delete = true;
}

class TierChangeSheet extends StatelessWidget {
  final int currentTier;
  final bool showDelete;

  const TierChangeSheet({
    super.key,
    required this.currentTier,
    this.showDelete = false,
  });

  /// Shows the sheet and returns the new tier, or null if cancelled.
  static Future<int?> show(BuildContext context, {required int currentTier}) async {
    final result = await showModalBottomSheet<TierChangeResult>(
      context: context,
      builder: (_) => TierChangeSheet(currentTier: currentTier),
    );
    return result?.tier;
  }

  /// Shows the sheet with a delete option.
  /// Returns a [TierChangeResult] indicating tier change or delete.
  static Future<TierChangeResult?> showWithDelete(
    BuildContext context, {
    required int currentTier,
  }) {
    return showModalBottomSheet<TierChangeResult>(
      context: context,
      builder: (_) => TierChangeSheet(
        currentTier: currentTier,
        showDelete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'ランクを変更',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final tier in [3, 2, 1, 0])
              ListTile(
                leading: Text(
                  DeskTheme.tierIcon(tier),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(DeskTheme.tierLabel(tier)),
                trailing: currentTier == tier
                    ? Icon(Icons.check,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: currentTier == tier
                    ? null
                    : () => Navigator.pop(
                          context,
                          TierChangeResult.changeTier(tier),
                        ),
              ),
            if (showDelete) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'ブックマークを削除',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  const TierChangeResult.deleteBookmark(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
