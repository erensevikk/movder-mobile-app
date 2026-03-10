import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../features/profile/data/models/import_result_model.dart';
import '../../../../features/profile/data/models/letterboxd_preview_model.dart';
import '../../../../features/profile/data/models/movie_list_model.dart';
import '../../../../features/profile/data/models/user_profile_model.dart';
import '../../data/repositories/profile_repository.dart';

class UserDetailViewModel extends BaseViewModel {
  UserDetailViewModel({
    required this.userId,
    required this.isMe,
    required this.openImportOnStart,
  });

  final String userId;
  final bool isMe;
  final bool openImportOnStart;

  ViewStatus status = ViewStatus.initial;
  UserProfileModel? profile;
  List<MovieListModel> lists = <MovieListModel>[];
  bool isEditMode = false;
  bool isImporting = false;
  String descriptionDraft = '';
  String descriptionSnapshot = '';
  List<int>? draftCoverBytes;
  String? draftCoverFileName;
  bool draftDeleteCover = false;

  ProfileRepository get _profileRepository =>
      AppScope.instance.profileRepository;

  bool get canSeeProfileDetails =>
      isMe || profile?.canSeeProfileDetails == true;

  MovieListModel? get favoriteList {
    for (final list in lists) {
      if (list.name.toLowerCase().contains('favori')) {
        return list;
      }
    }
    return null;
  }

  Future<void> pickAvatarImage() async {
    final file = await AppScope.instance.mediaPickerService.pickImage();
    if (file == null) return;

    status = ViewStatus.loading;
    notifyListeners();

    final updated = await _profileRepository.updateMyProfile(
      imageBytes: file.bytes.toList(),
      imageFileName: file.fileName,
    );

    if (updated == null) {
      status = ViewStatus.content;
      notifyListeners();
      emitEffect(const ShowSnackbarEffect(
          message: 'Profil fotoğrafı güncellenemedi.'));
      return;
    }

    profile = updated;
    status = ViewStatus.content;
    notifyListeners();
    emitEffect(
        const ShowSnackbarEffect(message: 'Profil fotoğrafı güncellendi.'));
  }

  @override
  Future<void> initialize() async {
    await load();
    if (openImportOnStart) {
      await startLetterboxdImport();
    }
  }

  Future<void> load() async {
    status = ViewStatus.loading;
    notifyListeners();

    profile = isMe
        ? await _profileRepository.getMyDetailProfile()
        : await _profileRepository.getUserDetailProfile(userId);

    if (profile == null) {
      status = ViewStatus.error;
      setError('Profil bulunamadi.');
      return;
    }

    if (isMe) {
      lists = await AppScope.instance.listsRepository.getMyLists();
    } else if (profile!.canSeeProfileDetails) {
      lists = await AppScope.instance.listsRepository.getUserLists(userId);
    } else {
      lists = <MovieListModel>[];
    }

    descriptionDraft = profile!.description;
    descriptionSnapshot = profile!.description;
    status = ViewStatus.content;
    notifyListeners();
  }

  void enterEditMode() {
    isEditMode = true;
    descriptionSnapshot = descriptionDraft;
    draftCoverBytes = null;
    draftCoverFileName = null;
    draftDeleteCover = false;
    notifyListeners();
  }

  void cancelEditMode() {
    isEditMode = false;
    descriptionDraft = descriptionSnapshot;
    draftCoverBytes = null;
    draftCoverFileName = null;
    draftDeleteCover = false;
    notifyListeners();
  }

  void updateDescription(String value) {
    descriptionDraft = value;
  }

  Future<void> pickCoverImage() async {
    final file = await AppScope.instance.mediaPickerService.pickImage();
    if (file == null) return;
    draftCoverBytes = file.bytes.toList();
    draftCoverFileName = file.fileName;
    draftDeleteCover = false;
    notifyListeners();
  }

  void deleteCoverPreview() {
    draftCoverBytes = null;
    draftCoverFileName = null;
    draftDeleteCover = true;
    notifyListeners();
  }

  Future<void> saveEditMode() async {
    final updated = await _profileRepository.updateMyProfile(
      description: descriptionDraft.trim(),
      coverImageBytes: draftCoverBytes,
      coverImageFileName: draftCoverFileName,
      deleteCover: draftDeleteCover,
    );
    if (updated == null) {
      emitEffect(const ShowSnackbarEffect(message: 'Profil guncellenemedi.'));
      return;
    }

    profile = updated;
    descriptionSnapshot = updated.description;
    isEditMode = false;
    draftCoverBytes = null;
    draftCoverFileName = null;
    draftDeleteCover = false;
    notifyListeners();
    emitEffect(const ShowSnackbarEffect(message: 'Profil guncellendi.'));
  }

  Future<void> startLetterboxdImport() async {
    final file = await AppScope.instance.mediaPickerService.pickImportFile();
    if (file == null) return;

    isImporting = true;
    notifyListeners();

    final preview = await AppScope.instance.importRepository.preview(
      fileName: file.fileName,
      bytes: file.bytes,
    );

    if (preview == null) {
      isImporting = false;
      notifyListeners();
      emitEffect(const ShowSnackbarEffect(message: 'Onizleme alinamadi.'));
      return;
    }

    emitEffect(
      ShowDialogEffect(
        barrierDismissible: true,
        builder: (context) => _ImportPreviewDialog(preview: preview, vm: this),
      ),
    );
  }

  Future<void> commitImport(
    LetterboxdPreviewModel preview,
    String strategy,
  ) async {
    final result = await AppScope.instance.importRepository.commit(
      previewToken: preview.previewToken,
      strategy: strategy,
    );

    isImporting = false;
    notifyListeners();

    if (result == null) {
      emitEffect(const ShowSnackbarEffect(message: 'Ice aktarma basarisiz.'));
      return;
    }

    emitEffect(
      ShowDialogEffect(
        builder: (context) => _ImportResultDialog(result: result),
      ),
    );
    await load();
  }
}

class _ImportPreviewDialog extends StatelessWidget {
  const _ImportPreviewDialog({
    required this.preview,
    required this.vm,
  });

  final LetterboxdPreviewModel preview;
  final UserDetailViewModel vm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Letterboxd Onizleme',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Liste: ${preview.totals.listCount} • Film: ${preview.totals.itemCount}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ...preview.lists.take(5).map(
                  (item) => Text(
                    '• ${item.name} (${item.itemCount})',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Iptal'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await vm.commitImport(preview, 'overwrite');
          },
          child: const Text('Uzerine Yaz'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await vm.commitImport(preview, 'merge');
          },
          child: const Text('Birlestir'),
        ),
      ],
    );
  }
}

class _ImportResultDialog extends StatelessWidget {
  const _ImportResultDialog({required this.result});

  final ImportResultModel result;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text(
        'Import Tamamlandi',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'Liste: ${result.importedListCount}\nFilm: ${result.importedItemCount}\nEslesmeyen: ${result.unresolvedCount}',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}
