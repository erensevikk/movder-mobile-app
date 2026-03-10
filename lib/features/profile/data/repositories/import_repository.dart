import 'dart:typed_data';

import '../models/import_result_model.dart';
import '../models/letterboxd_preview_model.dart';

abstract class ImportRepository {
  Future<LetterboxdPreviewModel?> preview({
    required String fileName,
    required Uint8List bytes,
  });

  Future<ImportResultModel?> commit({
    required String previewToken,
    required String strategy,
  });
}
