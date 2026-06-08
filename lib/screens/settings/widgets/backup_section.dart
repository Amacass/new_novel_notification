import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/backup_provider.dart';
import '../../../services/backup_service.dart';

class BackupSection extends ConsumerWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupProvider);
    final isWorking = state.status == BackupStatus.working;

    // 完了・エラー・ロック時にダイアログを出す
    ref.listen<BackupState>(backupProvider, (prev, next) {
      _handleStateChange(context, ref, prev, next);
    });

    return Column(
      children: [
        // エクスポート
        ListTile(
          leading: isWorking && _isExporting(state)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_outlined),
          title: const Text('バックアップをエクスポート'),
          subtitle: const Text('ブックマーク・スタンプ・設定をJSONで保存'),
          enabled: !isWorking,
          onTap: () => ref.read(backupProvider.notifier).export(),
        ),

        // インポート
        ListTile(
          leading: isWorking && !_isExporting(state)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          title: const Text('バックアップをインポート'),
          subtitle: const Text('novelmarkが出力したJSONから復元'),
          enabled: !isWorking,
          onTap: () => _startImport(context, ref),
        ),
      ],
    );
  }

  // エクスポート中かどうかを判定するための簡易フラグ
  //（プレビューがない = エクスポート操作中）
  bool _isExporting(BackupState state) => state.preview == null;

  void _startImport(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポートについて'),
        content: const Text(
          'novelmarkが出力したバックアップファイル（.json）のみ読み込めます。\n\n'
          '他のアプリのファイルや手動で編集したファイルは\n'
          '読み込めない場合があります。\n\n'
          'また、3回連続でインポートに失敗した場合は\nアカウントがロックされます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(backupProvider.notifier).pickAndPreview();
            },
            child: const Text('ファイルを選択'),
          ),
        ],
      ),
    );
  }

  void _handleStateChange(
      BuildContext context, WidgetRef ref, BackupState? prev, BackupState next) {
    if (prev?.status == next.status) return;

    switch (next.status) {
      case BackupStatus.previewReady:
        _showImportPreviewDialog(context, ref, next.preview!);
        break;

      case BackupStatus.success:
        if (next.result != null) {
          _showImportResultDialog(context, ref, next.result!);
        } else {
          // エクスポート成功（シェアシートが開くので追加UIは不要）
          ref.read(backupProvider.notifier).reset();
        }
        break;

      case BackupStatus.error:
        _showErrorSnackBar(context, ref, next.errorMessage ?? 'エラーが発生しました。');
        break;

      case BackupStatus.locked:
        _showLockedDialog(context, ref, next.errorMessage!);
        break;

      default:
        break;
    }
  }

  // ─── プレビューダイアログ ──────────────────────────────────────────────────

  void _showImportPreviewDialog(
      BuildContext context, WidgetRef ref, BackupPreview preview) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('バックアップを復元'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fmt.format(preview.exportedAt.toLocal())} のデータ',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _PreviewRow(
              label: 'ブックマーク',
              value: '${preview.bookmarkCount}件',
            ),
            _PreviewRow(
              label: 'スタンプ',
              value: '${preview.stampCount}件',
            ),
            _PreviewRow(
              label: 'タグ',
              value: '${preview.charmTagCount}件',
            ),
            _PreviewRow(
              label: 'テーマ設定',
              value: preview.hasSettings ? 'あり' : 'なし',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '既存データは上書きされません。\n'
                '既読数は大きい方を、分類済みのtierは\n'
                '既存データを優先します。\n'
                'DBに存在しない小説のブックマークは\nスキップされます。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(backupProvider.notifier).reset();
            },
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(backupProvider.notifier).confirmImport();
            },
            child: const Text('復元する'),
          ),
        ],
      ),
    );
  }

  // ─── 結果ダイアログ ───────────────────────────────────────────────────────

  void _showImportResultDialog(
      BuildContext context, WidgetRef ref, BackupImportResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('インポート完了'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewRow(
              label: '復元したブックマーク',
              value: '${result.importedBookmarks}件',
            ),
            if (result.skippedBookmarks > 0)
              _PreviewRow(
                label: 'スキップ（小説未登録）',
                value: '${result.skippedBookmarks}件',
                isWarning: true,
              ),
            _PreviewRow(
              label: '復元したスタンプ',
              value: '${result.importedStamps}件',
            ),
            if (result.skippedStamps > 0)
              _PreviewRow(
                label: 'スキップ（重複スタンプ）',
                value: '${result.skippedStamps}件',
              ),
            _PreviewRow(
              label: '復元したタグ',
              value: '${result.importedCharmTags}件',
            ),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '詳細:',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              ...result.warnings.take(5).map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('・$w',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
              if (result.warnings.length > 5)
                Text('他 ${result.warnings.length - 5} 件',
                    style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(backupProvider.notifier).reset();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  // ─── エラー ───────────────────────────────────────────────────────────────

  void _showErrorSnackBar(BuildContext context, WidgetRef ref, String message) {
    ref.read(backupProvider.notifier).reset();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _showLockedDialog(BuildContext context, WidgetRef ref, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.lock_outline,
          color: Theme.of(ctx).colorScheme.error,
        ),
        title: const Text('アカウントロック'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(backupProvider.notifier).reset();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// ─── 補助ウィジェット ─────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isWarning
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
          ),
        ],
      ),
    );
  }
}
