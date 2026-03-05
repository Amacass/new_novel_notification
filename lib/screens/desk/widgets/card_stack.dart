import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/theme.dart';
import '../../../models/bookmark.dart';
import '../../../providers/triage_provider.dart';
import '../../../utils/haptics.dart';
import 'triage_card.dart';

class CardStack extends ConsumerStatefulWidget {
  final List<Bookmark> cards;
  final int currentIndex;
  final ValueChanged<int?>? onDragTierChanged;
  final ValueChanged<int>? onCardSorted;

  const CardStack({
    super.key,
    required this.cards,
    required this.currentIndex,
    this.onDragTierChanged,
    this.onCardSorted,
  });

  @override
  ConsumerState<CardStack> createState() => _CardStackState();
}

class _CardStackState extends ConsumerState<CardStack>
    with TickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  late AnimationController _snapBackController;
  late Animation<Offset> _snapBackAnimation;

  // Fly-to-tray animation
  AnimationController? _flyController;
  Offset _flyStart = Offset.zero;
  Offset _flyEnd = Offset.zero;
  double _flyRotation = 0;
  bool _isFlying = false;
  int _flyTier = 0;

  // Gold particle effect
  AnimationController? _particleController;
  bool _showParticles = false;
  final _particleRandom = math.Random();
  List<_Particle>? _particles;

  static const double _sortThreshold = 50.0;
  static const double _guideThreshold = 20.0; // show guide earlier

  @override
  void initState() {
    super.initState();
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _snapBackAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _snapBackController,
      curve: Curves.elasticOut,
    ));
    _snapBackController.addListener(() {
      setState(() => _dragOffset = _snapBackAnimation.value);
    });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    _flyController?.dispose();
    _particleController?.dispose();
    super.dispose();
  }

  int? _tierFromAngle(double angle, double distance, {bool forGuide = false}) {
    final threshold = forGuide ? _guideThreshold : _sortThreshold;
    if (distance < threshold) return null;

    double degrees = angle * 180 / math.pi;
    if (degrees < 0) degrees += 360;

    if (degrees >= 200 && degrees <= 340) return 0; // down → trash
    if (degrees >= 60 && degrees <= 120) return 3;  // up → gold
    if (degrees >= 10 && degrees < 60) return 2;    // right-up → silver
    if (degrees > 120 && degrees <= 170) return 1;  // left-up → bronze

    return null; // skip
  }

  Offset _trayTargetOffset(int tier) {
    // Fly targets relative to card center (matching 3D desk layout)
    switch (tier) {
      case 3: return const Offset(0, -240);     // gold: top center (far on desk)
      case 2: return const Offset(140, -140);   // silver: upper right
      case 1: return const Offset(-140, -140);  // bronze: upper left
      default: return const Offset(0, 200);     // trash: bottom center (near)
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isFlying) return;
    _snapBackController.stop();
    setState(() => _dragOffset = Offset.zero);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isFlying) return;
    setState(() => _dragOffset += details.delta);

    final distance = _dragOffset.distance;
    final angle = math.atan2(-_dragOffset.dy, _dragOffset.dx);
    // Show guide with low threshold for responsiveness
    final guideTier = _tierFromAngle(angle, distance, forGuide: true);
    widget.onDragTierChanged?.call(guideTier);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isFlying) return;

    final distance = _dragOffset.distance;
    final angle = math.atan2(-_dragOffset.dy, _dragOffset.dx);
    final tier = _tierFromAngle(angle, distance);

    widget.onDragTierChanged?.call(null);

    if (tier != null) {
      _startFlyAnimation(tier);
    } else if (distance >= _sortThreshold) {
      // Skip
      ref.read(triageProvider.notifier).skipCard();
      setState(() => _dragOffset = Offset.zero);
    } else {
      // Snap back with spring
      _snapBackAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _snapBackController,
        curve: Curves.elasticOut,
      ));
      _snapBackController
        ..reset()
        ..forward();
    }
  }

  void _startFlyAnimation(int tier) {
    AppHaptics.sortCard(tier);

    _flyController?.dispose();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Doherty threshold
    );

    _flyStart = _dragOffset;
    _flyEnd = _trayTargetOffset(tier);
    _flyRotation = tier == 0 ? 0.3 : -0.15; // trash gets more spin
    _flyTier = tier;
    setState(() => _isFlying = true);

    _flyController!.addListener(() => setState(() {}));
    _flyController!.forward().then((_) {
      // Card reached tray - trigger sort
      ref.read(triageProvider.notifier).sortCard(tier);
      widget.onCardSorted?.call(tier);

      // Show particles for ★3
      if (tier == 3) {
        _triggerGoldParticles();
      }

      setState(() {
        _isFlying = false;
        _dragOffset = Offset.zero;
      });
    });
  }

  void _triggerGoldParticles() {
    _particleController?.dispose();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _particles = List.generate(40, (_) {
      return _Particle(
        x: _particleRandom.nextDouble() * 2 - 1,
        y: _particleRandom.nextDouble() * -1.5,
        vx: (_particleRandom.nextDouble() - 0.5) * 3,
        vy: -1.5 - _particleRandom.nextDouble() * 2,
        size: 2 + _particleRandom.nextDouble() * 4,
        color: _particleRandom.nextBool()
            ? DeskTheme.goldPrimary
            : DeskTheme.goldLight,
      );
    });

    setState(() => _showParticles = true);
    _particleController!.addListener(() => setState(() {}));
    _particleController!.forward().then((_) {
      setState(() => _showParticles = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentIndex >= widget.cards.length && !_isFlying) {
      return const SizedBox.shrink();
    }

    final visibleCount =
        math.min(3, widget.cards.length - widget.currentIndex);
    final children = <Widget>[];

    // Background cards (not draggable)
    for (int i = visibleCount - 1; i >= 1; i--) {
      final cardIndex = widget.currentIndex + i;
      if (cardIndex >= widget.cards.length) continue;

      final bookmark = widget.cards[cardIndex];
      final stackOffset = i * 6.0;
      final stackScale = 1.0 - (i * 0.04);

      children.add(
        Transform.translate(
          offset: Offset(0, stackOffset),
          child: Transform.scale(
            scale: stackScale,
            child: TriageCard(
              bookmark: bookmark,
              opacity: 1.0 - (i * 0.2),
            ),
          ),
        ),
      );
    }

    // Top card (draggable / flying)
    if (widget.currentIndex < widget.cards.length) {
      final bookmark = widget.cards[widget.currentIndex];

      double offsetX, offsetY, rotation;

      if (_isFlying && _flyController != null) {
        final t = Curves.easeInCubic.transform(_flyController!.value);
        offsetX = _flyStart.dx + (_flyEnd.dx - _flyStart.dx) * t;
        offsetY = _flyStart.dy + (_flyEnd.dy - _flyStart.dy) * t;
        rotation = _flyRotation * t;
        // Perspective scale: cards going far (up) shrink, going near (down) stay same
        final double scaleFactor;
        if (_flyTier == 0) {
          scaleFactor = 1.0 - (t * 0.15); // trash: slight shrink (falling down)
        } else if (_flyTier == 3) {
          scaleFactor = 1.0 - (t * 0.55); // gold: significant shrink (going far)
        } else {
          scaleFactor = 1.0 - (t * 0.4); // sides: moderate shrink
        }
        final scale = scaleFactor;

        children.add(
          Transform.scale(
            scale: scale,
            child: TriageCard(
              bookmark: bookmark,
              offsetX: offsetX,
              offsetY: offsetY,
              rotation: rotation,
              opacity: 1.0 - (t * 0.3),
              isTop: true,
            ),
          ),
        );
      } else {
        offsetX = _dragOffset.dx;
        offsetY = _dragOffset.dy;
        rotation = _dragOffset.dx * 0.0015; // proportional rotation

        children.add(
          GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: TriageCard(
              bookmark: bookmark,
              offsetX: offsetX,
              offsetY: offsetY,
              rotation: rotation,
              isTop: true,
            ),
          ),
        );
      }
    }

    // Gold particle overlay
    if (_showParticles && _particleController != null && _particles != null) {
      children.add(
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _GoldParticlePainter(
                particles: _particles!,
                progress: _particleController!.value,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

class _Particle {
  final double x, y, vx, vy, size;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}

class _GoldParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _GoldParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.15; // near the top (tray area)
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final t = progress;
      final x = cx + (p.x + p.vx * t) * 80;
      final y = cy + (p.y + p.vy * t) * 60 + 30 * t * t; // gravity

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.9)
        ..style = PaintingStyle.fill;

      // Star-shaped particles for gold
      canvas.drawCircle(Offset(x, y), p.size * (1.0 - t * 0.3), paint);

      // Sparkle highlight
      if (progress < 0.5) {
        final sparkle = Paint()
          ..color = Colors.white.withValues(alpha: opacity * 0.6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x + 1, y - 1),
          p.size * 0.3,
          sparkle,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GoldParticlePainter old) => old.progress != progress;
}
