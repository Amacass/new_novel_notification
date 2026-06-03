import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/bookmark_provider.dart';
import 'providers/novel_provider.dart';
import 'providers/realtime_provider.dart';
import 'providers/shared_url_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/triage_provider.dart';
import 'utils/url_parser.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final _urlQueue = <String>[];
  bool _isProcessingQueue = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    ref.watch(realtimeProvider);

    // Listen for shared URLs and process them as a queue
    ref.listen<List<String>>(sharedUrlProvider, (prev, next) {
      if (next.isNotEmpty) {
        ref.read(sharedUrlProvider.notifier).state = const [];
        _urlQueue.addAll(next);
        _drainQueue();
      }
    });

    return MaterialApp.router(
      title: 'Novelmark',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  GoRouter get router => ref.read(routerProvider);

  void _showSnackBar(String message, {Color? backgroundColor}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = router.routerDelegate.navigatorKey.currentContext;
      if (nav == null) return;
      ScaffoldMessenger.maybeOf(nav)?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  void _drainQueue() {
    if (_isProcessingQueue || _urlQueue.isEmpty) return;
    _isProcessingQueue = true;
    final url = _urlQueue.removeAt(0);
    _autoRegisterBookmark(url).then((_) {
      _isProcessingQueue = false;
      _drainQueue();
    });
  }

  Future<void> _autoRegisterBookmark(String url) async {
    try {
      final service = ref.read(registerNovelProvider);
      final (novel, isNewNovel) = await service.registerFromUrl(url);

      if (!mounted) return;

      if (novel == null) {
        _showSnackBar('対応していないURLです', backgroundColor: Colors.red[700]);
        return;
      }

      final parsed = NovelUrlParser.parse(url);
      final isNew = await ref
          .read(bookmarkListProvider.notifier)
          .addBookmark(novelId: novel.id);

      if (!mounted) return;

      if (!isNew) {
        final bookmarks = ref.read(bookmarkListProvider).valueOrNull ?? [];
        final existing = bookmarks.where((b) => b.novelId == novel.id).firstOrNull;

        // Update reading progress if URL contains a newer episode number
        if (existing != null &&
            parsed?.episodeNumber != null &&
            parsed!.episodeNumber! > existing.lastReadEpisode) {
          await ref
              .read(bookmarkListProvider.notifier)
              .updateLastReadEpisode(existing.id, parsed.episodeNumber!);
          if (!mounted) return;
          _showSnackBar('「${novel.title}」の既読を${parsed.episodeNumber}話に更新しました');
          return;
        }

        if (existing != null) {
          ref.read(triageProvider.notifier).addDuplicateBookmark(existing);
        }
        _showSnackBar('「${novel.title}」は既に登録済みです');
        return;
      }

      // Update last_read_episode based on URL episode or novel's current total
      final bookmarks = ref.read(bookmarkListProvider).valueOrNull ?? [];
      final newBookmark =
          bookmarks.where((b) => b.novelId == novel.id).firstOrNull;

      if (newBookmark != null) {
        if (parsed?.episodeNumber != null) {
          await ref
              .read(bookmarkListProvider.notifier)
              .updateLastReadEpisode(newBookmark.id, parsed!.episodeNumber!);
        }
      }

      if (!mounted) return;

      // Add to current triage session
      final refreshedBookmarks =
          ref.read(bookmarkListProvider).valueOrNull ?? [];
      final triageBookmark =
          refreshedBookmarks.where((b) => b.novelId == novel.id).firstOrNull;
      if (triageBookmark != null) {
        ref.read(triageProvider.notifier).addNewBookmark(triageBookmark);
      }

      final episodeMsg = parsed?.episodeNumber != null
          ? '（${parsed!.episodeNumber}話まで既読）'
          : '';
      _showSnackBar('「${novel.title}」を追加しました$episodeMsg');
    } catch (e) {
      if (mounted) {
        _showSnackBar('登録に失敗しました。', backgroundColor: Colors.red[700]);
      }
    }
  }
}
