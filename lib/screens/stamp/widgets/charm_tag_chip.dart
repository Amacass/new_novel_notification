import 'package:flutter/material.dart';

import '../../../models/charm_tag.dart';

class CharmTagChip extends StatelessWidget {
  final CharmTag tag;
  final bool isSelected;
  final VoidCallback? onTap;

  const CharmTagChip({
    super.key,
    required this.tag,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(
        tag.name,
        style: TextStyle(
          fontSize: 13,
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      avatar: tag.isSystem
          ? null
          : Icon(
              Icons.person,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }
}
