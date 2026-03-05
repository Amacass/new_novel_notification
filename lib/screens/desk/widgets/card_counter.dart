import 'package:flutter/material.dart';

class CardCounter extends StatelessWidget {
  final int remaining;
  final int total;

  const CardCounter({
    super.key,
    required this.remaining,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (total - remaining) / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '残り $remaining / $total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
