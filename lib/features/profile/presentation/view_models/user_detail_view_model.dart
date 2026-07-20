import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_effect.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/profile/data/models/import_preview_result_model.dart';
import '../../../../features/profile/data/models/import_status_model.dart';
import '../../../../features/profile/data/models/movie_list_model.dart';
import '../../../../features/profile/data/models/user_profile_model.dart';
import '../../../../features/profile/data/models/match_history_model.dart';
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
  List<MatchHistoryItemModel> matchHistoryItems = <MatchHistoryItemModel>[];
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
      final matchHistResp =
          await _profileRepository.getMatchHistory(page: 1, limit: 15);
      matchHistoryItems = matchHistResp?.items ?? <MatchHistoryItemModel>[];
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
    emitEffect(const ShowSnackbarEffect(message: 'Profil güncellendi.'));
  }

  Future<void> startLetterboxdImport() async {
    final file = await AppScope.instance.mediaPickerService.pickImportFile();
    if (file == null) return;

    isImporting = true;
    notifyListeners();

    final preview = await AppScope.instance.importRepository.getPreview(
      fileName: file.fileName,
      bytes: file.bytes,
    );

    isImporting = false;
    notifyListeners();

    if (preview == null) {
      emitEffect(const ShowSnackbarEffect(
          message: 'Önizleme alınamadı. İşlem durduruldu.'));
      return;
    }

    emitEffect(
      ShowDialogEffect(
        barrierDismissible: false,
        builder: (context) => _ImportPreviewDialog(
          vm: this,
          preview: preview,
          fileName: file.fileName,
          bytes: file.bytes,
        ),
      ),
    );
  }
}

