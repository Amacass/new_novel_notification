import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/bookmark_provider.dart';
import 'providers/novel_provider.dart';
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
  bool _isProcessingUrl = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // Listen for shared URL and auto-register bookmark
    ref.listen<String?>(sharedUrlProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        ref.read(sharedUrlProvider.notifier).state = null;
        _autoRegisterBookmark(next);
      }
    });

    return MaterialApp.router(
      title: 'Web小説通知',
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

  Future<void> _autoRegisterBookmark(String url) async {
    if (_isProcessingUrl) return;
    _isProcessingUrl = true;

    try {
      final service = ref.read(registerNovelProvider);
      final novel = await service.registerFromUrl(url);

      if (!mounted) return;

      if (novel != null) {
        await ref
            .read(bookmarkListProvider.notifier)
            .addBookmark(novelId: novel.id);

        if (!mounted) return;

        // Update last_read_episode if URL contains episode number
        final parsed = NovelUrlParser.parse(url);
        final bookmarks = ref.read(bookmarkListProvider).valueOrNull ?? [];
        final newBookmark =
            bookmarks.where((b) => b.novelId == novel.id).firstOrNull;

        if (newBookmark != null && parsed?.episodeNumber != null) {
          if (parsed!.episodeNumber! > newBookmark.lastReadEpisode) {
            await ref
                .read(bookmarkListProvider.notifier)
                .updateLastReadEpisode(
                    newBookmark.id, parsed.episodeNumber!);
          }
        }

        if (!mounted) return;

        // Add the new bookmark to the current triage session
        final refreshedBookmarks =
            ref.read(bookmarkListProvider).valueOrNull ?? [];
        final triageBookmark = refreshedBookmarks
            .where((b) => b.novelId == novel.id)
            .firstOrNull;
        if (triageBookmark != null) {
          ref.read(triageProvider.notifier).addNewBookmark(triageBookmark);
        }

        final episodeMsg = parsed?.episodeNumber != null
            ? '（${parsed!.episodeNumber}話まで既読）'
            : '';
        _showSnackBar('「${novel.title}」を追加しました$episodeMsg');
      } else {
        _showSnackBar(
          '対応していないURLです',
          backgroundColor: Colors.red[700],
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'ブックマーク追加に失敗しました',
          backgroundColor: Colors.red[700],
        );
      }
    } finally {
      _isProcessingUrl = false;
    }
  }
}
