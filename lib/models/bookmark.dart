import 'novel.dart';

class Bookmark {
  final int id;
  final String userId;
  final int novelId;
  final int lastReadEpisode;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Novel? novel;
  final Review? review;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.novelId,
    this.lastReadEpisode = 0,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
    this.novel,
    this.review,
  });

  int get unreadCount {
    if (novel == null) return 0;
    return novel!.totalEpisodes - lastReadEpisode;
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as int,
      lastReadEpisode: json['last_read_episode'] as int? ?? 0,
      memo: json['memo'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      novel: json['novels'] != null
          ? Novel.fromJson(json['novels'] as Map<String, dynamic>)
          : null,
      review: json['reviews'] != null
          ? Review.fromJson(json['reviews'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Review {
  final int id;
  final String userId;
  final int novelId;
  final int? rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Review({
    required this.id,
    required this.userId,
    required this.novelId,
    this.rating,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as int,
      rating: json['rating'] as int?,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
