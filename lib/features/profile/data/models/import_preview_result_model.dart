class ImportPreviewModel {
  final String name;
  final int totalItems;
  final String firstPosterUrl;

  ImportPreviewModel({
    required this.name,
    required this.totalItems,
    required this.firstPosterUrl,
  });

  factory ImportPreviewModel.fromMap(Map<String, dynamic> map) {
    return ImportPreviewModel(
      name: map['name'] ?? '',
      totalItems: map['totalItems'] ?? 0,
      firstPosterUrl: map['firstPosterUrl'] ?? '',
    );
  }
}

class ImportPreviewResultModel {
  final String message;
  final List<String> warnings;
  final List<ImportPreviewModel> lists;
  final String creator;

  ImportPreviewResultModel({
    required this.message,
    required this.warnings,
    required this.lists,
    this.creator = '',
  });

  factory ImportPreviewResultModel.fromMap(Map<String, dynamic> map) {
    return ImportPreviewResultModel(
      message: map['message'] ?? '',
      warnings: List<String>.from(map['warnings'] ?? []),
      lists: (map['lists'] as List<dynamic>?)
              ?.map((e) => ImportPreviewModel.fromMap(e))
              .toList() ??
          [],
      creator: map['creator'] ?? '',
    );
  }
}
