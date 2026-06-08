import 'package:flutter/material.dart';

class StampButton extends StatefulWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const StampButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<StampButton> createState() => _StampButtonState();
}

class _StampButtonState extends State<StampButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = widget.isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final border = widget.isActive
        ? Border.all(color: colorScheme.primary, width: 2)
        : null;

    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: ScaleTransition(
        scale: _scaleController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: border,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.isActive ? colorScheme.primary : null,
                    fontWeight: widget.isActive ? FontWeight.bold : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
