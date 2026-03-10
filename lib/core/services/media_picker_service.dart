import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class PickedMediaFile {
  const PickedMediaFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

class MediaPickerService {
  MediaPickerService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<PickedMediaFile?> pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    return PickedMediaFile(
      fileName: file.name,
      bytes: bytes,
    );
  }

  Future<PickedMediaFile?> pickImportFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['zip', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    return PickedMediaFile(
      fileName: file.name,
      bytes: bytes,
    );
  }
}
