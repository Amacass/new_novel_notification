import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/bookmark.dart';
import '../../providers/charm_tag_provider.dart';
import '../../providers/stamp_provider.dart';
import 'widgets/promo_card_canvas.dart';

class PromoCardScreen extends ConsumerStatefulWidget {
  final Bookmark bookmark;

  const PromoCardScreen({super.key, required this.bookmark});

  @override
  ConsumerState<PromoCardScreen> createState() => _PromoCardScreenState();
}

class _PromoCardScreenState extends ConsumerState<PromoCardScreen>
    with SingleTickerProviderStateMixin {
  final _repaintKey = GlobalKey();
  bool _isGenerating = false;
  late AnimationController _buildAnimController;
  late Animation<double> _buildAnimation;

  @override
  void initState() {
    super.initState();
    _buildAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _buildAnimation = CurvedAnimation(
      parent: _buildAnimController,
      curve: Curves.easeOutBack,
    );
    _buildAnimController.forward();
  }

  @override
  void dispose() {
    _buildAnimController.dispose();
    super.dispose();
  }

  Future<void> _shareCard() async {
    setState(() => _isGenerating = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'promo_card.png');

      await Share.shareXFiles(
        [xFile],
        text: '${widget.bookmark.novel?.title ?? "この小説"}がおすすめ！',
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync =
        ref.watch(novelTagsProvider(widget.bookmark.novelId));
    final stampsAsync =
        ref.watch(novelStampsProvider(widget.bookmark.novelId));

    final tags = tagsAsync.valueOrNull ?? [];
    final stamps = stampsAsync.valueOrNull ?? [];
    final latestEmoji = stamps.isNotEmpty ? stamps.first.emoji : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('布教カード'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _buildAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _buildAnimation.value.clamp(0.0, 1.0),
                    child: Opacity(
                      opacity: _buildAnimation.value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: PromoCardCanvas(
                    bookmark: widget.bookmark,
                    tags: tags,
                    latestStampEmoji: latestEmoji,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isGenerating ? null : _shareCard,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(_isGenerating ? '生成中...' : 'シェアする'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
