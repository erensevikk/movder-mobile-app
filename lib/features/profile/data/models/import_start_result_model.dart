class ImportStartResultModel {
  final String jobId;
  final String message;

  ImportStartResultModel({
    required this.jobId,
    required this.message,
  });

  factory ImportStartResultModel.fromMap(Map<String, dynamic> map) {
    return ImportStartResultModel(
      jobId: map['jobId'] ?? '',
      message: map['message'] ?? '',
    );
  }
}
