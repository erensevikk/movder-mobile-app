import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../models/movie.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/movie_list_model.dart';
import '../../../lists/presentation/views/create_list_screen.dart';
import '../../../lists/presentation/views/list_detail_screen.dart';
import '../view_models/user_detail_view_model.dart';
import 'match_history_full_list_screen.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({
    super.key,
    required this.userId,
    this.isMe = false,
    this.openImportOnStart = false,
  });

  final String userId;
  final bool isMe;
  final bool openImportOnStart;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with
        ViewModelBindingMixin<UserDetailScreen, UserDetailViewModel>,
        ViewEffectListenerMixin<UserDetailScreen, UserDetailViewModel> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  UserDetailViewModel createViewModel() => UserDetailViewModel(
        userId: widget.userId,
        isMe: widget.isMe,
        openImportOnStart: widget.openImportOnStart,
      );

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget buildWithViewModel(BuildContext context, UserDetailViewModel vm) {
    if (vm.status == ViewStatus.loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingView(),
      );
    }

    if (vm.status == ViewStatus.error || vm.profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: ErrorView(
          message: vm.errorMessage ?? 'Profil bulunamadı.',
          onRetry: vm.load,
        ),
      );
    }

    if (_descriptionController.text != vm.descriptionDraft) {
      _descriptionController.text = vm.descriptionDraft;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textHigh),
        leading: Transform.translate(
          offset: const Offset(0, -10),
          child: const BackButton(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(vm),
            ),
            SliverToBoxAdapter(
              child: _buildFavoriteFilmsOrEmptyState(vm),
            ),
            SliverToBoxAdapter(
              child: _buildUserListsSection(vm),
            ),
            if (widget.isMe)
              SliverToBoxAdapter(
                child: _buildMatchHistory(vm),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserDetailViewModel vm) {
    const double coverHeight = 100.0;
    const double avatarSize = 90.0;
    final topInset = MediaQuery.of(context).padding.top;
    final profile = vm.profile!;

    final avatarUrl = profile.avatarUrl;
    final description = vm.descriptionDraft.isEmpty
        ? (widget.isMe ? 'Seni tanımlayan bir şeyler yaz...' : '')
        : vm.descriptionDraft;

    // Kapak logic
    String effectiveCover = '';
    DecorationImage? coverDecorationImage;

    if (vm.draftCoverBytes != null) {
      coverDecorationImage = DecorationImage(
        image: MemoryImage(Uint8List.fromList(vm.draftCoverBytes!)),
        fit: BoxFit.cover,
      );
    } else if (!vm.draftDeleteCover && profile.coverUrl.isNotEmpty) {
      effectiveCover = profile.coverUrl;
    }

    if (!vm.draftDeleteCover &&
        coverDecorationImage == null &&
        effectiveCover.isEmpty) {
      for (final list in vm.lists) {
        if (list.items.isNotEmpty) {
          final poster = list.items.first.posterUrl;
          if (poster.isNotEmpty) {
            effectiveCover = poster;
            break;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: topInset + coverHeight + (avatarSize / 2),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + coverHeight,
              child: GestureDetector(
                onTap: widget.isMe && vm.isEditMode
                    ? vm.pickCoverImage
                    : (!widget.isMe && profile.coverUrl.isNotEmpty
                        ? () => _showFullScreenImage(profile.coverUrl)
                        : null),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.surface, AppColors.surface],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    image: coverDecorationImage ??
                        (effectiveCover.isNotEmpty
                            ? DecorationImage(
                                image:
                                    CachedNetworkImageProvider(effectiveCover),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  child: widget.isMe && vm.isEditMode
                      ? Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.overlay.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded,
                                    color: AppColors.textMedium, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  profile.coverUrl.isNotEmpty
                                      ? 'Kapağı Değiştir'
                                      : 'Kapak Ekle',
                                  style: const TextStyle(
                                      color: AppColors.textMedium,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (widget.isMe &&
                vm.isEditMode &&
                (profile.coverUrl.isNotEmpty || vm.draftCoverBytes != null) &&
                !vm.draftDeleteCover)
              Positioned(
                top: topInset + 12,
                right: 16,
                child: GestureDetector(
                  onTap: vm.deleteCoverPreview,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.overlay.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 7,
              bottom: 0,
              child: GestureDetector(
                onTap: widget.isMe ? vm.pickAvatarImage : null,
                child: Stack(
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        border:
                            Border.all(color: AppColors.background, width: 4),
                        image: avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.textMedium,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.isMe && vm.isEditMode)
              Positioned(
                left: 69,
                bottom: 5,
                child: GestureDetector(
                  onTap: vm.pickAvatarImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: AppColors.textHigh, size: 18),
                  ),
                ),
              ),
            Positioned(
              left: 118,
              right: 12,
              bottom: 5,
              child: Container(
                height: 74,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHeaderStatItem('0', 'Anlık Eşleşme'),
                    _buildHeaderStatDivider(),
                    _buildHeaderStatItem('0', 'Sohbet'),
                    _buildHeaderStatDivider(),
                    _buildHeaderStatItem('0', 'İzleme'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  profile.username,
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (widget.isMe && vm.isEditMode) ...[
                GestureDetector(
                  onTap: vm.cancelEditMode,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Text(
                      'Vazgeç',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: vm.saveEditMode,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (widget.isMe)
                GestureDetector(
                  onTap: vm.enterEditMode,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Text(
                      'Profili Düzenle',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isMe && vm.isEditMode
              ? TextField(
                  controller: _descriptionController,
                  onChanged: vm.updateDescription,
                  style: const TextStyle(
                    color: AppColors.textMedium,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  maxLength: 150,
                  decoration: InputDecoration(
                    hintText: 'Kendinden bahset...',
                    hintStyle: const TextStyle(color: AppColors.textMedium),
                    counterStyle: const TextStyle(color: AppColors.textMedium),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                )
              : Text(
                  !vm.canSeeProfileDetails
                      ? 'Bu profil detayları yalnızca arkadaşlarına açık.'
                      : description,
                  style: TextStyle(
                    color: !vm.canSeeProfileDetails
                        ? AppColors.textMedium
                        : (description.isNotEmpty
                            ? AppColors.textMedium
                            : AppColors.textMedium),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFavoriteFilmsOrEmptyState(UserDetailViewModel vm) {
    if (!vm.canSeeProfileDetails) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FAVORİ FİLMLER',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildPrivacyInfoCard(
              icon: Icons.lock_outline,
              text:
                  'Bu kullanıcı favori filmlerini sadece arkadaşlarıyla paylaşıyor.',
            ),
          ],
        ),
      );
    }

    final favoriteList = vm.favoriteList;
    final favoriteItems = favoriteList?.items ?? const [];
    final hasContent = favoriteItems.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FAVORİ FİLMLER',
                style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (widget.isMe)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateListScreen()),
                        );
                        if (created == true) {
                          await vm.load();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.textMedium, size: 14),
                      ),
                    ),
                    if (favoriteList != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final changed = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListDetailScreen(
                                list: favoriteList,
                                isMe: widget.isMe,
                              ),
                            ),
                          );
                          if (changed == true) {
                            await vm.load();
                          }
                        },
                        child: const Text(
                          'Listeyi Düzenle',
                          style: TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasContent && widget.isMe && !vm.profile!.letterboxdImported)
            _buildLetterboxdCTA(vm)
          else if (!hasContent && widget.isMe && vm.profile!.letterboxdImported)
            _buildAddFavoritesButton(vm, favoriteList)
          else if (!hasContent && !widget.isMe)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                children: [
                  Icon(Icons.movie_filter_outlined,
                      color: AppColors.textMedium, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Henüz favori filmlerini seçmemiş',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                ],
              ),
            )
          else ...[
            _buildFavoritesGrid(favoriteItems.take(4).toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildLetterboxdCTA(UserDetailViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sync_rounded,
            color: AppColors.secondary,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Profilin Çok Boş Görünüyor!',
            style: TextStyle(
              color: AppColors.textHigh,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Letterboxd hesabını bağlayarak favori filmlerini, son izlediklerini ve incelemelerini Movder profiline taşı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMedium,
              height: 1.5,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: vm.isImporting ? null : vm.startLetterboxdImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                vm.isImporting
                    ? 'İçe Aktarılıyor...'
                    : 'Letterboxd Verilerini İçe Aktar',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFavoritesButton(
      UserDetailViewModel vm, MovieListModel? favoriteList) {
    return GestureDetector(
      onTap: () => _openFavoriteMoviesPicker(vm, favoriteList),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: AppColors.textMedium, size: 40),
            SizedBox(height: 10),
            Text(
              'Favori Film Ekle',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFavoriteMoviesPicker(
    UserDetailViewModel vm,
    MovieListModel? favoriteList,
  ) async {
    final existingIds =
        favoriteList?.items.map((e) => e.tmdbId).toSet() ?? <int>{};

    final selectedMovies =
        await _showFavoriteMoviesModal(existingIds: existingIds);
    if (!mounted || selectedMovies == null || selectedMovies.isEmpty) return;

    MovieListModel? targetList = favoriteList;

    if (targetList == null) {
      final createdResult = await AppScope.instance.listsRepository.createList(
        name: 'Favori Filmler',
        description: 'Profilde öne çıkan favori filmler',
        isPublic: true,
      );

      if (createdResult.isFailure || createdResult.data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favori listesi oluşturulamadı.')),
        );
        return;
      }

      targetList = createdResult.data!;
    }

    final toAdd = selectedMovies
        .where((movie) => !existingIds.contains(movie.id))
        .toList(growable: false);

    if (toAdd.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Seçilen filmler zaten favori listende var.')),
      );
      return;
    }

    var addedCount = 0;
    for (final movie in toAdd) {
      final success = await AppScope.instance.listsRepository.addMovieToList(
        listId: targetList.id,
        movie: movie,
      );
      if (success) addedCount++;
    }

    await vm.load();
    if (!mounted) return;

    final failedCount = toAdd.length - addedCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failedCount == 0
              ? '$addedCount film favori listene eklendi.'
              : '$addedCount film eklendi, $failedCount film eklenemedi.',
        ),
      ),
    );
  }

  Future<List<Movie>?> _showFavoriteMoviesModal({
    required Set<int> existingIds,
  }) async {
    final searchController = TextEditingController();
    final searchResults = <Movie>[];
    final selectedMovies = <int, Movie>{};
    Timer? debounce;
    bool isSearching = false;

    final result = await showModalBottomSheet<List<Movie>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> onSearchChanged(String value) async {
              debounce?.cancel();
              final query = value.trim();

              if (query.length < 2) {
                setModalState(() {
                  searchResults.clear();
                  isSearching = false;
                });
                return;
              }

              debounce = Timer(const Duration(milliseconds: 350), () async {
                if (!context.mounted) return;
                setModalState(() => isSearching = true);

                final results = await AppScope.instance.moviesRepository
                    .searchMovies(query);

                if (!context.mounted) return;
                setModalState(() {
                  searchResults
                    ..clear()
                    ..addAll(results);
                  isSearching = false;
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Favori Filmlerine Ekle',
                        style: TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: const TextStyle(color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: 'Film ara (en az 2 karakter)',
                        hintStyle: const TextStyle(color: AppColors.textMedium),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textMedium),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${selectedMovies.length} film seçildi',
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: isSearching
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : searchResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Film arayarak seçim yapabilirsin.',
                                    style:
                                        TextStyle(color: AppColors.textMedium),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: searchResults.length,
                                  separatorBuilder: (_, __) => Divider(
                                    color: AppColors.textHigh
                                        .withValues(alpha: 0.06),
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final movie = searchResults[index];
                                    final isAlreadyAdded =
                                        existingIds.contains(movie.id);
                                    final isSelected =
                                        selectedMovies.containsKey(movie.id);

                                    return ListTile(
                                      enabled: !isAlreadyAdded,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 4),
                                      leading: SizedBox(
                                        width: 42,
                                        child: AspectRatio(
                                          aspectRatio: 2 / 3,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: movie.posterUrl.isEmpty
                                                ? Container(
                                                    color: AppColors.surface,
                                                    child: const Icon(
                                                      Icons.movie,
                                                      color:
                                                          AppColors.textMedium,
                                                      size: 18,
                                                    ),
                                                  )
                                                : CachedNetworkImage(
                                                    imageUrl: movie.posterUrl,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        movie.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isAlreadyAdded
                                              ? AppColors.textMedium
                                              : AppColors.textHigh,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        isAlreadyAdded
                                            ? 'Bu film zaten favorilerde'
                                            : movie.releaseYear,
                                        style: TextStyle(
                                          color: isAlreadyAdded
                                              ? AppColors.warning
                                              : AppColors.textMedium,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: isAlreadyAdded
                                            ? null
                                            : (checked) {
                                                setModalState(() {
                                                  if (checked == true) {
                                                    selectedMovies[movie.id] =
                                                        movie;
                                                  } else {
                                                    selectedMovies
                                                        .remove(movie.id);
                                                  }
                                                });
                                              },
                                      ),
                                      onTap: isAlreadyAdded
                                          ? null
                                          : () {
                                              setModalState(() {
                                                if (isSelected) {
                                                  selectedMovies
                                                      .remove(movie.id);
                                                } else {
                                                  selectedMovies[movie.id] =
                                                      movie;
                                                }
                                              });
                                            },
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              debounce?.cancel();
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMedium,
                              side: const BorderSide(color: AppColors.divider),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Vazgeç'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedMovies.isEmpty
                                ? null
                                : () {
                                    debounce?.cancel();
                                    Navigator.of(context)
                                        .pop(selectedMovies.values.toList());
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textHigh,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Kaydet'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    debounce?.cancel();
    searchController.dispose();
    return result;
  }

  Widget _buildFavoritesGrid(List<dynamic> movies) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        ...movies.asMap().entries.map((entry) {
          final index = entry.key;
          final movie = entry.value;
          final posterUrl = movie.posterUrl;

          return Expanded(
            child: Padding(
              padding:
                  EdgeInsets.only(right: index == movies.length - 1 ? 0 : 8),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                    image: posterUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(posterUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
        if (movies.length < 4) Spacer(flex: 4 - movies.length),
      ],
    );
  }

  Widget _buildUserListsSection(UserDetailViewModel vm) {
    if (!vm.canSeeProfileDetails) {
      return const SizedBox.shrink();
    }

    final otherLists = vm.lists
        .where((l) => !l.name.toLowerCase().contains('favori'))
        .toList();

    if (otherLists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: otherLists.map((userList) {
        final listName = userList.name;
        final items = userList.items;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      listName.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListDetailScreen(
                            list: userList,
                            isMe: widget.isMe,
                          ),
                        ),
                      );
                      if (changed == true) {
                        await vm.load();
                      }
                    },
                    child: Text(
                      widget.isMe ? 'Listeyi Düzenle' : 'Tümünü Gör',
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                SizedBox(
                  height: 140,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_filter_outlined,
                              color: AppColors.textMedium, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            widget.isMe
                                ? 'Bu listeye henüz film eklemedin'
                                : 'Bu listede henüz film yok',
                            style: const TextStyle(color: AppColors.textMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length > 5 ? 5 : items.length,
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      final posterUrl = item.posterUrl;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                              image: posterUrl.isNotEmpty
                                  ? DecorationImage(
                                      image:
                                          CachedNetworkImageProvider(posterUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: posterUrl.isEmpty
                                ? const Center(
                                    child: Icon(Icons.movie,
                                        color: AppColors.textMedium))
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchHistory(UserDetailViewModel vm) {
    if (vm.matchHistoryItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'EŞLEŞME GEÇMİŞİ',
              style: TextStyle(
                color: AppColors.textMedium,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_alt_outlined, color: AppColors.textMedium, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Henüz eşleşme geçmişin yok',
                      style: TextStyle(color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EŞLEŞME GEÇMİŞİ',
                style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (vm.matchHistoryItems.length > 4)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MatchHistoryFullListScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: vm.matchHistoryItems.map((match) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: () {
                      // Push to the matched user's profile
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserDetailScreen(
                            userId: match.matchedUserId,
                            isMe: false,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.surface,
                          backgroundImage: (match.avatarUrl != null && match.avatarUrl!.isNotEmpty)
                              ? NetworkImage(
                                  match.avatarUrl!.startsWith('http')
                                      ? match.avatarUrl!
                                      : 'http://10.0.2.2:8080${match.avatarUrl}',
                                )
                              : null,
                          child: (match.avatarUrl == null || match.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person, color: AppColors.textMedium)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.username ?? 'Kullanıcı',
                          style: const TextStyle(
                            color: AppColors.textHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 70,
                          child: Text(
                            match.movieName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatItem(String count, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count,
          style: const TextStyle(
            color: AppColors.textHigh,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMedium,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatDivider() {
    return Container(
      height: 24,
      width: 1,
      color: AppColors.divider,
    );
  }

  Widget _buildPrivacyInfoCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMedium, size: 48),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium)),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: AppColors.textMedium, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.overlay,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.textHigh, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
