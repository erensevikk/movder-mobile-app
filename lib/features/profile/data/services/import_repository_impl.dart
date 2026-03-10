import 'dart:typed_data';

import '../../../../services/api_service.dart';
import '../models/import_result_model.dart';
import '../models/letterboxd_preview_model.dart';
import '../repositories/import_repository.dart';

class ImportRepositoryImpl implements ImportRepository {
  @override
  Future<ImportResultModel?> commit({
    required String previewToken,
    required String strategy,
  }) async {
    final result = await ApiService.commitLetterboxdImport(
      previewToken: previewToken,
      strategy: strategy,
    );
    if (result == null || result['error'] != null) return null;
    return ImportResultModel.fromMap(result);
  }

  @override
  Future<LetterboxdPreviewModel?> preview({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await ApiService.previewLetterboxdImport(
      fileName: fileName,
      bytes: bytes,
    );
    if (result == null || result['error'] != null) return null;
    return LetterboxdPreviewModel.fromMap(result);
  }
}
