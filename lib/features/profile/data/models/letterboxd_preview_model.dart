class ImportTotalsModel {
  const ImportTotalsModel({
    required this.listCount,
    required this.itemCount,
    required this.unresolvedCount,
    required this.conflictCount,
  });

  factory ImportTotalsModel.fromMap(Map<String, dynamic>? map) {
    return ImportTotalsModel(
      listCount: int.tryParse((map?['listCount'] ?? '0').toString()) ?? 0,
      itemCount: int.tryParse((map?['itemCount'] ?? '0').toString()) ?? 0,
      unresolvedCount:
          int.tryParse((map?['unresolvedCount'] ?? '0').toString()) ?? 0,
      conflictCount:
          int.tryParse((map?['conflictCount'] ?? '0').toString()) ?? 0,
    );
  }

  final int listCount;
  final int itemCount;
  final int unresolvedCount;
  final int conflictCount;
}

class ImportListPreviewModel {
  const ImportListPreviewModel({
    required this.name,
    required this.itemCount,
    required this.createdAt,
  });

  factory ImportListPreviewModel.fromMap(Map<String, dynamic> map) {
    return ImportListPreviewModel(
      name: (map['name'] ?? '').toString(),
      itemCount: int.tryParse((map['itemCount'] ?? '0').toString()) ?? 0,
      createdAt: (map['createdAt'] ?? '').toString(),
    );
  }

  final String name;
  final int itemCount;
  final String createdAt;
}

class ImportConflictModel {
  const ImportConflictModel({
    required this.listName,
    required this.existingItemCount,
    required this.incomingItemCount,
  });

  factory ImportConflictModel.fromMap(Map<String, dynamic> map) {
    return ImportConflictModel(
      listName: (map['listName'] ?? '').toString(),
      existingItemCount:
          int.tryParse((map['existingItemCount'] ?? '0').toString()) ?? 0,
      incomingItemCount:
          int.tryParse((map['incomingItemCount'] ?? '0').toString()) ?? 0,
    );
  }

  final String listName;
  final int existingItemCount;
  final int incomingItemCount;
}

class LetterboxdPreviewModel {
  const LetterboxdPreviewModel({
    required this.previewToken,
    required this.totals,
    required this.lists,
    required this.conflicts,
    required this.warnings,
  });

  factory LetterboxdPreviewModel.fromMap(Map<String, dynamic> map) {
    return LetterboxdPreviewModel(
      previewToken: (map['previewToken'] ?? '').toString(),
      totals: ImportTotalsModel.fromMap(
        map['totals'] as Map<String, dynamic>?,
      ),
      lists: (map['lists'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map>()
          .map((item) => ImportListPreviewModel.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      conflicts: (map['conflicts'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map>()
          .map((item) => ImportConflictModel.fromMap(
                Map<String, dynamic>.from(item),
              ))
          .toList(),
      warnings: (map['warnings'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }

  final String previewToken;
  final ImportTotalsModel totals;
  final List<ImportListPreviewModel> lists;
  final List<ImportConflictModel> conflicts;
  final List<String> warnings;
}
