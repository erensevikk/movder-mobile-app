import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/base/base_state.dart';
import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../lists/presentation/views/create_list_screen.dart';
import '../../../lists/presentation/views/list_detail_screen.dart';
import '../view_models/user_detail_view_model.dart';

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
        backgroundColor: Color(0xFF0F0F0F),
        body: LoadingView(),
      );
    }

    if (vm.status == ViewStatus.error || vm.profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
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
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0F0F0F),
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
            SliverToBoxAdapter(
              child: _buildMatchHistory(),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(UserDetailViewModel vm) {
    const double coverHeight = 140.0;
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
              height: topInset,
              child: Container(color: const Color(0xFF0F0F0F)),
            ),
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: coverHeight,
              child: GestureDetector(
                onTap: widget.isMe && vm.isEditMode
                    ? vm.pickCoverImage
                    : (!widget.isMe && profile.coverUrl.isNotEmpty
                        ? () => _showFullScreenImage(profile.coverUrl)
                        : null),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A1A), Color(0xFF1A1A1A)],
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
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_photo_alternate_rounded,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  profile.coverUrl.isNotEmpty
                                      ? 'Kapağı Değiştir'
                                      : 'Kapak Ekle',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
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
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
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
                        color: const Color(0xFF1E1E1E),
                        border: Border.all(
                            color: const Color(0xFF0F0F0F), width: 4),
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
                              color: Colors.white54,
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
                      color: const Color(0xFF2A2A2A),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF0F0F0F), width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 18),
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
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
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
                    color: Colors.white,
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
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      'Vazgeç',
                      style: TextStyle(
                        color: Colors.white54,
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
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'Kaydet',
                      style: TextStyle(
                        color: Colors.redAccent,
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
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Text(
                      'Profili Düzenle',
                      style: TextStyle(
                        color: Colors.white54,
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
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  maxLength: 150,
                  decoration: InputDecoration(
                    hintText: 'Kendinden bahset...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    counterStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                )
              : Text(
                  !vm.canSeeProfileDetails
                      ? 'Bu profil detayları yalnızca arkadaşlarına açık.'
                      : description,
                  style: TextStyle(
                    color: !vm.canSeeProfileDetails
                        ? Colors.white54
                        : (description.isNotEmpty
                            ? Colors.white54
                            : Colors.white38),
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
                color: Colors.white54,
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
                  color: Colors.white54,
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
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white70, size: 14),
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
                            color: Colors.white70,
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
            _buildAddFavoritesButton(vm)
          else if (!hasContent && !widget.isMe)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.movie_filter_outlined,
                      color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Henüz favori filmlerini seçmemiş',
                    style: TextStyle(color: Colors.white54),
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
        color: const Color(0xFF141A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C3440)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sync_rounded,
            color: Color(0xFF40BCF4),
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Profilin Çok Boş Görünüyor!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Letterboxd hesabını bağlayarak favori filmlerini, son izlediklerini ve incelemelerini Movder profiline taşı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
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
                backgroundColor: const Color(0xFF00E054),
                foregroundColor: Colors.black,
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

  Widget _buildAddFavoritesButton(UserDetailViewModel vm) {
    return GestureDetector(
      onTap: () async {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const CreateListScreen()),
        );
        if (created == true) {
          await vm.load();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: const Column(
          children: [
            Icon(Icons.add_circle_outline_rounded,
                color: Colors.white38, size: 40),
            SizedBox(height: 10),
            Text(
              'Favori Film Ekle',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                        color: Colors.white54,
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
                        color: Colors.white70,
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
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.movie_filter_outlined,
                              color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            widget.isMe
                                ? 'Bu listeye henüz film eklemedin'
                                : 'Bu listede henüz film yok',
                            style: const TextStyle(color: Colors.white54),
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
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
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
                                        color: Colors.white24))
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

  Widget _buildMatchHistory() {
    final matches = [
      {
        'name': 'Ali',
        'movie': 'Interstellar',
        'imageUrl': 'https://i.pravatar.cc/150?u=a042581f4e29026704d'
      },
      {
        'name': 'Ayşe',
        'movie': 'Oppenheimer',
        'imageUrl': 'https://i.pravatar.cc/150?u=a042581f4e29026704e'
      },
      {
        'name': 'Fatma',
        'movie': 'Barbie',
        'imageUrl': 'https://i.pravatar.cc/150?u=a042581f4e29026704f'
      },
      {
        'name': 'Mehmet',
        'movie': 'Inception',
        'imageUrl': 'https://i.pravatar.cc/150?u=a042581f4e29026704g'
      },
      {
        'name': 'Kemal',
        'movie': 'Dune',
        'imageUrl': 'https://i.pravatar.cc/150?u=a042581f4e29026704h'
      },
    ];

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
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (matches.length > 4)
                const Text(
                  'Tümünü Gör',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: matches.take(5).map((match) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: const Color(0xFF1E1E1E),
                        backgroundImage: NetworkImage(match['imageUrl']!),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        match['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 70,
                        child: Text(
                          match['movie']!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
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
      color: Colors.white12,
    );
  }

  Widget _buildPrivacyInfoCard({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white38, size: 64),
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
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
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
