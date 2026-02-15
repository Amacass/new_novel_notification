import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final int? rating;
  final double size;
  final bool interactive;
  final ValueChanged<int>? onChanged;

  const RatingStars({
    super.key,
    this.rating,
    this.size = 20,
    this.interactive = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (rating == null && !interactive) {
      return Text(
        '未評価',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = rating != null && starValue <= rating!;

        if (interactive) {
          return GestureDetector(
            onTap: () => onChanged?.call(starValue),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              color: isFilled ? Colors.amber : Colors.grey,
              size: size,
            ),
          );
        }

        return Icon(
          isFilled ? Icons.star : Icons.star_border,
          color: isFilled ? Colors.amber : Colors.grey,
          size: size,
        );
      }),
    );
  }
}
