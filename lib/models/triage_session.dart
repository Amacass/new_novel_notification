class TriageSession {
  final int id;
  final String userId;
  final int totalCards;
  final int sortedCards;
  final bool isComplete;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TriageSession({
    required this.id,
    required this.userId,
    required this.totalCards,
    this.sortedCards = 0,
    this.isComplete = false,
    required this.createdAt,
    this.completedAt,
  });

  factory TriageSession.fromJson(Map<String, dynamic> json) {
    return TriageSession(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      totalCards: json['total_cards'] as int,
      sortedCards: json['sorted_cards'] as int? ?? 0,
      isComplete: json['is_complete'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

class TriageResult {
  final int id;
  final int sessionId;
  final int bookmarkId;
  final int tier;
  final DateTime sortedAt;

  const TriageResult({
    required this.id,
    required this.sessionId,
    required this.bookmarkId,
    required this.tier,
    required this.sortedAt,
  });

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    return TriageResult(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      bookmarkId: json['bookmark_id'] as int,
      tier: json['tier'] as int,
      sortedAt: DateTime.parse(json['sorted_at'] as String),
    );
  }
}