class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({
    required this.vm,
    required this.preview,
    required this.fileName,
    required this.bytes,
  });

  final UserDetailViewModel vm;
  final ImportPreviewResultModel preview;
  final String fileName;
  final Uint8List bytes;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  final PageController _pageController = PageController(viewportFraction: 0.84);
  final Set<int> _selectedIndexes = <int>{};
  bool _isStarting = false;

  bool get _hasLists => widget.preview.lists.isNotEmpty;

  bool get _allSelected =>
      _hasLists && _selectedIndexes.length == widget.preview.lists.length;

  String get _ctaLabel => _allSelected ? 'Hepsini Aktar' : 'Seçilenleri Aktar';

  @override
  void initState() {
    super.initState();
    _selectedIndexes.addAll(
      List<int>.generate(widget.preview.lists.length, (index) => index),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleSelection(int index) {
    if (_isStarting) return;
    final isSelected = _selectedIndexes.contains(index);

    if (isSelected && _selectedIndexes.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az 1 liste seçili olmalı.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (isSelected) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  Future<void> _startImport() async {
    if (_selectedIndexes.isEmpty) return;

    setState(() => _isStarting = true);

    final selectedNames = _selectedIndexes
        .map((index) => widget.preview.lists[index].name)
        .toList(growable: false);

    final result = await AppScope.instance.importRepository.start(
      fileName: widget.fileName,
      bytes: widget.bytes,
      strategy: 'merge',
      selectedListNames: selectedNames,
    );

    if (!mounted) return;

    Navigator.of(context).pop();

    if (result == null) {
      widget.vm.emitEffect(
          const ShowSnackbarEffect(message: 'İçe aktarma başlatılamadı.'));
      return;
    }

    widget.vm.emitEffect(
      ShowDialogEffect(
        barrierDismissible: false,
        builder: (context) =>
            _ImportStatusDialog(jobId: result.jobId, vm: widget.vm),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = math.min(420.0, viewport.width - 28);
    final dialogHeight = math.min(560.0, viewport.height * 0.8);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                'Liste Önizlemesi',
                style: TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.preview.warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget.preview.warnings.first,
                  style:
                      const TextStyle(color: AppColors.warning, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: !_hasLists
                    ? const Center(
                        child: Text('Bulunan liste yok.',
                            style: TextStyle(color: AppColors.textMedium)),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: widget.preview.lists.length,
                        itemBuilder: (context, index) {
                          final list = widget.preview.lists[index];
                          final posterUrl = list.firstPosterUrl;
                          final isSelected = _selectedIndexes.contains(index);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 12),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.success
                                          : AppColors.divider,
                                      width: isSelected ? 1.4 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: AppColors.surface,
                                                image: posterUrl.isNotEmpty
                                                    ? DecorationImage(
                                                        image: NetworkImage(
                                                            posterUrl),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: posterUrl.isEmpty
                                                  ? const Center(
                                                      child: Icon(
                                                        Icons
                                                            .movie_filter_outlined,
                                                        color: AppColors
                                                            .textMedium,
                                                        size: 44,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          list.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textHigh,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Oluşturan: ${widget.preview.creator.isNotEmpty ? widget.preview.creator : "Bilinmeyen"}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textMedium,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Toplam ${list.totalItems} film',
                                          style: const TextStyle(
                                            color: AppColors.textMedium,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => _toggleSelection(index),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? AppColors.success
                                            : AppColors.surface,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.success
                                              : AppColors.divider,
                                        ),
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check : Icons.close,
                                        size: 16,
                                        color: AppColors.textHigh,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Row(
                children: [
                  Text(
                    '${_selectedIndexes.length}/${widget.preview.lists.length} seçili',
                    style: const TextStyle(
                        color: AppColors.textMedium, fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isStarting ? null : () => Navigator.of(context).pop(),
                    child: const Text('İptal',
                        style: TextStyle(color: AppColors.textMedium)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        _isStarting || !_hasLists || _selectedIndexes.isEmpty
                            ? null
                            : _startImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textHigh,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isStarting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.textHigh,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_ctaLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportStatusDialog extends StatefulWidget {
  const _ImportStatusDialog({
    required this.jobId,
    required this.vm,
  });

  final String jobId;
  final UserDetailViewModel vm;

  @override
  State<_ImportStatusDialog> createState() => _ImportStatusDialogState();
}

class _ImportStatusDialogState extends State<_ImportStatusDialog> {
  ImportStatusModel? _status;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _pollStatus();
  }

  Future<void> _pollStatus() async {
    while (mounted) {
      final status = await AppScope.instance.importRepository
          .getStatus(jobId: widget.jobId);

      if (!mounted) break;

      if (status == null) {
        setState(() {
          _error = 'Durum sorgulanamadı.';
          _isLoading = false;
        });
        break;
      }

      setState(() {
        _status = status;
        _isLoading = false;
      });

      if (status.status == 'completed' || status.status == 'failed') {
        if (status.status == 'completed') {
          widget.vm.load(); // Refresh lists after completion
        }
        break; // Stop polling
      }

      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Listeler İçe Aktarılıyor',
        style: TextStyle(color: AppColors.textHigh),
      ),
      content: SizedBox(
        width: 320,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error.isNotEmpty
                ? Text(_error, style: const TextStyle(color: AppColors.error))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_status!.status == 'processing' ||
                          _status!.status == 'pending') ...[
                        const Text('İşlem arka planda devam ediyor...',
                            style: TextStyle(color: AppColors.textMedium)),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _status!.totalItems > 0
                              ? (_status!.processedItems +
                                      _status!.failedItems) /
                                  _status!.totalItems
                              : null,
                          backgroundColor: AppColors.divider,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                            '%${_status!.progress} Tamamlandı (${_status!.processedItems + _status!.failedItems}/${_status!.totalItems})',
                            style: const TextStyle(color: AppColors.textHigh)),
                      ] else if (_status!.status == 'completed') ...[
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 48),
                        const SizedBox(height: 16),
                        Text(
                            '${_status!.processedItems} film başarıyla eklendi.',
                            style: const TextStyle(color: AppColors.textHigh)),
                        if (_status!.failedItems > 0)
                          Text('${_status!.failedItems} film eşleştirilemedi.',
                              style: const TextStyle(
                                  color: AppColors.textMedium, fontSize: 12)),
                      ] else if (_status!.status == 'failed') ...[
                        const Icon(Icons.error,
                            color: AppColors.error, size: 48),
                        const SizedBox(height: 16),
                        const Text('İçe aktarma sırasında bir hata oluştu.',
                            style: TextStyle(color: AppColors.textHigh)),
                      ]
                    ],
                  ),
      ),
      actions: <Widget>[
        if (_status?.status == 'completed' ||
            _status?.status == 'failed' ||
            _error.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                const Text('Kapat', style: TextStyle(color: AppColors.primary)),
          )
        else
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.vm.emitEffect(const ShowSnackbarEffect(
                  message: 'İşlem arka planda devam edecek.'));
            },
            child: const Text('Arka Plana Al',
                style: TextStyle(color: AppColors.textMedium)),
          ),
      ],
    );
  }
}
