import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';

enum CategoryPickMode { assign, filter }

class CategoryPickSheet extends ConsumerStatefulWidget {
  final Set<int> initialSelectedIds;
  final CategoryPickMode mode;

  const CategoryPickSheet({
    super.key,
    required this.initialSelectedIds,
    required this.mode,
  });

  static Future<Set<int>?> show(
    BuildContext context, {
    required Set<int> initialSelectedIds,
    CategoryPickMode mode = CategoryPickMode.assign,
  }) {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickSheet(
        initialSelectedIds: initialSelectedIds,
        mode: mode,
      ),
    );
  }

  @override
  ConsumerState<CategoryPickSheet> createState() => _CategoryPickSheetState();
}

class _CategoryPickSheetState extends ConsumerState<CategoryPickSheet> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
  }

  void _toggle(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _done() {
    Navigator.pop(context, Set<int>.from(_selectedIds));
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    String selectedColor = BookshelfCategory.colorToHex(
      BookshelfCategory.presetColors.first,
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('カテゴリを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'カテゴリ名',
                  hintText: '例: ファンタジー',
                ),
                autofocus: true,
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              const Text('色を選択', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BookshelfCategory.presetColors.map((color) {
                  final hex = BookshelfCategory.colorToHex(color);
                  final isSelected = hex == selectedColor;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Colors.black,
                                width: 2.5,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, {'name': name, 'color': selectedColor});
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();

    if (result == null || !mounted) return;
    try {
      final category = await ref
          .read(categoryListProvider.notifier)
          .create(result['name']!, result['color']!);
      if (mounted) setState(() => _selectedIds.add(category.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _showEditDialog(BookshelfCategory category) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('名前を変更'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('色を変更'),
              onTap: () => Navigator.pop(ctx, 'color'),
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(ctx).colorScheme.error),
              title: Text(
                '削除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'rename') {
      await _showRenameDialog(category);
    } else if (action == 'color') {
      await _showColorDialog(category);
    } else if (action == 'delete') {
      await _confirmDelete(category);
    }
  }

  Future<void> _showRenameDialog(BookshelfCategory category) async {
    final controller = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリ名を変更'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty || name == category.name) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, name);
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || !mounted) return;
    await ref.read(categoryListProvider.notifier).rename(category.id, result);
  }

  Future<void> _showColorDialog(BookshelfCategory category) async {
    String selectedColor = category.color;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('色を変更'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BookshelfCategory.presetColors.map((color) {
              final hex = BookshelfCategory.colorToHex(color);
              final isSelected = hex == selectedColor;
              return GestureDetector(
                onTap: () => setDialogState(() => selectedColor = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black, width: 2.5)
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selectedColor),
              child: const Text('変更'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    await ref.read(categoryListProvider.notifier).updateColor(category.id, result);
  }

  Future<void> _confirmDelete(BookshelfCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリを削除'),
        content: Text('「${category.name}」を削除しますか？\n付与中の作品からも外れます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(categoryListProvider.notifier).delete(category.id);
      setState(() => _selectedIds.remove(category.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final title = widget.mode == CategoryPickMode.assign ? 'カテゴリ' : 'カテゴリで絞り込み';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _done,
                    child: const Text('完了'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category list
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'カテゴリがありません',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('カテゴリを追加'),
                              onPressed: _showCreateDialog,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final isSelected = _selectedIds.contains(category.id);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 10,
                            backgroundColor: category.colorValue,
                          ),
                          title: Text(category.name),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (_) => _toggle(category.id),
                          ),
                          onTap: () => _toggle(category.id),
                          onLongPress: () => _showEditDialog(category),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('エラー: $e')),
                ),
              ),

              // Add new category button
              categoriesAsync.whenOrNull(
                    data: (cats) => cats.isNotEmpty
                        ? TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('新規カテゴリを追加'),
                            onPressed: _showCreateDialog,
                          )
                        : null,
                  ) ??
                  const SizedBox.shrink(),
            ],
          ),
        );
      },
    );
  }
}
