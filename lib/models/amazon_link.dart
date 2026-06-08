class AmazonLink {
  final int id;
  final int novelId;
  final String label;
  final String url;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  const AmazonLink({
    required this.id,
    required this.novelId,
    required this.label,
    required this.url,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  factory AmazonLink.fromJson(Map<String, dynamic> json) {
    return AmazonLink(
      id: json['id'] as int,
      novelId: json['novel_id'] as int,
      label: json['label'] as String,
      url: json['url'] as String,
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
