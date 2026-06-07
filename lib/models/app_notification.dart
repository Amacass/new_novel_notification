enum NotificationType {
  newEpisode,
  newNovelByAuthor,
  novelCompleted,
  crawlBatch; // バッチクロールによる一括更新通知

  String get displayName {
    switch (this) {
      case NotificationType.newEpisode:
        return '新エピソード公開';
      case NotificationType.newNovelByAuthor:
        return 'お気に入り作者の新作';
      case NotificationType.novelCompleted:
        return '小説完結';
      case NotificationType.crawlBatch:
        return '一括更新';
    }
  }
}

/// crawlBatch 通知の各小説エントリ
class BatchItem {
  final int novelId;
  final String title;
  final int newTotal;

  const BatchItem({
    required this.novelId,
    required this.title,
    required this.newTotal,
  });

  factory BatchItem.fromJson(Map<String, dynamic> json) => BatchItem(
        novelId: json['novel_id'] as int,
        title: json['title'] as String,
        newTotal: json['new_total'] as int,
      );
}

class AppNotification {
  final int id;
  final String userId;
  final NotificationType type;
  final int? novelId;
  final int? authorId;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  final List<BatchItem>? batchItems; // crawlBatch のときのみ

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.novelId,
    this.authorId,
    required this.title,
    this.body,
    this.isRead = false,
    required this.createdAt,
    this.batchItems,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final type = _parseType(json['type'] as String);

    List<BatchItem>? batchItems;
    if (type == NotificationType.crawlBatch) {
      final raw = json['metadata'];
      if (raw is List) {
        batchItems = raw
            .map((e) => BatchItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    return AppNotification(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      type: type,
      novelId: json['novel_id'] as int?,
      authorId: json['author_id'] as int?,
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      batchItems: batchItems,
    );
  }

  static NotificationType _parseType(String type) {
    switch (type) {
      case 'new_episode':
        return NotificationType.newEpisode;
      case 'new_novel_by_author':
        return NotificationType.newNovelByAuthor;
      case 'novel_completed':
        return NotificationType.novelCompleted;
      case 'crawl_batch':
        return NotificationType.crawlBatch;
      default:
        return NotificationType.newEpisode;
    }
  }
}
