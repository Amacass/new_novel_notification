class CharmTag {
  final int id;
  final String name;
  final bool isSystem;
  final String? userId;
  final DateTime createdAt;

  const CharmTag({
    required this.id,
    required this.name,
    required this.isSystem,
    this.userId,
    required this.createdAt,
  });

  factory CharmTag.fromJson(Map<String, dynamic> json) {
    return CharmTag(
      id: json['id'] as int,
      name: json['name'] as String,
      isSystem: json['is_system'] as bool,
      userId: json['user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
