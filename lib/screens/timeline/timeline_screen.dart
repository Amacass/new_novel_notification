import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../models/bookmark.dart';
import '../../models/novel.dart';
import '../../providers/bookmark_provider.dart';
import '../../utils/error_message.dart';
import '../../widgets/site_badge.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  Set<NovelSite> _siteFilter = {};

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タイムライン'),
      ),
      body: Column(
        children: [
          // Site filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _siteChip(null),
                for (final site in NovelSite.values) _siteChip(site),
              ],
            ),
          ),

          Expanded(
            child: bookmarksAsync.when(
              data: (bookmarks) {
                var items = bookmarks
                    .where((b) => b.tier != 0 && b.novel != null)
                    .where((b) => _siteFilter.isEmpty || _siteFilter.contains(b.novel!.site))
                    .toList()
                  ..sort((a, b) {
                    final aDate = a.novel!.siteUpdatedAt;
                    final bDate = b.novel!.siteUpdatedAt;
                    if (aDate != null && bDate != null) return bDate.compareTo(aDate);
                    if (aDate != null) return -1;
                    if (bDate != null) return 1;
                    return b.createdAt.compareTo(a.createdAt);
                  });

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.update,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '該当する作品がありません',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(bookmarkListProvider.notifier).refresh(),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final bookmark = items[index];
                      return _TimelineItem(bookmark: bookmark);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(errorMessage(error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _siteChip(NovelSite? site) {
    final selected = site == null ? _siteFilter.isEmpty : _siteFilter.contains(site);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: site != null
            ? SizedBox(
                width: 16,
                height: 16,
                child: SiteBadge(site: site, size: 16),
              )
            : null,
        label: Text(
          site == null ? '全て' : _siteLabel(site),
          style: const TextStyle(fontSize: 12),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (site == null) {
              _siteFilter = {};
            } else if (_siteFilter.contains(site)) {
              _siteFilter = Set.from(_siteFilter)..remove(site);
            } else {
              _siteFilter = Set.from(_siteFilter)..add(site);
            }
          });
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _siteLabel(NovelSite site) => switch (site) {
        NovelSite.narou => 'なろう',
        NovelSite.hameln => 'ハーメルン',
        NovelSite.arcadia => 'Arcadia',
      };
}

class _TimelineItem extends StatelessWidget {
  final Bookmark bookmark;

  const _TimelineItem({required this.bookmark});

  @override
  Widget build(BuildContext context) {
    final novel = bookmark.novel!;
    final unread = bookmark.unreadCount;

    return ListTile(
      leading: SiteBadge(site: novel.site, size: 36),
      title: Text(
        novel.title ?? '不明な小説',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        novel.siteUpdatedAt != null
            ? '${novel.authorName ?? ''} · ${timeago.format(novel.siteUpdatedAt!, locale: 'ja')}'
            : novel.authorName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$unread',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 20),
            onPressed: () => _openReadUrl(),
            visualDensity: VisualDensity.compact,
            tooltip: '続きを読む',
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
      onTap: () => context.push('/novel/${novel.id}'),
    );
  }

  Future<void> _openReadUrl() async {
    final novel = bookmark.novel!;
    final url = bookmark.lastReadEpisode > 0
        ? novel.episodeUrl(bookmark.lastReadEpisode)
        : novel.url;
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {}
    }
  }
}
