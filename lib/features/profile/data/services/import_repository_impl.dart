import 'dart:typed_data';

import '../../../../services/api_service.dart';
import '../models/import_status_model.dart';
import '../models/import_start_result_model.dart';
import '../models/import_preview_result_model.dart';
import '../repositories/import_repository.dart';

class ImportRepositoryImpl implements ImportRepository {
  @override
  Future<ImportPreviewResultModel?> getPreview({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await ApiService.previewLetterboxdImport(
      fileName: fileName,
      bytes: bytes,
    );
    if (result == null || result['error'] != null) return null;
    return ImportPreviewResultModel.fromMap(result);
  }

  @override
  Future<ImportStartResultModel?> start({
    required String fileName,
    required Uint8List bytes,
    String strategy = 'merge',
    List<String>? selectedListNames,
  }) async {
    final result = await ApiService.startLetterboxdImport(
      fileName: fileName,
      bytes: bytes,
      strategy: strategy,
      selectedListNames: selectedListNames,
    );
    if (result == null || result['error'] != null) return null;
    return ImportStartResultModel.fromMap(result);
  }

  @override
  Future<ImportStatusModel?> getStatus({
    required String jobId,
  }) async {
    final result = await ApiService.getImportStatus(jobId);
    if (result == null || result['error'] != null) return null;
    return ImportStatusModel.fromMap(result);
  }
}
