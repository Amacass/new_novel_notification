enum NovelSite {
  narou,
  hameln,
  arcadia;

  String get displayName {
    switch (this) {
      case NovelSite.narou:
        return '小説家になろう';
      case NovelSite.hameln:
        return 'ハーメルン';
      case NovelSite.arcadia:
        return 'Arcadia';
    }
  }

  String get shortLabel {
    switch (this) {
      case NovelSite.narou:
        return 'N';
      case NovelSite.hameln:
        return 'H';
      case NovelSite.arcadia:
        return 'A';
    }
  }
}

enum SerialStatus {
  ongoing,
  completed,
  hiatus;

  String get displayName {
    switch (this) {
      case SerialStatus.ongoing:
        return '連載中';
      case SerialStatus.completed:
        return '完結';
      case SerialStatus.hiatus:
        return '長期未更新';
    }
  }
}

class Novel {
  final int id;
  final NovelSite site;
  final String siteNovelId;
  final String url;
  final String? title;
  final String? authorName;
  final int? authorId;
  final String? synopsis;
  final int totalEpisodes;
  final String? latestEpisodeId;
  final String? latestEpisodeTitle;
  final SerialStatus serialStatus;
  final DateTime? siteUpdatedAt;
  final DateTime? lastCrawledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Novel({
    required this.id,
    required this.site,
    required this.siteNovelId,
    required this.url,
    this.title,
    this.authorName,
    this.authorId,
    this.synopsis,
    this.totalEpisodes = 0,
    this.latestEpisodeId,
    this.latestEpisodeTitle,
    this.serialStatus = SerialStatus.ongoing,
    this.siteUpdatedAt,
    this.lastCrawledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as int,
      site: NovelSite.values.firstWhere((e) => e.name == json['site']),
      siteNovelId: json['site_novel_id'] as String,
      url: json['url'] as String,
      title: json['title'] as String?,
      authorName: json['author_name'] as String?,
      authorId: json['author_id'] as int?,
      synopsis: json['synopsis'] as String?,
      totalEpisodes: json['total_episodes'] as int? ?? 0,
      latestEpisodeId: json['latest_episode_id'] as String?,
      latestEpisodeTitle: json['latest_episode_title'] as String?,
      serialStatus: SerialStatus.values.firstWhere(
        (e) => e.name == json['serial_status'],
        orElse: () => SerialStatus.ongoing,
      ),
      siteUpdatedAt: json['site_updated_at'] != null
          ? DateTime.parse(json['site_updated_at'] as String)
          : null,
      lastCrawledAt: json['last_crawled_at'] != null
          ? DateTime.parse(json['last_crawled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
