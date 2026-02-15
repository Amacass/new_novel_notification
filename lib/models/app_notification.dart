enum NotificationType {
  newEpisode,
  newNovelByAuthor,
  novelCompleted;

  String get displayName {
    switch (this) {
      case NotificationType.newEpisode:
        return '新エピソード公開';
      case NotificationType.newNovelByAuthor:
        return 'お気に入り作者の新作';
      case NotificationType.novelCompleted:
        return '小説完結';
    }
  }
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
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      type: _parseType(json['type'] as String),
      novelId: json['novel_id'] as int?,
      authorId: json['author_id'] as int?,
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
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
      default:
        return NotificationType.newEpisode;
    }
  }
}
