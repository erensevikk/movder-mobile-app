import 'dart:typed_data';

import '../models/import_status_model.dart';
import '../models/import_start_result_model.dart';
import '../models/import_preview_result_model.dart';

abstract class ImportRepository {
  Future<ImportPreviewResultModel?> getPreview({
    required String fileName,
    required Uint8List bytes,
  });

  Future<ImportStartResultModel?> start({
    required String fileName,
    required Uint8List bytes,
    String strategy = 'merge',
    List<String>? selectedListNames,
  });

  Future<ImportStatusModel?> getStatus({
    required String jobId,
  });
}
