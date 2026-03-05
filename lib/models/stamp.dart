import 'charm_tag.dart';

class EmotionStamp {
  final int id;
  final String userId;
  final int novelId;
  final String emoji;
  final int? episodeNumber;
  final List<CharmTag> charmTags;
  final DateTime createdAt;

  const EmotionStamp({
    required this.id,
    required this.userId,
    required this.novelId,
    required this.emoji,
    this.episodeNumber,
    this.charmTags = const [],
    required this.createdAt,
  });

  factory EmotionStamp.fromJson(Map<String, dynamic> json) {
    final tagsJson = json['stamp_charm_tags'] as List?;
    final tags = tagsJson
            ?.map((e) => CharmTag.fromJson(
                (e as Map<String, dynamic>)['charm_tags'] as Map<String, dynamic>))
            .toList() ??
        [];

    return EmotionStamp(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      novelId: json['novel_id'] as int,
      emoji: json['emoji'] as String,
      episodeNumber: json['episode_number'] as int?,
      charmTags: tags,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'novel_id': novelId,
      'emoji': emoji,
      if (episodeNumber != null) 'episode_number': episodeNumber,
    };
  }
}
