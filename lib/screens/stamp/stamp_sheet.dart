import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/stamp_provider.dart';
import '../../utils/haptics.dart';
import 'widgets/stamp_button.dart';
import 'widgets/stamp_effect.dart';

class StampSheet extends ConsumerStatefulWidget {
  final int novelId;
  final int? episodeNumber;

  const StampSheet({
    super.key,
    required this.novelId,
    this.episodeNumber,
  });

  static Future<void> show(
    BuildContext context, {
    required int novelId,
    int? episodeNumber,
  }) {
    return showModalBottomSheet(
      context: context,
      builder: (_) => StampSheet(
        novelId: novelId,
        episodeNumber: episodeNumber,
      ),
    );
  }

  @override
  ConsumerState<StampSheet> createState() => _StampSheetState();
}

class _StampSheetState extends ConsumerState<StampSheet> {
  OverlayEntry? _effectOverlay;

  @override
  void dispose() {
    _effectOverlay?.remove();
    super.dispose();
  }

  void _onStampTap(int index) async {
    final stamp = _stampData[index];
    AppHaptics.stampTap();

    // Show particle effect
    _showEffect(stamp.effectType, stamp.primaryColor, stamp.secondaryColor);

    // Save to DB
    try {
      await ref.read(stampServiceProvider).addStamp(
            novelId: widget.novelId,
            emoji: stamp.emoji,
            episodeNumber: widget.episodeNumber,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('スタンプの保存に失敗しました: $e')),
        );
      }
    }
  }

  void _showEffect(StampEffectType type, Color primary, Color secondary) {
    _effectOverlay?.remove();
    _effectOverlay = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: StampEffect(
            type: type,
            primaryColor: primary,
            secondaryColor: secondary,
            onComplete: () {
              _effectOverlay?.remove();
              _effectOverlay = null;
            },
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_effectOverlay!);
  }

  static const _stampData = [
    (emoji: '🔥', label: '熱い', effectType: StampEffectType.fireRise, primaryColor: Color(0xFFFF6B00), secondaryColor: Color(0xFFFF0000)),
    (emoji: '😭', label: '泣ける', effectType: StampEffectType.rainDrop, primaryColor: Color(0xFF4FC3F7), secondaryColor: Color(0xFF0288D1)),
    (emoji: '🌿', label: '癒し', effectType: StampEffectType.leafFloat, primaryColor: Color(0xFF66BB6A), secondaryColor: Color(0xFF795548)),
    (emoji: '😍', label: '好き', effectType: StampEffectType.heartRise, primaryColor: Color(0xFFE91E63), secondaryColor: Color(0xFFF44336)),
    (emoji: '🤯', label: '衝撃', effectType: StampEffectType.explosion, primaryColor: Color(0xFFFFFFFF), secondaryColor: Color(0xFFFFEB3B)),
    (emoji: '💤', label: '眠い', effectType: StampEffectType.zFloat, primaryColor: Color(0xFF9C27B0), secondaryColor: Color(0xFF42A5F5)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'スタンプを押す',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          // 2x3 grid of stamps
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(_stampData.length, (i) {
              final s = _stampData[i];
              return StampButton(
                emoji: s.emoji,
                label: s.label,
                onTap: () => _onStampTap(i),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
