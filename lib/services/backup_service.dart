import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── 定数 ────────────────────────────────────────────────────────────────────

const _kFormatVersion = 1;
const _kAppName = 'novelmark';
const _kMaxFileBytes = 10 * 1024 * 1024; // 10 MB
const _kMaxBookmarks = 500;
const _kMaxStampsTotal = 5000;
const _kMaxCharmTags = 200;
const _kMaxStampsPerBookmark = 100;
const _kMaxTagsPerStamp = 20;

// 失敗カウントがこの値に達したらロック
const kImportMaxFailures = 3;

// ─── 値オブジェクト ────────────────────────────────────────────────────────

class BackupPreview {
  const BackupPreview({
    required this.exportedAt,
    required this.bookmarkCount,
    required this.stampCount,
    required this.charmTagCount,
    required this.hasSettings,
    required this.rawData,
  });

  final DateTime exportedAt;
  final int bookmarkCount;
  final int stampCount;
  final int charmTagCount;
  final bool hasSettings;
  final Map<String, dynamic> rawData;
}

class BackupImportResult {
  const BackupImportResult({
    required this.importedBookmarks,
    required this.skippedBookmarks,
    required this.importedStamps,
    required this.skippedStamps,
    required this.importedCharmTags,
    required this.warnings,
  });

  final int importedBookmarks;
  final int skippedBookmarks;
  final int importedStamps;
  final int skippedStamps;
  final int importedCharmTags;
  final List<String> warnings;
}

// ─── 検証エラー ───────────────────────────────────────────────────────────────

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportLockedException implements Exception {
  const ImportLockedException();
  @override
  String toString() => 'インポートがロックされています。管理者にお問い合わせください。';
}

// ─── BackupService ───────────────────────────────────────────────────────────

class BackupService {
  BackupService(this._supabase);

  final SupabaseClient _supabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // エクスポート
  // ═══════════════════════════════════════════════════════════════════════════

  Future<File> export(String themeMode) async {
    final userId = _requireUserId();
    final data = await _buildBackupData(userId, themeMode);
    final json = const JsonEncoder.withIndent('  ').convert(data);
    return _writeFile(json);
  }

  Future<Map<String, dynamic>> _buildBackupData(
      String userId, String themeMode) async {
    // ブックマーク + 小説
    final bookmarkRows = await _supabase
        .from('bookmarks')
        .select('*, novels(site, site_novel_id, url, title, author_name)')
        .eq('user_id', userId)
        .limit(_kMaxBookmarks);

    // レビュー
    final reviewRows = await _supabase
        .from('reviews')
        .select('novel_id, rating, comment, updated_at')
        .eq('user_id', userId);
    final reviewByNovelId = {
      for (final r in reviewRows) r['novel_id'] as int: r,
    };

    // スタンプ + タグ
    final stampRows = await _supabase
        .from('stamps')
        .select('id, novel_id, emoji, episode_number, created_at, stamp_charm_tags(charm_tags(name))')
        .eq('user_id', userId)
        .limit(_kMaxStampsTotal);

    // novelId → [stamps]
    final Map<int, List<Map<String, dynamic>>> stampsByNovelId = {};
    for (final s in stampRows) {
      final nid = s['novel_id'] as int;
      stampsByNovelId.putIfAbsent(nid, () => []).add(s);
    }

    // ユーザー独自 charm_tags
    final tagRows = await _supabase
        .from('charm_tags')
        .select('name, created_at')
        .eq('user_id', userId)
        .eq('is_system', false)
        .limit(_kMaxCharmTags);

    final bookmarks = bookmarkRows.map((bm) {
      final novel = bm['novels'] as Map<String, dynamic>;
      final novelId = bm['novel_id'] as int;
      final review = reviewByNovelId[novelId];
      final stamps = (stampsByNovelId[novelId] ?? [])
          .take(_kMaxStampsPerBookmark)
          .map((s) => {
                'emoji': s['emoji'],
                'episode_number': s['episode_number'],
                'charm_tags': (s['stamp_charm_tags'] as List)
                    .map((t) => (t['charm_tags'] as Map)['name'] as String)
                    .toList(),
                'created_at': s['created_at'],
              })
          .toList();

      return {
        'novel': {
          'site': novel['site'],
          'site_novel_id': novel['site_novel_id'],
          'url': novel['url'],
          'title': novel['title'],
          'author_name': novel['author_name'],
        },
        'last_read_episode': bm['last_read_episode'],
        'memo': bm['memo'],
        'tier': bm['tier'],
        'created_at': bm['created_at'],
        'review': review == null
            ? null
            : {
                'rating': review['rating'],
                'comment': review['comment'],
                'updated_at': review['updated_at'],
              },
        'stamps': stamps,
      };
    }).toList();

    return {
      'backup_format_version': _kFormatVersion,
      'app': _kAppName,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'settings': {'theme_mode': themeMode},
      'user_charm_tags':
          tagRows.map((t) => {'name': t['name'], 'created_at': t['created_at']}).toList(),
      'bookmarks': bookmarks,
    };
  }

