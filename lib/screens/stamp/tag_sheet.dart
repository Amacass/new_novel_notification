import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/charm_tag_provider.dart';
import 'widgets/charm_tag_chip.dart';

class TagSheet extends ConsumerStatefulWidget {
  final int stampId;
  final int novelId;
  final List<int> selectedTagIds;

  const TagSheet({
    super.key,
    required this.stampId,
    required this.novelId,
    this.selectedTagIds = const [],
  });

  static Future<void> show(
    BuildContext context, {
    required int stampId,
    required int novelId,
    List<int> selectedTagIds = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TagSheet(
        stampId: stampId,
        novelId: novelId,
        selectedTagIds: selectedTagIds,
      ),
    );
  }

  @override
  ConsumerState<TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<TagSheet> {
  late Set<int> _selectedIds;
  final _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedTagIds);
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _toggleTag(int tagId) async {
    final service = ref.read(charmTagServiceProvider);
    if (_selectedIds.contains(tagId)) {
      await service.removeTagFromStamp(widget.stampId, tagId);
      setState(() => _selectedIds.remove(tagId));
    } else {
      await service.addTagToStamp(widget.stampId, tagId);
      setState(() => _selectedIds.add(tagId));
    }
    ref.invalidate(novelTagsProvider(widget.novelId));
  }

  void _addNewTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) return;

    final tag =
        await ref.read(charmTagServiceProvider).createUserTag('#$name');
    _newTagController.clear();
    _toggleTag(tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(charmTagsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '魅力タグ',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'この作品の魅力を記録しよう',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),

              // Tag list
              Expanded(
                child: tagsAsync.when(
                  data: (tags) => SingleChildScrollView(
                    controller: scrollController,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        return CharmTagChip(
                          tag: tag,
                          isSelected: _selectedIds.contains(tag.id),
                          onTap: () => _toggleTag(tag.id),
                        );
                      }).toList(),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('エラー: $e')),
                ),
              ),

              // Add new tag
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      decoration: const InputDecoration(
                        hintText: 'タグを追加（例: 伏線回収）',
                        isDense: true,
                        prefixText: '#',
                      ),
                      onSubmitted: (_) => _addNewTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addNewTag,
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
