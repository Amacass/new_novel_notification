import 'novel.dart';

enum ModerationStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case ModerationStatus.pending:   return '審査中';
      case ModerationStatus.approved:  return '公開中';
      case ModerationStatus.rejected:  return '却下';
    }
  }
}

enum ModerationReason {
  r18,
  ad,
  harassment,
  offTopic,
  other;

  String get label {
    switch (this) {
      case ModerationReason.r18:        return 'R18・性的表現';
      case ModerationReason.ad:         return '広告・スパム';
      case ModerationReason.harassment: return '誹謗中傷・アンチ';
      case ModerationReason.offTopic:   return '感想と無関係な内容';
      case ModerationReason.other:      return '規約違反';
    }
  }

  static ModerationReason? fromString(String? s) {
    switch (s) {
      case 'r18':        return ModerationReason.r18;
      case 'ad':         return ModerationReason.ad;
      case 'harassment': return ModerationReason.harassment;
      case 'off_topic':  return ModerationReason.offTopic;
      case 'other':      return ModerationReason.other;
      default:           return null;
    }
  }
}

class RecommendationAuthor {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final int totalRecommendLikes;

  const RecommendationAuthor({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.totalRecommendLikes = 0,
  });

  factory RecommendationAuthor.fromJson(Map<String, dynamic> json) {
    return RecommendationAuthor(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      totalRecommendLikes: json['total_recommend_likes'] as int? ?? 0,
    );
  }
}

class Recommendation {
  final int id;
  final String userId;
  final int novelId;
  final String heading;
  final String body;
  final bool isPublic;
  final ModerationStatus moderationStatus;
  final ModerationReason? moderationReason;
  final int likeCount;
  final int sourceTier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Novel? novel;
  final RecommendationAuthor? author;
  final bool? isLikedByMe;

  const Recommendation({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.heading,
    required this.body,
    required this.isPublic,
    required this.moderationStatus,
    this.moderationReason,
    required this.likeCount,
    required this.sourceTier,
    required this.createdAt,
    required this.updatedAt,
    this.novel,
    this.author,
    this.isLikedByMe,
  });

  Recommendation copyWith({
    bool? isPublic,
    ModerationStatus? moderationStatus,
    int? likeCount,
    bool? isLikedByMe,
  }) {
    return Recommendation(
      id: id,
      userId: userId,
      novelId: novelId,
      heading: heading,
      body: body,
      isPublic: isPublic ?? this.isPublic,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      moderationReason: moderationReason,
      likeCount: likeCount ?? this.likeCount,
      sourceTier: sourceTier,
      createdAt: createdAt,
      updatedAt: updatedAt,
      novel: novel,
      author: author,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    final novelJson = json['novels'];
    final authorJson = json['author'];

    return Recommendation(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as int,
      heading: json['heading'] as String,
      body: json['body'] as String,
      isPublic: json['is_public'] as bool? ?? true,
      moderationStatus: ModerationStatus.values.firstWhere(
        (e) => e.name == json['moderation_status'],
        orElse: () => ModerationStatus.pending,
      ),
      moderationReason: ModerationReason.fromString(
        json['moderation_reason'] as String?,
      ),
      likeCount: json['like_count'] as int? ?? 0,
      sourceTier: json['source_tier'] as int? ?? 2,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      novel: novelJson != null
          ? Novel.fromJson(novelJson as Map<String, dynamic>)
          : null,
      author: authorJson != null
          ? RecommendationAuthor.fromJson(authorJson as Map<String, dynamic>)
          : null,
    );
  }
}
