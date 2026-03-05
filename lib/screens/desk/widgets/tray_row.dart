import 'package:flutter/material.dart';
import 'tray.dart';

class TrayRow extends StatelessWidget {
  final int? highlightedTier;
  final int? receivingTier; // tier that just received a card
  final Map<int, int> tierCounts;
  final ValueChanged<int>? onTrayTap;

  const TrayRow({
    super.key,
    this.highlightedTier,
    this.receivingTier,
    this.tierCounts = const {},
    this.onTrayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Tray(
            tier: 0,
            isHighlighted: highlightedTier == 0,
            isReceiving: receivingTier == 0,
            count: tierCounts[0] ?? 0,
            onTap: () => onTrayTap?.call(0),
          ),
          Tray(
            tier: 1,
            isHighlighted: highlightedTier == 1,
            isReceiving: receivingTier == 1,
            count: tierCounts[1] ?? 0,
            onTap: () => onTrayTap?.call(1),
          ),
          Tray(
            tier: 2,
            isHighlighted: highlightedTier == 2,
            isReceiving: receivingTier == 2,
            count: tierCounts[2] ?? 0,
            onTap: () => onTrayTap?.call(2),
          ),
          Tray(
            tier: 3,
            isHighlighted: highlightedTier == 3,
            isReceiving: receivingTier == 3,
            count: tierCounts[3] ?? 0,
            onTap: () => onTrayTap?.call(3),
          ),
        ],
      ),
    );
  }
}
