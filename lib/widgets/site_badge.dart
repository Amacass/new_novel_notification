import 'package:flutter/material.dart';

import '../models/novel.dart';

class SiteBadge extends StatelessWidget {
  final NovelSite site;
  final double size;

  const SiteBadge({super.key, required this.site, this.size = 28});

  Color _getColor() {
    switch (site) {
      case NovelSite.narou:
        return Colors.green;
      case NovelSite.hameln:
        return Colors.blue;
      case NovelSite.arcadia:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          site.shortLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
