import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'list_detail_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  final bool isMe;
  final bool openImportOnStart;

  const UserDetailScreen({
    super.key,
    required this.userId,
    this.isMe = false,
    this.openImportOnStart = false,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userLists = [];
  bool _isImporting = false;
  String _coverUrl = ''; // Kapak fotoğrafı URL'si
  bool _letterboxdImported = false;
  bool _isEditMode = false;
  final TextEditingController _descriptionController = TextEditingController();
  dynamic _draftCoverBytes;
  String? _draftCoverFileName;
  bool _draftDeleteCover = false;
  String _descriptionSnapshot = '';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _canSeeProfileDetails {
    if (widget.isMe) return true;
    return _profileData?['canSeeProfileDetails'] != false;
  }

  Map<String, dynamic>? get _favoriteList {
    for (final list in _userLists) {
      final name = (list['name'] ?? '').toString().toLowerCase();
      if (name.contains('favori')) return list;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile().then((_) {
      if (widget.openImportOnStart && mounted) {
        _startLetterboxdImport();
      }
    });
  }

  Future<void> _fetchProfile() async {
    final data = widget.isMe
        ? await ApiService.getProfile()
        : await ApiService.getUserProfile(widget.userId);

    List<Map<String, dynamic>> listsData = [];
    if (widget.isMe) {
      listsData = await ApiService.getMyLists();
    } else if (data?['canSeeProfileDetails'] == true) {
      listsData = await ApiService.getUserLists(widget.userId);
    }

    // OPTIMIZED: N+1 sorununu çözmek için tüm liste item'larını paralel olarak çek
    if (listsData.isNotEmpty) {
      final listFutures = listsData.map((list) async {
        final id = list['id'] ?? list['_id'];
        if (id != null) {
          try {
            final items = await ApiService.getListItems(id.toString());
            return {'id': id, 'items': items};
          } catch (e) {
            return {'id': id, 'items': <Map<String, dynamic>>[]};
          }
        }
        return {'id': id, 'items': <Map<String, dynamic>>[]};
      }).toList();

      // Tüm API çağrılarını paralel olarak yap
      final listResults = await Future.wait(listFutures);

      // Sonuçları listelere ata
      final itemsMap = {
        for (var r in listResults)
          r['id'].toString(): r['items'] as List<Map<String, dynamic>>
      };
      for (var list in listsData) {
        final id = list['id'] ?? list['_id'];
        list['items'] = itemsMap[id?.toString()] ?? [];
      }
    }

    if (mounted) {
      setState(() {
        _profileData = data;
        _coverUrl = (data?['coverUrl'] ?? '').toString();
        _letterboxdImported = data?['letterboxdImported'] == true;
        _userLists = listsData;
        _isLoading = false;
      });
      // Controller'a mevcut description'u ata
      final raw = (data?['description'] ?? '').toString();
      _descriptionController.text = raw;
      _descriptionSnapshot = raw;
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _descriptionSnapshot = _descriptionController.text;
      _draftCoverBytes = null;
      _draftCoverFileName = null;
      _draftDeleteCover = false;
    });
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      _descriptionController.text = _descriptionSnapshot;
      _draftCoverBytes = null;
      _draftCoverFileName = null;
      _draftDeleteCover = false;
    });
  }

  Future<void> _saveEditMode() async {
    final newDesc = _descriptionController.text.trim();
    final currentDesc = (_profileData?['description'] ?? '').toString();
    final hasDescriptionChange = newDesc != currentDesc;
    final hasCoverChange = _draftCoverBytes != null || _draftDeleteCover;

    if (!hasDescriptionChange && !hasCoverChange) {
      setState(() => _isEditMode = false);
      return;
    }

    final res = await ApiService.updateProfile(
      description: hasDescriptionChange ? newDesc : null,
      coverImageBytes: _draftCoverBytes,
      coverImageFileName: _draftCoverFileName,
      deleteCover: _draftDeleteCover,
    );
    if (!mounted) return;

    if (res != null && res['error'] == null) {
      setState(() {
        _profileData = {
          ..._profileData ?? {},
          'description': newDesc,
        };
        _coverUrl = _draftDeleteCover
            ? ''
            : (res['coverUrl'] ?? _coverUrl).toString();
        _descriptionSnapshot = newDesc;
        _draftCoverBytes = null;
        _draftCoverFileName = null;
        _draftDeleteCover = false;
        _isEditMode = false;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text((res?['error'] ?? 'Profil güncellenemedi').toString()),
      ),
    );
  }

  void _previewDeleteCover() {
    setState(() {
      _draftCoverBytes = null;
      _draftCoverFileName = null;
      _draftDeleteCover = _coverUrl.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    if (_profileData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Profil bulunamadı',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final username = (_profileData!['username'] ?? 'Kullanıcı').toString();

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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(username),
          ),
          SliverToBoxAdapter(
            child: _buildFavoriteFilmsOrEmptyState(),
          ),
          SliverToBoxAdapter(
            child: _buildUserListsSection(),
          ),
          SliverToBoxAdapter(
            child: _buildMatchHistory(),
          ),
          SliverToBoxAdapter(
            child: _buildRecentActivity(),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
        ],
      ),
    );
  }

  Widget _buildHeader(String username) {
    const double coverHeight = 140.0;
    const double avatarSize = 90.0;
    final topInset = MediaQuery.of(context).padding.top;

    final avatarUrl = _profileData?['avatarUrl']?.toString();
    final rawDescription = _profileData?['description']?.toString();
    final hasDescription =
        rawDescription != null && rawDescription.trim().isNotEmpty;
    final description = hasDescription
        ? rawDescription.trim()
        : 'Seni tanımlayan bir şeyler yaz...';

    // Kapak: önce kullanıcı kapak URL'si, yoksa ilk listede ilk film posteri
    String effectiveCover = '';
    bool effectiveCoverIsTmdb = false;
    DecorationImage? coverDecorationImage;
    if (_draftCoverBytes != null) {
      coverDecorationImage = DecorationImage(
        image: MemoryImage(_draftCoverBytes),
        fit: BoxFit.cover,
      );
    } else if (!_draftDeleteCover && _coverUrl.isNotEmpty) {
      effectiveCover = _coverUrl;
    }
    if (!_draftDeleteCover &&
        coverDecorationImage == null &&
        effectiveCover.isEmpty) {
      for (final list in _userLists) {
        final items = list['items'] as List? ?? [];
        if (items.isNotEmpty) {
          final poster = items.first['posterUrl']?.toString() ?? '';
          if (poster.isNotEmpty) {
            effectiveCover = poster;
            effectiveCoverIsTmdb = poster.startsWith('http');
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
            // Stack boyutunu belirleyen görünmez alan
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
            // Kapak fotoğrafı / gradient (üst kısma sabitlendi)
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: coverHeight,
              child: GestureDetector(
                onTap: widget.isMe && _isEditMode
                    ? _pickAndUploadCover
                    : (!widget.isMe && _coverUrl.isNotEmpty
                        ? () => _showFullScreenImage(
                            '${ApiService.baseUrl}$_coverUrl')
                        : null),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    image: coverDecorationImage ??
                        (effectiveCover.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(
                              effectiveCoverIsTmdb
                                  ? effectiveCover
                                  : '${ApiService.baseUrl}$effectiveCover',
                            ),
                            fit: BoxFit.cover,
                          )
                        : null),
                  ),
                  // "Kapağı Değiştir" sadece edit modda görünür
                  child: widget.isMe && _isEditMode
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
                                  _coverUrl.isNotEmpty
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
                _isEditMode &&
                (_coverUrl.isNotEmpty || _draftCoverBytes != null) &&
                !_draftDeleteCover)
              Positioned(
                top: topInset + 12,
                right: 16,
                child: GestureDetector(
                  onTap: _previewDeleteCover,
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
            // Avatar — artık Stack sınırları İÇİNDE
            Positioned(
              left: 7,
              bottom: 0,
              child: GestureDetector(
                onTap: widget.isMe ? _pickAndUploadImage : null,
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
                        image: avatarUrl != null && avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(
                                    '${ApiService.baseUrl}$avatarUrl'),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: avatarUrl == null || avatarUrl.isEmpty
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
            // Kamera butonu: sadece edit modda görünür
            if (widget.isMe && _isEditMode)
              Positioned(
                left: 69,
                bottom: 5,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
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
        // Username + "Profili Düzenle" toggle butonu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (widget.isMe && _isEditMode) ...[
                GestureDetector(
                  onTap: _cancelEditMode,
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
                  onTap: _saveEditMode,
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
                  onTap: _enterEditMode,
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
        // Description: edit modda TextField, normal modda Text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.isMe && _isEditMode
              ? TextField(
                  controller: _descriptionController,
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
                  !widget.isMe && !_canSeeProfileDetails
                      ? 'Bu profil detayları yalnızca arkadaşlarına açık.'
                      : _descriptionController.text.isNotEmpty
                          ? _descriptionController.text
                          : (hasDescription
                              ? description
                              : 'Seni tanımlayan bir şeyler yaz...'),
                  style: TextStyle(
                    color: (!widget.isMe && !_canSeeProfileDetails)
                        ? Colors.white54
                        : (hasDescription ? Colors.white54 : Colors.white38),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();

    // Galeri mi Kamera mı seç
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: Colors.white70),
                title: const Text('Galeriden Seç',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                title: const Text('Kamerayı Kullan',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return; // Kullanıcı iptal etti

    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();

      setState(() => _isLoading = true);
      final res = await ApiService.updateProfile(
        imageBytes: bytes,
        imageFileName: pickedFile.name,
      );

      if (mounted) {
        if (res != null && res['error'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil fotoğrafı güncellendi')),
          );
          await _fetchProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text((res?['error'] ?? 'Fotoğraf yüklenemedi').toString())),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  /// Tam ekran fotoğraf görüntüleyici
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

  /// Kapak fotoğrafı değiştir — direkt galeri açılır
  Future<void> _pickAndUploadCover() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _draftCoverBytes = bytes;
        _draftCoverFileName = pickedFile.name;
        _draftDeleteCover = false;
      });
    }
  }

  Widget _buildHeaderStatDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white12,
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

  Widget _buildFavoriteFilmsOrEmptyState() {
    if (!widget.isMe && !_canSeeProfileDetails) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FAVORi FİLMLER',
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

    final favoriteList = _favoriteList;
    final favoriteItems = (favoriteList?['items'] as List?) ?? const [];
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
                    // + Butonu (Liste Oluştur)
                    GestureDetector(
                      onTap: _showCreateListDialog,
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListDetailScreen(
                                listData: favoriteList,
                                isMe: widget.isMe,
                              ),
                            ),
                          ).then((_) => _fetchProfile());
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
          // İçerik durumuna göre CTA / boş durum seç
          if (!hasContent && widget.isMe && !_letterboxdImported)
            _buildLetterboxdCTA()
          else if (!hasContent && widget.isMe && _letterboxdImported)
            // Import yapılmış ama hiç film yok — Ekle butonu
            _buildAddFavoritesButton()
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

  Widget _buildLetterboxdCTA() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141A1F), // Letterboxd mavimsi/lacivert tonu
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C3440)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sync_rounded,
            color: Color(0xFF40BCF4), // Letterboxd mavi accent
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
              onPressed: _isImporting ? null : _startLetterboxdImport,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF00E054), // Letterboxd yeşil accent
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                _isImporting
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

  Widget _buildAddFavoritesButton() {
    return GestureDetector(
      onTap: _showCreateListDialog,
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
          final posterUrl = movie['posterUrl']?.toString() ?? '';

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
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    image: posterUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(posterUrl.startsWith('http')
                                ? posterUrl
                                : '${ApiService.baseUrl}$posterUrl'),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
        // Eğer 4'ten az film varsa, sağ tarafı boş bırakmak için boş Expandedlar eklemiyoruz
        // (Kullanıcı 'boş duran kartlar kaldırılsın' dediği için sadece posterleri gösteriyoruz)
        if (movies.length < 4) Spacer(flex: 4 - movies.length),
      ],
    );
  }

  Widget _buildUserListsSection() {
    if (!widget.isMe && !_canSeeProfileDetails) {
      return const SizedBox.shrink();
    }

    if (_userLists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _userLists.where((userList) {
        final listName = (userList['name'] ?? '').toString().toLowerCase();
        return !listName.contains('favori');
      }).map((userList) {
        final listName = userList['name'] ?? 'İsimsiz Liste';
        final isFavoriteList =
            listName.toString().toLowerCase().contains('favori');
        final items = (userList['items'] as List?) ?? [];

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
                      listName.toString().toUpperCase(),
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListDetailScreen(
                            listData: userList,
                            isMe: widget.isMe,
                          ),
                        ),
                      ).then((_) => _fetchProfile());
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
                          if (widget.isMe && isFavoriteList) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ListDetailScreen(
                                        listData: userList,
                                        isMe: widget.isMe,
                                      ),
                                    ),
                                  ).then((_) => _fetchProfile());
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white12),
                                  backgroundColor: const Color(0xFF232323),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Favori Filmlerini Ekle',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
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
                        ],
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 140, // Afişler için 140px ideal
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length > 5
                        ? 5
                        : items.length, // Maksimum 5 eleman gösterelim
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      final posterUrl = item['posterUrl']?.toString() ?? '';
                      // Link kontrolü ve düzeltmesi
                      final imageUrl = posterUrl.isNotEmpty
                          ? (posterUrl.startsWith('http')
                              ? posterUrl
                              : 'https://image.tmdb.org/t/p/w500$posterUrl')
                          : '';

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                              image: imageUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imageUrl.isEmpty
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
    // Statik eşleşme verileri (test amaçlı)
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
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Tüm eşleşmeler yakında eklenecek!')),
                    );
                  },
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      color: Colors.white70,
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
                        width: 70, // Max width for movie name
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

  Future<void> _showCreateListDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final searchController = TextEditingController();

    final List<Movie> selectedMovies = [];
    List<Movie> searchResults = [];
    Timer? debounce;
    int searchRequestId = 0;

    bool isSearching = false;
    bool isSaving = false;

    Future<void> runSearch(
        String query, void Function(void Function()) setSheetState) async {
      final q = query.trim();
      searchRequestId++;
      final requestId = searchRequestId;

      if (q.length < 2) {
        setSheetState(() {
          searchResults = [];
          isSearching = false;
        });
        return;
      }

      setSheetState(() {
        isSearching = true;
      });
      final results = await ApiService.searchMovies(q);

      if (requestId != searchRequestId) {
        return;
      }

      setSheetState(() {
        searchResults = results.take(5).toList();
        isSearching = false;
      });
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111317),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 18,
                      right: 18,
                      top: 14,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const Text(
                          'Yeni Koleksiyon',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'En az 1 film ekleyerek koleksiyonunuzu oluşturun.',
                          style: TextStyle(color: Colors.white60),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-ZğüşıöçĞÜŞİÖÇ\s]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Koleksiyon adı',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF1A1D22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Açıklama (opsiyonel)',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF1A1D22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            if (value.trim().isEmpty) {
                              debounce?.cancel();
                              searchRequestId++;
                              setSheetState(() {
                                searchResults = [];
                                isSearching = false;
                              });
                              return;
                            }

                            debounce?.cancel();
                            debounce =
                                Timer(const Duration(milliseconds: 350), () {
                              runSearch(value, setSheetState);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Film ara (Interstellar, Dune...)',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF1A1D22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedMovies.isNotEmpty)
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: selectedMovies.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final movie = selectedMovies[index];
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: movie.posterUrl.isNotEmpty
                                          ? _moviePosterThumb(
                                              _thumbPosterUrl(movie.posterUrl),
                                              width: 72,
                                              height: 110,
                                              cacheWidth: 144,
                                            )
                                          : Container(
                                              width: 72,
                                              color: const Color(0xFF2A2A2A),
                                              child: const Icon(Icons.movie,
                                                  color: Colors.white30),
                                            ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() =>
                                            selectedMovies.removeAt(index)),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black87,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close,
                                              color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF15181D),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: isSearching
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.redAccent))
                                : searchResults.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Film eklemek için arama yap.',
                                          style:
                                              TextStyle(color: Colors.white38),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: searchResults.length,
                                        itemBuilder: (context, index) {
                                          final movie = searchResults[index];
                                          final selected = selectedMovies
                                              .any((m) => m.id == movie.id);

                                          return ListTile(
                                            leading: movie.posterUrl.isNotEmpty
                                                ? _moviePosterThumb(
                                                    _thumbPosterUrl(
                                                        movie.posterUrl),
                                                    width: 38,
                                                    height: 54,
                                                    cacheWidth: 76,
                                                  )
                                                : _movieLeadingFallback(),
                                            title: Text(
                                              movie.title,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              movie.releaseYear,
                                              style: const TextStyle(
                                                  color: Colors.white54),
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(
                                                selected
                                                    ? Icons.check_circle
                                                    : Icons.add_circle_outline,
                                                color: selected
                                                    ? Colors.greenAccent
                                                    : Colors.white70,
                                              ),
                                              onPressed: () {
                                                setSheetState(() {
                                                  if (selected) {
                                                    selectedMovies.removeWhere(
                                                        (m) =>
                                                            m.id == movie.id);
                                                  } else {
                                                    selectedMovies.add(movie);
                                                  }
                                                });
                                              },
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: titleController,
                          builder: (context, titleValue, _) {
                            final canCreate =
                                titleValue.text.trim().isNotEmpty &&
                                    selectedMovies.isNotEmpty &&
                                    !isSaving;

                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: !canCreate
                                    ? null
                                    : () async {
                                        setSheetState(() => isSaving = true);

                                        if (!mounted) return;

                                        final createRes =
                                            await ApiService.createList(
                                          name: titleController.text.trim(),
                                          description:
                                              descController.text.trim(),
                                          isPublic: true,
                                        );

                                        final listId = _extractListId(
                                            createRes?['listId']);
                                        if (createRes == null ||
                                            createRes['error'] != null ||
                                            listId == null) {
                                          setSheetState(() => isSaving = false);
                                          if (mounted) {
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text((createRes?[
                                                            'error'] ??
                                                        'Koleksiyon oluşturulamadı')
                                                    .toString()),
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        for (final movie in selectedMovies) {
                                          await ApiService.addMovieToList(
                                            listId: listId,
                                            tmdbId: movie.id,
                                            movieName: movie.title,
                                            posterUrl: movie.posterUrl,
                                          );
                                        }

                                        if (ctx.mounted) {
                                          Navigator.pop(ctx, true);
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E054),
                                  foregroundColor: Colors.black,
                                  disabledBackgroundColor: Colors.white12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isSaving
                                      ? 'Oluşturuluyor...'
                                      : 'Koleksiyonu Oluştur (${selectedMovies.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    debounce?.cancel();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koleksiyon oluşturuldu.')),
      );
      await _fetchProfile();
    }
  }

  String? _extractListId(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final oid = value[r'$oid']?.toString();
      if (oid != null && oid.isNotEmpty) return oid;
    }
    return null;
  }

  String _thumbPosterUrl(String url) {
    if (url.contains('/w500')) return url.replaceFirst('/w500', '/w92');
    if (url.contains('/w342')) return url.replaceFirst('/w342', '/w92');
    return url;
  }

  Widget _movieLeadingFallback({double width = 38, double height = 54}) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF252831),
      child: const Icon(Icons.movie, color: Colors.white54, size: 18),
    );
  }

  Widget _moviePosterThumb(
    String url, {
    required double width,
    required double height,
    required int cacheWidth,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        memCacheWidth: cacheWidth,
        maxWidthDiskCache: cacheWidth,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) =>
            _movieLeadingFallback(width: width, height: height),
        errorWidget: (_, __, ___) =>
            _movieLeadingFallback(width: width, height: height),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (!widget.isMe && !_canSeeProfileDetails) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İZLEME GEÇMİŞİ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _buildPrivacyInfoCard(
              icon: Icons.visibility_off_outlined,
              text: 'Bu kullanıcının izleme geçmişi sadece arkadaşlarına açık.',
            ),
          ],
        ),
      );
    }

    final history = (_profileData?['watchHistory'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İZLEME GEÇMİŞİ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Text(
                'Son aktivite bulunamadı',
                style: TextStyle(color: Colors.white38),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final posterPath = item['posterPath']?.toString() ?? '';
                  final imageUrl = posterPath.startsWith('http')
                      ? posterPath
                      : '${ApiService.baseUrl}$posterPath';

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _moviePosterThumb(
                        _thumbPosterUrl(imageUrl),
                        width: 93,
                        height: 140,
                        cacheWidth: 150,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyInfoCard({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 36),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startLetterboxdImport() async {
    setState(() => _isImporting = true);

    try {
      FilePickerResult? picked;
      try {
        picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['zip', 'csv'],
          withData: true,
        );
      } on MissingPluginException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dosya seçici başlatılamadı. Uygulamayı tamamen kapatıp yeniden açın.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dosya okunamadı')),
        );
        setState(() => _isImporting = false);
        return;
      }

      final preview = await ApiService.previewLetterboxdImport(
        fileName: file.name,
        bytes: bytes,
      );

      if (!mounted) return;
      if (preview == null || preview['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text((preview?['error'] ?? 'Önizleme alınamadı').toString())),
        );
        setState(() => _isImporting = false);
        return;
      }

      final strategy = await _pickImportStrategy(preview);
      if (!mounted) return;
      if (strategy == null) {
        setState(() => _isImporting = false);
        return;
      }

      final token = (preview['previewToken'] ?? '').toString();
      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önizleme token alınamadı')),
        );
        setState(() => _isImporting = false);
        return;
      }

      final result = await ApiService.commitLetterboxdImport(
        previewToken: token,
        strategy: strategy,
      );

      if (!mounted) return;
      if (result == null || result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  (result?['error'] ?? 'İçe aktarma başarısız').toString())),
        );
        setState(() => _isImporting = false);
        return;
      }

      await _showImportResultDialog(result);

      if (mounted) {
        await _fetchProfile();
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<String?> _pickImportStrategy(Map<String, dynamic> preview) async {
    final totals = preview['totals'] as Map<String, dynamic>?;
    final listCount = (totals?['listCount'] ?? 0).toString();
    final itemCount = (totals?['itemCount'] ?? 0).toString();
    final unresolved = (totals?['unresolvedCount'] ?? 0).toString();
    final conflictCount = (totals?['conflictCount'] ?? 0).toString();
    final warnings = (preview['warnings'] as List?) ?? const [];
    final lists = (preview['lists'] as List?) ?? const [];
    final conflicts = (preview['conflicts'] as List?) ?? const [];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Letterboxd Önizleme',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Liste: $listCount • Film: $itemCount • Eşleşmeyen: $unresolved • Çakışma: $conflictCount',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                if (warnings.isNotEmpty)
                  Text(
                    'Uyarı: ${warnings.length}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                if (conflicts.isNotEmpty)
                  Text(
                    'Çakışan listeler: ${conflicts.length}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final row = (lists[index] as Map).cast<String, dynamic>();
                      final createdAt =
                          _formatDate(row['createdAt']?.toString());
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (row['name'] ?? 'Liste').toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Film: ${(row['itemCount'] ?? 0)} • Oluşturulma: $createdAt',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      );
                    },
                  ),
                ),
                if (conflicts.isNotEmpty) const Divider(color: Colors.white10),
                if (conflicts.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 90),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: conflicts.length,
                      itemBuilder: (context, index) {
                        final row =
                            (conflicts[index] as Map).cast<String, dynamic>();
                        return Text(
                          '• ${row['listName']} (mevcut: ${row['existingItemCount']}, yeni: ${row['incomingItemCount']})',
                          style: const TextStyle(color: Colors.white54),
                        );
                      },
                    ),
                  ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Birleştir (önerilen)',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Aynı listedeki yeni filmleri ekler',
                      style: TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.pop(ctx, 'merge'),
                ),
                ListTile(
                  title: const Text('Üzerine Yaz',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                      'Mevcut listedeki filmleri silip yeniden yazar',
                      style: TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.pop(ctx, 'overwrite'),
                ),
                ListTile(
                  title: const Text('Kopya Liste Oluştur',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Aynı isim için yeni liste açar',
                      style: TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.pop(ctx, 'duplicate'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showImportResultDialog(Map<String, dynamic> result) {
    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final skipped = result['skipped'] as Map<String, dynamic>? ?? {};
    final unresolved = (skipped['unresolved'] as List?)?.length ?? 0;
    final duplicates = (skipped['duplicates'] as List?)?.length ?? 0;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('Import Sonucu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oluşturulan liste: ${summary['createdLists'] ?? 0}',
                style: const TextStyle(color: Colors.white70)),
            Text('Güncellenen liste: ${summary['updatedLists'] ?? 0}',
                style: const TextStyle(color: Colors.white70)),
            Text('Eklenen film: ${summary['addedItems'] ?? 0}',
                style: const TextStyle(color: Colors.white70)),
            Text('Atlanan unresolved: $unresolved',
                style: const TextStyle(color: Colors.white70)),
            Text('Atlanan duplicate: $duplicates',
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return '${parsed.day} ${months[parsed.month]}';
  }
}
