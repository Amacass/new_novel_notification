import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class Tray extends StatefulWidget {
  final int tier;
  final bool isHighlighted;
  final bool isReceiving; // pulse when card just landed
  final int count;
  final VoidCallback? onTap;

  const Tray({
    super.key,
    required this.tier,
    this.isHighlighted = false,
    this.isReceiving = false,
    this.count = 0,
    this.onTap,
  });

  @override
  State<Tray> createState() => _TrayState();
}

class _TrayState extends State<Tray> with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Gold tray shimmer (visual anchor - always animating)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    if (widget.tier == 3) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(Tray oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger pulse when card lands
    if (widget.isReceiving && !oldWidget.isReceiving) {
      _triggerPulse();
    }
  }

  void _triggerPulse() {
    _pulseController?.dispose();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _pulseController!,
      curve: Curves.easeOut,
    ));
    _pulseController!.addListener(() => setState(() {}));
    _pulseController!.forward();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pulseScale = _pulseAnimation?.value ?? 1.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (widget.isHighlighted ? 1.15 : 1.0) * pulseScale,
        duration: const Duration(milliseconds: 150),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              width: 76,
              height: 80,
              decoration: DeskTheme.trayDecoration(widget.tier, isDark: isDark)
                  .copyWith(
                border: widget.isHighlighted
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.8),
                        width: 2.5,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  // Shimmer overlay for gold tray
                  if (widget.tier == 3)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment(_shimmerAnimation.value - 1, 0),
                              end: Alignment(_shimmerAnimation.value, 0),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcATop,
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                    ),
                  // Content
                  Center(child: child!),
                ],
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DeskTheme.tierIcon(widget.tier),
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                DeskTheme.tierLabel(widget.tier),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.tier == 0 ? Colors.white70 : Colors.white,
                  shadows: const [
                    Shadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
              ),
              if (widget.count > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
