class MatchHistoryResponse {
  final int page;
  final int limit;
  final List<MatchHistoryItemModel> items;

  MatchHistoryResponse({
    required this.page,
    required this.limit,
    required this.items,
  });

  factory MatchHistoryResponse.fromJson(Map<String, dynamic> json) {
    return MatchHistoryResponse(
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 20,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => MatchHistoryItemModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MatchHistoryItemModel {
  final String matchedUserId;
  final int tmdbId;
  final String movieName;
  final String? username;
  final String? avatarUrl;
  final DateTime? matchedAt;

  MatchHistoryItemModel({
    required this.matchedUserId,
    required this.tmdbId,
    required this.movieName,
    this.username,
    this.avatarUrl,
    this.matchedAt,
  });

  factory MatchHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItemModel(
      matchedUserId: json['matchedUserId'] ?? '',
      tmdbId: json['tmdbId'] ?? 0,
      movieName: json['movieName'] ?? '',
      username: json['username'],
      avatarUrl: json['avatarUrl'],
      matchedAt: json['matchedAt'] != null ? DateTime.tryParse(json['matchedAt']) : null,
    );
  }
}
