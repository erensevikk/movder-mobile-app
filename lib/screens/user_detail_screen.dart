import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/movie.dart';
import '../services/api_service.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  final bool isMe;

  const UserDetailScreen({
    super.key,
    required this.userId,
    this.isMe = false,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _userLists = [];
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final data = widget.isMe
        ? await ApiService.getProfile()
        : await ApiService.getUserProfile(widget.userId);

    // Kendi listelerimiziyse getir
    List<Map<String, dynamic>> listsData = [];
    if (widget.isMe) {
      listsData = await ApiService.getMyLists();
      // Her liste için film içeriklerini çekelim
      for (var list in listsData) {
        final id = list['id'] ?? list['_id'];
        if (id != null) {
          list['items'] = await ApiService.getListItems(id.toString());
        } else {
          list['items'] = [];
        }
      }
    }

    if (mounted) {
      setState(() {
        _profileData = data;
        _userLists = listsData;
        _isLoading = false;
      });
    }
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
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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

    final avatarUrl = _profileData?['avatarUrl']?.toString();
    final rawDescription = _profileData?['description']?.toString();
    final hasDescription =
        rawDescription != null && rawDescription.trim().isNotEmpty;
    final description = hasDescription
        ? rawDescription.trim()
        : 'Seni tanımlayan bir şeyler yaz...';

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: coverHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF151515)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: -(avatarSize / 2),
              child: GestureDetector(
                onTap: widget.isMe ? _pickAndUploadImage : null,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E1E1E),
                    border:
                        Border.all(color: const Color(0xFF0F0F0F), width: 4),
                    image: avatarUrl != null && avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image:
                                NetworkImage('${ApiService.baseUrl}$avatarUrl'),
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
              ),
            ),
            if (widget.isMe)
              Positioned(
                left: 85,
                bottom: -40,
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
            Positioned(
              left: 118,
              right: 12,
              bottom: -40,
              child: Container(
                height: 74,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHeaderStatItem('0', 'Anlik Eslesme'),
                    _buildHeaderStatDivider(),
                    _buildHeaderStatItem('0', 'Sohbet'),
                    _buildHeaderStatDivider(),
                    _buildHeaderStatItem('0', 'Izleme'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: (avatarSize / 2) + 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
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
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: widget.isMe ? _editDescription : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: hasDescription ? Colors.white54 : Colors.white38,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                if (widget.isMe)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.edit, color: Colors.white38, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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
          await _fetchProfile(); // Veriyi tazelemek için
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

  Future<void> _editDescription() async {
    final currentDesc = _profileData?['description']?.toString() ?? '';
    final controller = TextEditingController(text: currentDesc);

    final newDesc = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Hakkında', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Kendinden bahset...',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (newDesc != null && newDesc != currentDesc) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final res = await ApiService.updateProfile(description: newDesc);

      if (mounted) {
        if (res != null && res['error'] == null) {
          _profileData?['description'] = res['description'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    (res?['error'] ?? 'Açıklama güncellenemedi').toString())),
          );
        }
        setState(() => _isLoading = false);
      }
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
    const bool hasFavorites = false; // Şimdilik hep boş gösteriyoruz

    return Padding(
      padding: const EdgeInsets.all(20),
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
                GestureDetector(
                  onTap: _showCreateListDialog,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Liste Oluştur',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasFavorites && widget.isMe)
            _buildLetterboxdCTA()
          else if (!hasFavorites && !widget.isMe)
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
          else
            _buildFavoritesGrid(),
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

  Widget _buildFavoritesGrid() {
    return Row(
      children: List.generate(
        4,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Center(
                  child: Icon(Icons.movie, color: Colors.white24),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserListsSection() {
    if (!widget.isMe) {
      return const SizedBox
          .shrink(); // Şimdilik sadece isMe'de listeleri gösteriyoruz.
    }

    if (_userLists.isEmpty) {
      return const SizedBox
          .shrink(); // Hiç liste yoksa gereksiz yer kaplamasın.
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _userLists.map((userList) {
        final listName = userList['name'] ?? 'İsimsiz Liste';
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
                  if (items.isNotEmpty) // Gerekirse her zaman çıksın
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Hepsini gör ekranı hazırlanıyor')),
                        );
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
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
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
                        'Bu listeye henüz film eklemedin',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
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
            final canCreate = titleController.text.trim().isNotEmpty &&
                selectedMovies.isNotEmpty &&
                !isSaving;

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
                          onChanged: (_) => setSheetState(() {}),
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
                                          'Film eklemek icin arama yap.',
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
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: !canCreate
                                ? null
                                : () async {
                                    setSheetState(() => isSaving = true);

                                    final createRes =
                                        await ApiService.createList(
                                      name: titleController.text.trim(),
                                      description: descController.text.trim(),
                                      isPublic: true,
                                    );

                                    final listId =
                                        _extractListId(createRes?['listId']);
                                    if (createRes == null ||
                                        createRes['error'] != null ||
                                        listId == null) {
                                      setSheetState(() => isSaving = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text((createRes?[
                                                        'error'] ??
                                                    'Koleksiyon olusturulamadi')
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
                                  ? 'Olusturuluyor...'
                                  : 'Koleksiyonu Olustur (${selectedMovies.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
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
        const SnackBar(content: Text('Koleksiyon olusturuldu.')),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: const Text(
              'Son aktivite bulunamadı',
              style: TextStyle(color: Colors.white38),
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
              'Dosya secici baslatilamadi. Uygulamayi tamamen kapatip yeniden acin.',
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
