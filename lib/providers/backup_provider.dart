import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/supabase.dart';
import '../providers/theme_provider.dart';
import '../services/backup_service.dart';

// ─── 状態 ────────────────────────────────────────────────────────────────────

enum BackupStatus { idle, working, previewReady, success, error, locked }

class BackupState {
  const BackupState({
    this.status = BackupStatus.idle,
    this.preview,
    this.result,
    this.errorMessage,
  });

  final BackupStatus status;
  final BackupPreview? preview;
  final BackupImportResult? result;
  final String? errorMessage;

  BackupState copyWith({
    BackupStatus? status,
    BackupPreview? preview,
    BackupImportResult? result,
    String? errorMessage,
  }) =>
      BackupState(
        status: status ?? this.status,
        preview: preview ?? this.preview,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

// ─── プロバイダー ─────────────────────────────────────────────────────────────

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(supabase);
});

final backupProvider =
    StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier(ref);
});

// ─── Notifier ────────────────────────────────────────────────────────────────

class BackupNotifier extends StateNotifier<BackupState> {
  BackupNotifier(this._ref) : super(const BackupState());

  final Ref _ref;

  BackupService get _service => _ref.read(backupServiceProvider);

  // ═══════════════════════════════════════════════════════════════════════════
  // エクスポート
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> export() async {
    state = const BackupState(status: BackupStatus.working);
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeMode = prefs.getString('theme_mode') ?? 'system';
      final file = await _service.export(themeMode);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'novelmark バックアップ',
      );
      state = const BackupState(status: BackupStatus.success);
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        errorMessage: 'エクスポートに失敗しました: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // インポート
  // ═══════════════════════════════════════════════════════════════════════════

  /// ファイルを選択してプレビューを読み込む
  Future<void> pickAndPreview() async {
    state = const BackupState(status: BackupStatus.working);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
        withReadStream: false,
      );
      if (result == null || result.files.isEmpty) {
        state = const BackupState(status: BackupStatus.idle);
        return;
      }

      final path = result.files.single.path;
      if (path == null) {
        state = const BackupState(
          status: BackupStatus.error,
          errorMessage: 'ファイルパスを取得できませんでした。',
        );
        return;
      }

      final preview = await _service.loadPreview(File(path));
      state = BackupState(
        status: BackupStatus.previewReady,
        preview: preview,
      );
    } on ImportLockedException {
      state = const BackupState(
        status: BackupStatus.locked,
        errorMessage:
            'インポートが3回連続で失敗したためロックされています。\nサポートにお問い合わせください。',
      );
    } on BackupValidationException catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        errorMessage: 'ファイルの読み込みに失敗しました: $e',
      );
    }
  }

  /// プレビュー確認後、実際にインポートを実行する
  Future<void> confirmImport() async {
    final preview = state.preview;
    if (preview == null) return;

    state = BackupState(
      status: BackupStatus.working,
      preview: preview,
    );

    try {
      final result = await _service.executeImport(preview.rawData);

      // theme_mode をローカルにも反映
      final settings = preview.rawData['settings'] as Map<String, dynamic>?;
      if (settings != null && settings.containsKey('theme_mode')) {
        final mode = _parseThemeMode(settings['theme_mode'] as String);
        _ref.read(themeModeProvider.notifier).setThemeMode(mode);
      }

      // 全 provider を無効化してリフレッシュ
      _ref.invalidate(themeModeProvider);

      state = BackupState(
        status: BackupStatus.success,
        result: result,
      );
    } on ImportLockedException {
      state = const BackupState(
        status: BackupStatus.locked,
        errorMessage:
            'インポートが3回連続で失敗したためロックされています。\nサポートにお問い合わせください。',
      );
    } on BackupValidationException catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      state = BackupState(
        status: BackupStatus.error,
        errorMessage: 'インポートに失敗しました: $e',
      );
    }
  }

  void reset() => state = const BackupState();

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
