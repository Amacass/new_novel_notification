import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/supabase.dart';
import '../../config/theme.dart';
import '../../models/bookmark.dart';
import '../../models/novel.dart';
import '../../models/recommendation.dart';
import '../../providers/amazon_link_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/novel_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/stamp_provider.dart';
import '../../utils/error_message.dart';
import '../../widgets/category_pick_sheet.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/site_badge.dart';
import '../../widgets/tier_badge.dart';
import '../../widgets/tier_change_sheet.dart';
import '../recommend/widgets/recommendation_card.dart';
import '../stamp/stamp_sheet.dart';

class NovelDetailScreen extends ConsumerStatefulWidget {
  final int novelId;

  const NovelDetailScreen({super.key, required this.novelId});

  @override
  ConsumerState<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends ConsumerState<NovelDetailScreen>
    with WidgetsBindingObserver {
  bool _openedBrowser = false;
  bool _unreadBannerShown = false;
  Novel? _currentNovel;
  Bookmark? _currentBookmark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _openedBrowser) {
      _openedBrowser = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showReadBanner());
    }
  }

  void _showReadBanner() {
    final novel = _currentNovel;
    final bookmark = _currentBookmark;
    if (novel == null || bookmark == null || !mounted) return;
    if (novel.totalEpisodes <= bookmark.lastReadEpisode) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('最新話まで読みましたか？'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '更新',
          onPressed: () => _updateToLatest(bookmark, novel.totalEpisodes),
        ),
      ),
    );
  }

  void _updateToLatest(Bookmark bookmark, int newEpisode) {
    final oldEpisode = bookmark.lastReadEpisode;
    ref
        .read(bookmarkListProvider.notifier)
        .updateLastReadEpisode(bookmark.id, newEpisode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('既読を第$newEpisode話に更新しました'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '元に戻す',
          onPressed: () => ref
              .read(bookmarkListProvider.notifier)
              .updateLastReadEpisode(bookmark.id, oldEpisode),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final novelAsync = ref.watch(novelDetailProvider(widget.novelId));
    final reviewAsync = ref.watch(novelReviewProvider(widget.novelId));
    final bookmarks = ref.watch(bookmarkListProvider);
    final stampsAsync = ref.watch(novelStampsProvider(widget.novelId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('小説詳細'),
      ),
      body: novelAsync.when(
        data: (novel) {
          if (novel == null) {
            return const Center(child: Text('小説が見つかりません'));
          }

          final bookmark = bookmarks.valueOrNull
              ?.where((b) => b.novelId == widget.novelId)
              .firstOrNull;
          final review = reviewAsync.valueOrNull;
          final stamps = stampsAsync.valueOrNull ?? [];

          // Cache for lifecycle callbacks
          _currentNovel = novel;
          _currentBookmark = bookmark;

          // Show banner once when entering with unread episodes
          if (!_unreadBannerShown &&
              bookmark != null &&
              bookmark.unreadCount > 0) {
            _unreadBannerShown = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _showReadBanner(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    SiteBadge(site: novel.site, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            novel.title ?? '不明な小説',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            novel.authorName ?? '不明な作者',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(label: Text(novel.serialStatus.displayName)),
                    const SizedBox(width: 8),
                    Text('全${novel.totalEpisodes}話'),
                    const Spacer(),
                    // Tier badge (tap to change)
                    if (bookmark != null && bookmark.tier >= 0)
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final newTier = await TierChangeSheet.show(
                            context,
                            currentTier: bookmark.tier,
                          );
                          if (newTier != null) {
                            ref
                                .read(bookmarkListProvider.notifier)
                                .updateTier(bookmark.id, newTier);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TierBadge(tier: bookmark.tier, size: 28),
                              const SizedBox(width: 4),
                              Text(
                                DeskTheme.tierLabel(bookmark.tier),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const Divider(height: 32),

                // Stamp button
                if (bookmark != null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Text('📝', style: TextStyle(fontSize: 18)),
                      label: const Text('スタンプを押す'),
                      onPressed: () => StampSheet.show(
                        context,
                        novelId: widget.novelId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Stamp history
                if (stamps.isNotEmpty) ...[
                  _SectionTitle(title: 'スタンプ履歴'),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: stamps.length,
                      itemBuilder: (context, index) {
                        final stamp = stamps[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              Text(
                                stamp.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              Text(
                                _formatDate(stamp.createdAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],


                // Bookmark info (reading progress)
                if (bookmark != null) ...[
                  _SectionTitle(title: 'しおり'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.bookmark),
                      title: Text('既読: 第${bookmark.lastReadEpisode}話まで'),
                      subtitle: bookmark.unreadCount > 0
                          ? Text('未読 ${bookmark.unreadCount}話')
                          : const Text('最新話まで読了'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEpisodeDialog(
                            bookmark.id,
                            bookmark.lastReadEpisode,
                            novel.totalEpisodes),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Review
                _SectionTitle(title: '評価・感想'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RatingStars(
                          rating: review?.rating,
                          size: 32,
                          interactive: true,
                          onChanged: (rating) {
                            ref.read(registerNovelProvider).upsertReview(
                                  novelId: widget.novelId,
                                  rating: rating,
                                  comment: review?.comment,
                                );
                            ref.invalidate(
                                novelReviewProvider(widget.novelId));
                          },
                        ),
                        const SizedBox(height: 12),
                        if (review?.comment != null &&
                            review!.comment!.isNotEmpty)
                          Text(review.comment!)
                        else
                          Text(
                            '感想を追加...',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('編集'),
                            onPressed: () =>
                                _showCommentDialog(review?.comment),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Memo
                if (bookmark != null) ...[
                  _SectionTitle(title: 'メモ'),
                  Card(
                    child: ListTile(
                      title: Text(
                        bookmark.memo?.isNotEmpty == true
                            ? bookmark.memo!
                            : 'メモを追加...',
                        style: bookmark.memo?.isNotEmpty != true
                            ? TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )
                            : null,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showMemoDialog(bookmark.id, bookmark.memo),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Genre classification
                if (bookmark != null) ...[
                  _SectionTitle(title: '分類'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: SegmentedButton<BookmarkGenre?>(
                        segments: const [
                          ButtonSegment(
                            value: null,
                            label: Text('未分類'),
                            icon: Icon(Icons.help_outline, size: 16),
                          ),
                          ButtonSegment(
                            value: BookmarkGenre.original,
                            label: Text('オリジナル'),
                            icon: Icon(Icons.auto_stories, size: 16),
                          ),
                          ButtonSegment(
                            value: BookmarkGenre.derivative,
                            label: Text('二次創作'),
                            icon: Icon(Icons.people_outline, size: 16),
                          ),
                        ],
                        selected: {bookmark.genre},
                        onSelectionChanged: (selected) {
                          final genre = selected.first;
                          ref
                              .read(bookmarkListProvider.notifier)
                              .updateGenre(bookmark.id, genre);
                        },
                        emptySelectionAllowed: true,
                        multiSelectionEnabled: false,
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Category assignment
                if (bookmark != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SectionTitle(title: 'カテゴリ'),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('編集'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showCategorySheet(bookmark),
                      ),
                    ],
                  ),
                  if (bookmark.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '未分類',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: bookmark.categories.map((cat) {
                          return Chip(
                            avatar: CircleAvatar(
                              radius: 6,
                              backgroundColor: cat.colorValue,
                            ),
                            label: Text(
                              cat.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                ],

                // Amazon links
                ...ref
                    .watch(novelAmazonLinksProvider(widget.novelId))
                    .maybeWhen(
                      data: (links) => links.isEmpty
                          ? []
                          : [
                              _SectionTitle(title: 'Amazonで購入'),
                              ...links.map(
                                (link) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      label: Text(
                                          '${link.label}（外部サイト: Amazon）↗'),
                                      onPressed: () => _openUrl(link.url),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                      orElse: () => [],
                    ),

                // Open in browser
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('サイトで読む'),
                    onPressed: () {
                      final targetUrl = _buildReadUrl(novel, bookmark);
                      _openedBrowser = true;
                      _openUrl(targetUrl);
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Recommendations section
                _RecommendSection(
                  novelId: widget.novelId,
                  novel: novel,
                  bookmark: bookmark,
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(errorMessage(error))),
      ),
    );
  }

  String _buildReadUrl(Novel novel, Bookmark? bookmark) {
    if (bookmark != null && bookmark.lastReadEpisode > 0) {
      return novel.episodeUrl(bookmark.lastReadEpisode);
    }
    // For Arcadia, strip act=dump from legacy DB URLs
    if (novel.site == NovelSite.arcadia) {
      return novel.url.replaceFirst('act=dump&', '');
    }
    return novel.url;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  Future<void> _openUrl(String url) async {
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

  void _showEpisodeDialog(int bookmarkId, int current, int total) {
    final controller = TextEditingController(text: current.toString());

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('既読話数を更新'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '既読話数',
            hintText: '0〜$total',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0 &&
                  (total == 0 || value <= total)) {
                ref
                    .read(bookmarkListProvider.notifier)
                    .updateLastReadEpisode(bookmarkId, value);
                Navigator.pop(context);
              }
            },
            child: const Text('更新'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showCommentDialog(String? currentComment) {
    final controller = TextEditingController(text: currentComment);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TextEditSheet(
        title: '感想を編集',
        controller: controller,
        hintText: '感想を入力...',
        onSave: () {
          final reviewAsync = ref.read(novelReviewProvider(widget.novelId));
          ref.read(registerNovelProvider).upsertReview(
                novelId: widget.novelId,
                rating: reviewAsync.valueOrNull?.rating,
                comment: controller.text,
              );
          ref.invalidate(novelReviewProvider(widget.novelId));
          Navigator.pop(ctx);
        },
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _showCategorySheet(Bookmark bookmark) async {
    final oldIds = bookmark.categories.map((c) => c.id).toSet();
    final newIds = await CategoryPickSheet.show(
      context,
      initialSelectedIds: oldIds,
      mode: CategoryPickMode.assign,
    );

    if (newIds == null) return;

    await ref
        .read(bookmarkListProvider.notifier)
        .syncCategories(bookmark.id, oldIds, newIds);
  }

  void _showMemoDialog(int bookmarkId, String? currentMemo) {
    final controller = TextEditingController(text: currentMemo);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TextEditSheet(
        title: 'メモを編集',
        controller: controller,
        hintText: 'キャラ名、伏線の記録など...',
        onSave: () {
          ref
              .read(bookmarkListProvider.notifier)
              .updateMemo(bookmarkId, controller.text);
          Navigator.pop(ctx);
        },
      ),
    ).then((_) => controller.dispose());
  }

}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _TextEditSheet extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSave;

  const _TextEditSheet({
    required this.title,
    required this.controller,
    required this.hintText,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onSave,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 8,
              minLines: 4,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// おすすめセクション（小説詳細画面用）
// ============================================================

class _RecommendSection extends ConsumerWidget {
  final int novelId;
  final Novel novel;
  final Bookmark? bookmark;

  const _RecommendSection({
    required this.novelId,
    required this.novel,
    required this.bookmark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(recommendSettingsProvider).valueOrNull;
    final myRec = ref.watch(myNovelRecommendationProvider(novelId)).valueOrNull;
    final publicRecs =
        ref.watch(novelRecommendationsProvider(novelId)).valueOrNull ?? [];

    final canCreate = (settings?.createEnabled ?? false) &&
        bookmark != null &&
        (bookmark!.tier == 2 || bookmark!.tier == 3);

    final showCreate = settings?.createEnabled ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'おすすめ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        if (showCreate)
          if (canCreate)
            _RecommendForm(novelId: novelId, existing: myRec)
          else if (bookmark != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '殿堂入り・良作に分類するとおすすめを書けます',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),

        if (publicRecs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('まだおすすめがありません',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          )
        else
          ...publicRecs.map(
            (rec) => RecommendationCard(
              rec: rec,
              onTap: null,
              onLike: () async {
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) return;
                final liked = rec.isLikedByMe ?? false;
                if (liked) {
                  await supabase
                      .from('recommendation_likes')
                      .delete()
                      .eq('recommendation_id', rec.id)
                      .eq('user_id', userId);
                } else {
                  await supabase.from('recommendation_likes').insert({
                    'recommendation_id': rec.id,
                    'user_id': userId,
                  });
                }
                ref.invalidate(novelRecommendationsProvider(novelId));
              },
              onReport: () => _showReportSheet(context, rec),
            ),
          ),
      ],
    );
  }

  void _showReportSheet(BuildContext context, Recommendation rec) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _SimpleReportSheet(rec: rec),
    );
  }
}

class _SimpleReportSheet extends StatefulWidget {
  final Recommendation rec;

  const _SimpleReportSheet({required this.rec});

  @override
  State<_SimpleReportSheet> createState() => _SimpleReportSheetState();
}

class _SimpleReportSheetState extends State<_SimpleReportSheet> {
  String? _reason;
  bool _submitting = false;

  static const _reasons = [
    ('r18',        'R18・性的表現'),
    ('ad',         '広告・スパム'),
    ('harassment', '誹謗中傷・アンチ'),
    ('off_topic',  '感想と無関係'),
    ('other',      'その他'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('通報', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: _reasons.map(
                (r) => RadioListTile<String>(
                  value: r.$1,
                  title: Text(r.$2),
                  dense: true,
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _reason == null || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('通報する'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() => _submitting = true);
    try {
      await supabase.from('recommendation_reports').insert({
        'recommendation_id': widget.rec.id,
        'reason': _reason,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通報を受け付けました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通報に失敗しました: ${errorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _RecommendForm extends ConsumerStatefulWidget {
  final int novelId;
  final Recommendation? existing;

  const _RecommendForm({required this.novelId, this.existing});

  @override
  ConsumerState<_RecommendForm> createState() => _RecommendFormState();
}

class _RecommendFormState extends ConsumerState<_RecommendForm> {
  late final TextEditingController _headingCtrl;
  late final TextEditingController _bodyCtrl;
  bool _isPublic = true;
  bool _submitting = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _headingCtrl = TextEditingController(text: widget.existing?.heading ?? '');
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _isPublic = widget.existing?.isPublic ?? true;
    _expanded = widget.existing != null;
  }

  @override
  void dispose() {
    _headingCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  bool get _hasExisting => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    if (!_expanded && !_hasExisting) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.recommend_outlined),
          label: const Text('この作品をおすすめする'),
          onPressed: () => setState(() => _expanded = true),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _hasExisting ? '自分のおすすめ' : 'おすすめを投稿',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _headingCtrl,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '見出し（60文字以内）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: 'おすすめコメント',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                Text(_isPublic ? '公開' : '非公開'),
                const Spacer(),
                if (_hasExisting)
                  TextButton(
                    onPressed: _submitting ? null : _delete,
                    child: Text('削除',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_hasExisting ? '更新' : '投稿'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '投稿後は審査中になります。承認後に公開されます。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final heading = _headingCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (heading.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('見出しとコメントを入力してください')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_hasExisting) {
        await supabase.from('recommendations').update({
          'heading': heading,
          'body': body,
          'is_public': _isPublic,
        }).eq('id', widget.existing!.id);
      } else {
        await supabase.from('recommendations').insert({
          'user_id': supabase.auth.currentUser!.id,
          'novel_id': widget.novelId,
          'heading': heading,
          'body': body,
          'is_public': _isPublic,
        });
      }
      ref.invalidate(myNovelRecommendationProvider(widget.novelId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_hasExisting
                  ? 'おすすめを更新しました（再審査中）'
                  : 'おすすめを投稿しました（審査中）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${errorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _submitting = true);
    try {
      await supabase
          .from('recommendations')
          .delete()
          .eq('id', widget.existing!.id);
      ref.invalidate(myNovelRecommendationProvider(widget.novelId));
      ref.invalidate(novelRecommendationsProvider(widget.novelId));
      if (mounted) setState(() => _expanded = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: ${errorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
