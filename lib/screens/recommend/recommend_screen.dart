import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/supabase.dart';
import '../../models/recommendation.dart';
import '../../providers/recommendation_provider.dart';
import '../../utils/error_message.dart';
import 'widgets/recommendation_card.dart';

class RecommendScreen extends ConsumerStatefulWidget {
  const RecommendScreen({super.key});

  @override
  ConsumerState<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends ConsumerState<RecommendScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    (tab: RecommendTab.omakase,  label: 'おまかせ'),
    (tab: RecommendTab.daily,    label: 'デイリー'),
    (tab: RecommendTab.weekly,   label: '週間'),
    (tab: RecommendTab.monthly,  label: '月間'),
    (tab: RecommendTab.total,    label: '総合'),
    (tab: RecommendTab.mine,     label: '自分'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('おすすめ'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _FeedView(tab: t.tab)).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------

class _FeedView extends ConsumerWidget {
  final RecommendTab tab;

  const _FeedView({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(recommendFeedProvider(tab));

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('読み込みエラー: ${errorMessage(e)}'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => ref.invalidate(recommendFeedProvider(tab)),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
      data: (recs) => recs.isEmpty
          ? const _EmptyView()
          : _RecList(recs: recs, tab: tab),
    );
  }
}

class _RecList extends ConsumerWidget {
  final List<Recommendation> recs;
  final RecommendTab tab;

  const _RecList({required this.recs, required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(recommendFeedProvider(tab).notifier).refresh(),
      child: ListView.builder(
        itemCount: recs.length + 1,
        itemBuilder: (context, index) {
          if (index == recs.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(recommendFeedProvider(tab).notifier).loadMore(),
                  child: const Text('さらに読み込む'),
                ),
              ),
            );
          }
          final rec = recs[index];
          return RecommendationCard(
            rec: rec,
            showMine: tab == RecommendTab.mine,
            onTap: () => context.push('/novel/${rec.novelId}'),
            onLike: tab != RecommendTab.mine
                ? () =>
                    ref.read(recommendFeedProvider(tab).notifier).toggleLike(rec)
                : null,
            onTogglePublic: tab == RecommendTab.mine
                ? () => ref
                    .read(recommendFeedProvider(tab).notifier)
                    .togglePublic(rec)
                : null,
            onDelete: tab == RecommendTab.mine
                ? () => _confirmDelete(context, ref, rec)
                : null,
            onReport: tab != RecommendTab.mine
                ? () => _showReportSheet(context, rec)
                : null,
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Recommendation rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('おすすめを削除'),
        content: const Text('このおすすめを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(recommendFeedProvider(tab).notifier).delete(rec.id);
    }
  }

  void _showReportSheet(BuildContext context, Recommendation rec) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ReportSheet(rec: rec),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.recommend_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('おすすめがまだありません', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 通報シート
// ---------------------------------------------------------------
class _ReportSheet extends StatefulWidget {
  final Recommendation rec;

  const _ReportSheet({required this.rec});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
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
