class ImportStatusModel {
  final String jobId;
  final String status;
  final int progress;
  final int totalItems;
  final int processedItems;
  final int failedItems;
  final List<String> logs;

  ImportStatusModel({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.totalItems,
    required this.processedItems,
    required this.failedItems,
    required this.logs,
  });

  factory ImportStatusModel.fromMap(Map<String, dynamic> map) {
    return ImportStatusModel(
      jobId: map['jobId'] ?? '',
      status: map['status'] ?? 'pending',
      progress: map['progress'] ?? 0,
      totalItems: map['totalItems'] ?? 0,
      processedItems: map['processedItems'] ?? 0,
      failedItems: map['failedItems'] ?? 0,
      logs: List<String>.from(map['logs'] ?? []),
    );
  }
}
