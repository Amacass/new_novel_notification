import 'novel.dart';

class Bookmark {
  final int id;
  final String userId;
  final int novelId;
  final int lastReadEpisode;
  final String? memo;
  final int tier; // -1=未仕分け, 0=ゴミ箱, 1=キープ, 2=良作, 3=殿堂入り
  final double heatScore;
  final DateTime? lastStampedAt;
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
    this.tier = -1,
    this.heatScore = 0.0,
    this.lastStampedAt,
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
      tier: json['tier'] as int? ?? -1,
      heatScore: (json['heat_score'] as num?)?.toDouble() ?? 0.0,
      lastStampedAt: json['last_stamped_at'] != null
          ? DateTime.parse(json['last_stamped_at'] as String)
          : null,
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

  Bookmark copyWith({
    int? id,
    String? userId,
    int? novelId,
    int? lastReadEpisode,
    String? memo,
    int? tier,
    double? heatScore,
    DateTime? lastStampedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Novel? novel,
    Review? review,
  }) {
    return Bookmark(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      novelId: novelId ?? this.novelId,
      lastReadEpisode: lastReadEpisode ?? this.lastReadEpisode,
      memo: memo ?? this.memo,
      tier: tier ?? this.tier,
      heatScore: heatScore ?? this.heatScore,
      lastStampedAt: lastStampedAt ?? this.lastStampedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      novel: novel ?? this.novel,
      review: review ?? this.review,
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
