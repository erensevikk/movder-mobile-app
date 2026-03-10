class ImportResultModel {
  const ImportResultModel({
    required this.importedListCount,
    required this.importedItemCount,
    required this.unresolvedCount,
  });

  factory ImportResultModel.fromMap(Map<String, dynamic> map) {
    return ImportResultModel(
      importedListCount:
          int.tryParse((map['importedListCount'] ?? '0').toString()) ?? 0,
      importedItemCount:
          int.tryParse((map['importedItemCount'] ?? '0').toString()) ?? 0,
      unresolvedCount:
          int.tryParse((map['unresolvedCount'] ?? '0').toString()) ?? 0,
    );
  }

  final int importedListCount;
  final int importedItemCount;
  final int unresolvedCount;
}