  Future<File> _writeFile(String json) async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final name =
        'novelmark_backup_${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(json, encoding: utf8);
    return file;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // インポート
  // ═══════════════════════════════════════════════════════════════════════════

  /// ファイルを読んで検証し、プレビュー情報を返す（DB書き込みなし）
  Future<BackupPreview> loadPreview(File file) async {
    // ファイルサイズ
    final size = await file.length();
    if (size > _kMaxFileBytes) {
      throw const BackupValidationException(
          'ファイルが大きすぎます（上限10MB）。novelmarkが出力したバックアップファイルを選択してください。');
    }

    final content = await file.readAsString(encoding: utf8);
    final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      throw const BackupValidationException(
          'JSONの解析に失敗しました。novelmarkが出力したバックアップファイルを選択してください。');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException(
          'ファイル形式が正しくありません。novelmarkが出力したバックアップファイルを選択してください。');
    }

    _validateStructure(decoded);
    return _buildPreview(decoded);
  }

  /// アカウントロック確認 → DB書き込み実行
  Future<BackupImportResult> executeImport(Map<String, dynamic> data) async {
    final userId = _requireUserId();
    await _checkAndEnforceImportLock(userId);

    try {
      final result = await _importData(userId, data);
      await _resetFailureCount(userId);
      return result;
    } catch (e) {
      await _recordFailure(userId);
      rethrow;
    }
  }

  // ─── バリデーション ────────────────────────────────────────────────────────

  void _validateStructure(Map<String, dynamic> data) {
    // アプリ識別
    if (data['app'] != _kAppName) {
      throw const BackupValidationException(
          'このファイルはnovelmarkのバックアップではありません。');
    }

    // バージョン
    final version = data['backup_format_version'];
    if (version is! int || version < 1 || version > _kFormatVersion) {
      throw BackupValidationException(
          'バックアップのバージョン($version)はサポートされていません。アプリを最新版に更新してください。');
    }

    // exported_at
    _requireIso8601(data, 'exported_at', 'トップレベル');

    // settings
    if (data.containsKey('settings')) {
      final settings = _requireMap(data, 'settings', 'トップレベル');
      if (settings.containsKey('theme_mode')) {
        _requireEnum(settings, 'theme_mode', ['system', 'light', 'dark'], 'settings');
      }
    }

    // user_charm_tags
    final tags = _requireList(data, 'user_charm_tags', 'トップレベル');
    if (tags.length > _kMaxCharmTags) {
      throw BackupValidationException(
          'user_charm_tagsが多すぎます（上限$_kMaxCharmTags件）。');
    }
    for (var i = 0; i < tags.length; i++) {
      _validateCharmTag(tags[i], i);
    }

    // bookmarks
    final bookmarks = _requireList(data, 'bookmarks', 'トップレベル');
    if (bookmarks.length > _kMaxBookmarks) {
      throw BackupValidationException(
          'bookmarksが多すぎます（上限$_kMaxBookmarks件）。');
    }

    var totalStamps = 0;
    for (var i = 0; i < bookmarks.length; i++) {
      final stampsInBm = _validateBookmark(bookmarks[i], i);
      totalStamps += stampsInBm;
    }
    if (totalStamps > _kMaxStampsTotal) {
      throw BackupValidationException(
          'スタンプの合計が多すぎます（上限$_kMaxStampsTotal件）。');
    }
  }

  void _validateCharmTag(dynamic raw, int index) {
    final tag = _asMap(raw, 'user_charm_tags[$index]');
    final name = _requireString(tag, 'name', 'user_charm_tags[$index]');
    if (!name.startsWith('#')) {
      throw BackupValidationException('user_charm_tags[$index].name は # で始まる必要があります。');
    }
    if (name.length > 50) {
      throw BackupValidationException('user_charm_tags[$index].name が長すぎます（上限50文字）。');
    }
    _requireIso8601(tag, 'created_at', 'user_charm_tags[$index]');
  }

  /// スタンプ数を返す
  int _validateBookmark(dynamic raw, int index) {
    final bm = _asMap(raw, 'bookmarks[$index]');
    final ctx = 'bookmarks[$index]';

    // novel (識別子のみ検証)
    final novel = _requireMap(bm, 'novel', ctx);
    _requireEnum(novel, 'site', ['narou', 'hameln', 'arcadia'], '$ctx.novel');
    final siteNovelId = _requireString(novel, 'site_novel_id', '$ctx.novel');
    if (siteNovelId.isEmpty || siteNovelId.length > 100) {
      throw BackupValidationException('$ctx.novel.site_novel_id の長さが不正です。');
    }
    if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(siteNovelId)) {
      throw BackupValidationException('$ctx.novel.site_novel_id に不正な文字が含まれています。');
    }

    // last_read_episode
    final lre = _requireInt(bm, 'last_read_episode', ctx);
    if (lre < 0 || lre > 99999) {
      throw BackupValidationException('$ctx.last_read_episode の値が範囲外です（0〜99999）。');
    }

    // memo
    if (bm['memo'] != null) {
      final memo = _requireString(bm, 'memo', ctx);
      if (memo.length > 1000) {
        throw BackupValidationException('$ctx.memo が長すぎます（上限1000文字）。');
      }
    }

    // tier
    final tier = _requireInt(bm, 'tier', ctx);
    if (![-1, 0, 1, 2, 3].contains(tier)) {
      throw BackupValidationException('$ctx.tier の値が不正です（-1〜3）。');
    }

    _requireIso8601(bm, 'created_at', ctx);

    // review
    if (bm['review'] != null) {
      _validateReview(_asMap(bm['review'], '$ctx.review'), '$ctx.review');
    }

    // stamps
    final stamps = _requireList(bm, 'stamps', ctx);
    if (stamps.length > _kMaxStampsPerBookmark) {
      throw BackupValidationException('$ctx.stamps が多すぎます（上限$_kMaxStampsPerBookmark件）。');
    }
    for (var i = 0; i < stamps.length; i++) {
      _validateStamp(stamps[i], '$ctx.stamps[$i]');
    }
    return stamps.length;
  }

  void _validateReview(Map<String, dynamic> review, String ctx) {
    final rating = _requireInt(review, 'rating', ctx);
    if (rating < 1 || rating > 5) {
      throw BackupValidationException('$ctx.rating は1〜5の整数である必要があります。');
    }
    if (review['comment'] != null) {
      final comment = _requireString(review, 'comment', ctx);
      if (comment.length > 2000) {
        throw BackupValidationException('$ctx.comment が長すぎます（上限2000文字）。');
      }
    }
    _requireIso8601(review, 'updated_at', ctx);
  }

  void _validateStamp(dynamic raw, String ctx) {
    final stamp = _asMap(raw, ctx);
    final emoji = _requireString(stamp, 'emoji', ctx);
    if (emoji.isEmpty || emoji.length > 8) {
      throw BackupValidationException('$ctx.emoji の値が不正です。');
    }

    if (stamp['episode_number'] != null) {
      final ep = _requireInt(stamp, 'episode_number', ctx);
      if (ep < 1 || ep > 99999) {
        throw BackupValidationException('$ctx.episode_number の値が範囲外です（1〜99999）。');
      }
    }

    final tags = _requireList(stamp, 'charm_tags', ctx);
    if (tags.length > _kMaxTagsPerStamp) {
      throw BackupValidationException('$ctx.charm_tags が多すぎます（上限$_kMaxTagsPerStamp件）。');
    }
    for (final t in tags) {
      if (t is! String || t.isEmpty || t.length > 50) {
        throw BackupValidationException('$ctx.charm_tags に不正な値が含まれています。');
      }
    }

    _requireIso8601(stamp, 'created_at', ctx);
  }

  // ─── プレビュー ────────────────────────────────────────────────────────────

  BackupPreview _buildPreview(Map<String, dynamic> data) {
    final bookmarks = data['bookmarks'] as List;
    var stampCount = 0;
    for (final bm in bookmarks) {
      stampCount += ((bm as Map)['stamps'] as List).length;
    }
    return BackupPreview(
      exportedAt: DateTime.parse(data['exported_at'] as String),
      bookmarkCount: bookmarks.length,
      stampCount: stampCount,
      charmTagCount: (data['user_charm_tags'] as List).length,
      hasSettings: data.containsKey('settings'),
      rawData: data,
    );
  }

  // ─── インポート本体 ────────────────────────────────────────────────────────

  Future<BackupImportResult> _importData(
      String userId, Map<String, dynamic> data) async {
    final warnings = <String>[];
    var importedBookmarks = 0;
    var skippedBookmarks = 0;
    var importedStamps = 0;
    var skippedStamps = 0;
    var importedCharmTags = 0;

    // Phase 1: ユーザー独自 charm_tags を登録
    final tagRows = (data['user_charm_tags'] as List).cast<Map<String, dynamic>>();
    final tagNameToId = <String, int>{};

    for (final tag in tagRows) {
      final result = await _supabase
          .from('charm_tags')
          .upsert(
            {'name': tag['name'], 'user_id': userId, 'is_system': false},
            onConflict: 'name,user_id',
            ignoreDuplicates: false,
          )
          .select('id, name');
      if (result.isNotEmpty) {
        tagNameToId[result.first['name'] as String] = result.first['id'] as int;
        importedCharmTags++;
      }
    }

    // Phase 2: 既存 charm_tags (system + user) の name→id を補完
    final existingTags = await _supabase
        .from('charm_tags')
        .select('id, name')
        .or('is_system.eq.true,user_id.eq.$userId');
    for (final t in existingTags) {
      tagNameToId.putIfAbsent(t['name'] as String, () => t['id'] as int);
    }

    // Phase 3: ブックマーク
    final bookmarks = (data['bookmarks'] as List).cast<Map<String, dynamic>>();

    for (final bm in bookmarks) {
      final novel = bm['novel'] as Map<String, dynamic>;
      final novelId = await _lookupNovelId(
          novel['site'] as String, novel['site_novel_id'] as String);

      if (novelId == null) {
        skippedBookmarks++;
        warnings.add(
            '「${novel['title'] ?? novel['site_novel_id']}」はDBに存在しないためスキップしました。');
        continue;
      }

      // bookmark UPSERT（既存データ優先ルール）
      final existing = await _supabase
          .from('bookmarks')
          .select('id, last_read_episode, memo, tier')
          .eq('user_id', userId)
          .eq('novel_id', novelId)
          .maybeSingle();

      int bookmarkId;
      if (existing == null) {
        final inserted = await _supabase
            .from('bookmarks')
            .insert({
              'user_id': userId,
              'novel_id': novelId,
              'last_read_episode': bm['last_read_episode'],
              'memo': bm['memo'],
              'tier': bm['tier'],
              'created_at': bm['created_at'],
            })
            .select('id')
            .single();
        bookmarkId = inserted['id'] as int;
        importedBookmarks++;
      } else {
        bookmarkId = existing['id'] as int;
        // 既読数は大きい方、memo/tier は既存優先（未設定なら新規採用）
        await _supabase.from('bookmarks').update({
          'last_read_episode': [
            existing['last_read_episode'] as int,
            bm['last_read_episode'] as int,
          ].reduce((a, b) => a > b ? a : b),
          'memo': existing['memo'] ?? bm['memo'],
          'tier': (existing['tier'] as int) == -1
              ? bm['tier']
              : existing['tier'],
        }).eq('id', bookmarkId);
        importedBookmarks++;
      }

      // review UPSERT（既存優先）
      final review = bm['review'] as Map<String, dynamic>?;
      if (review != null) {
        await _supabase.from('reviews').upsert(
          {
            'user_id': userId,
            'novel_id': novelId,
            'rating': review['rating'],
            'comment': review['comment'],
          },
          onConflict: 'user_id,novel_id',
          ignoreDuplicates: true, // 既存レコードは変更しない
        );
      }

      // stamps（重複チェック付き）
      final stamps = (bm['stamps'] as List).cast<Map<String, dynamic>>();
      for (final stamp in stamps) {
        final createdAt = DateTime.parse(stamp['created_at'] as String);
        final windowStart = createdAt.subtract(const Duration(minutes: 1));
        final windowEnd = createdAt.add(const Duration(minutes: 1));

        final epNum = stamp['episode_number'] as int?;
        var dupQuery = _supabase
            .from('stamps')
            .select('id')
            .eq('user_id', userId)
            .eq('novel_id', novelId)
            .eq('emoji', stamp['emoji'])
            .gte('created_at', windowStart.toIso8601String())
            .lte('created_at', windowEnd.toIso8601String());
        // episode_number が null の場合と非 null の場合で分岐
        if (epNum == null) {
          dupQuery = dupQuery.isFilter('episode_number', null);
        } else {
          dupQuery = dupQuery.eq('episode_number', epNum);
        }
        final dup = await dupQuery.maybeSingle();

        if (dup != null) {
          skippedStamps++;
          continue;
        }

        final insertedStamp = await _supabase
            .from('stamps')
            .insert({
              'user_id': userId,
              'novel_id': novelId,
              'emoji': stamp['emoji'],
              'episode_number': stamp['episode_number'],
              'created_at': stamp['created_at'],
            })
            .select('id')
            .single();
        final stampId = insertedStamp['id'] as int;
        importedStamps++;

        // charm_tags の紐付け
        final tagNames = (stamp['charm_tags'] as List).cast<String>();
        for (final name in tagNames) {
          final tagId = tagNameToId[name];
          if (tagId == null) continue;
          await _supabase.from('stamp_charm_tags').upsert(
                {'stamp_id': stampId, 'charm_tag_id': tagId},
                onConflict: 'stamp_id,charm_tag_id',
                ignoreDuplicates: true,
              );
        }
      }
    }

    // Phase 4: settings
    if (data.containsKey('settings')) {
      final settings = data['settings'] as Map<String, dynamic>;
      if (settings.containsKey('theme_mode')) {
        await _supabase.from('profiles').update(
            {'theme_mode': settings['theme_mode']}).eq('id', userId);
      }
    }

    return BackupImportResult(
      importedBookmarks: importedBookmarks,
      skippedBookmarks: skippedBookmarks,
      importedStamps: importedStamps,
      skippedStamps: skippedStamps,
      importedCharmTags: importedCharmTags,
      warnings: warnings,
    );
  }

  // ─── ロック管理 ──────────────────────────────────────────────────────────

  Future<void> _checkAndEnforceImportLock(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('import_failure_count, import_locked_at')
        .eq('id', userId)
        .single();

    if (profile['import_locked_at'] != null) {
      throw const ImportLockedException();
    }
  }

  Future<void> _recordFailure(String userId) async {
    // 現在のカウントを取得してインクリメント
    final profile = await _supabase
        .from('profiles')
        .select('import_failure_count')
        .eq('id', userId)
        .single();

    final current = (profile['import_failure_count'] as int? ?? 0);
    final next = current + 1;
    final shouldLock = next >= kImportMaxFailures;

    await _supabase.from('profiles').update({
      'import_failure_count': next,
      if (shouldLock) 'import_locked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> _resetFailureCount(String userId) async {
    await _supabase.from('profiles').update({
      'import_failure_count': 0,
    }).eq('id', userId);
  }

  // ─── DB ヘルパー ──────────────────────────────────────────────────────────

  /// novels テーブルで site + site_novel_id を検索し、存在すれば id を返す
  /// 存在しなければ null を返す（novels テーブルには書き込まない）
  Future<int?> _lookupNovelId(String site, String siteNovelId) async {
    final row = await _supabase
        .from('novels')
        .select('id')
        .eq('site', site)
        .eq('site_novel_id', siteNovelId)
        .maybeSingle();
    return row?['id'] as int?;
  }

  // ─── バリデーション ヘルパー ─────────────────────────────────────────────

  Map<String, dynamic> _asMap(dynamic value, String ctx) {
    if (value is! Map<String, dynamic>) {
      throw BackupValidationException('$ctx はオブジェクトである必要があります。');
    }
    return value;
  }

  Map<String, dynamic> _requireMap(
      Map<String, dynamic> parent, String key, String ctx) {
    if (!parent.containsKey(key) || parent[key] == null) {
      throw BackupValidationException('$ctx.$key が見つかりません。');
    }
    return _asMap(parent[key], '$ctx.$key');
  }

  List<dynamic> _requireList(
      Map<String, dynamic> parent, String key, String ctx) {
    if (!parent.containsKey(key)) {
      throw BackupValidationException('$ctx.$key が見つかりません。');
    }
    final v = parent[key];
    if (v is! List) {
      throw BackupValidationException('$ctx.$key は配列である必要があります。');
    }
    return v;
  }

  String _requireString(Map<String, dynamic> parent, String key, String ctx) {
    final v = parent[key];
    if (v is! String) {
      throw BackupValidationException('$ctx.$key は文字列である必要があります。');
    }
    return v;
  }

  int _requireInt(Map<String, dynamic> parent, String key, String ctx) {
    final v = parent[key];
    if (v is! int) {
      throw BackupValidationException('$ctx.$key は整数である必要があります。');
    }
    return v;
  }

  void _requireEnum(Map<String, dynamic> parent, String key,
      List<String> allowed, String ctx) {
    final v = _requireString(parent, key, ctx);
    if (!allowed.contains(v)) {
      throw BackupValidationException(
          '$ctx.$key の値「$v」は不正です。許容値: ${allowed.join(', ')}');
    }
  }

  void _requireIso8601(
      Map<String, dynamic> parent, String key, String ctx) {
    final v = _requireString(parent, key, ctx);
    try {
      DateTime.parse(v);
    } catch (_) {
      throw BackupValidationException('$ctx.$key は ISO8601 形式の日時である必要があります。');
    }
  }

  // ─── その他ヘルパー ───────────────────────────────────────────────────────

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('ログインが必要です。');
    return userId;
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
