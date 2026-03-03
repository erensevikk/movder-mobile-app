import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../models/movie.dart';
import '../services/api_service.dart';
import 'movie_detail_screen.dart';

class ListDetailScreen extends StatefulWidget {
  final Map<String, dynamic> listData;
  final bool isMe;

  const ListDetailScreen({
    super.key,
    required this.listData,
    required this.isMe,
  });

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  late String listName;
  late String listId;
  List<Map<String, dynamic>> items = [];
  bool isEditing = false;
  bool isLoading = false;

  /// Edit modunda işaretlenen (silinmeyi bekleyen) filmler
  final Set<int> _pendingRemovals = {};

  @override
  void initState() {
    super.initState();
    listName = widget.listData['name'] ?? 'Liste';
    listId = (widget.listData['id'] ?? widget.listData['_id']).toString();
    items = List<Map<String, dynamic>>.from(widget.listData['items'] ?? []);
  }

  /// X'e basınca sadece pending listesine ekle — backend'e gitme
  void _markForRemoval(int tmdbId) {
    setState(() {
      if (_pendingRemovals.contains(tmdbId)) {
        _pendingRemovals.remove(tmdbId); // Tekrar basılırsa işareti kaldır
      } else {
        _pendingRemovals.add(tmdbId);
      }
    });
  }

  /// Yeşil tik: pending filmleri sil + yeni sıralamayı kaydet
  Future<void> _commitRemovals() async {
    setState(() => isLoading = true);

    // 1) Bekleyen silme işlemleri varsa gönder
    final failed = <int>[];
    if (_pendingRemovals.isNotEmpty) {
      final toRemove = Set<int>.from(_pendingRemovals);
      for (final tmdbId in toRemove) {
        final success = await ApiService.removeMovieFromList(listId, tmdbId);
        if (success) {
          _pendingRemovals.remove(tmdbId);
        } else {
          failed.add(tmdbId);
        }
      }
      // Başarıyla silinenlerini local listeden çıkar
      if (mounted) {
        setState(() {
          items.removeWhere((item) {
            final id = item['tmdbId'];
            return id != null && toRemove.contains(id) && !failed.contains(id);
          });
        });
      }
    }

    // 2) Mevcut sıralamayı backend'e kaydet
    final orderedIds = items.map((i) => i['tmdbId']).whereType<int>().toList();
    if (orderedIds.isNotEmpty) {
      await ApiService.reorderList(listId, orderedIds);
    }

    if (mounted) {
      setState(() {
        isLoading = false;
        isEditing = false;
      });
      if (failed.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${failed.length} film silinemedi. Lütfen tekrar deneyin.'),
          ),
        );
      }
    }
  }

  /// Edit moddan çıkarken pending'i sıfırla (iptal)
  void _cancelEdit() {
    setState(() {
      _pendingRemovals.clear();
      isEditing = false;
    });
  }

  Future<void> _showAddMovieSheet() async {
    final searchController = TextEditingController();
    List<Movie> searchResults = [];
    Timer? debounce;
    int searchRequestId = 0;
    bool isSearching = false;

    Future<void> runSearch(
        String query, void Function(void Function()) setSheetState) async {
      final q = query.trim();
      searchRequestId++;
      final requestId = searchRequestId;

      if (q.length < 2) {
        if (!mounted) return;
        setSheetState(() {
          searchResults = [];
          isSearching = false;
        });
        return;
      }

      if (!mounted) return;
      setSheetState(() => isSearching = true);
      final results = await ApiService.searchMovies(q);

      if (requestId != searchRequestId) return;
      if (!mounted) return;

      setSheetState(() {
        searchResults = results.take(5).toList();
        isSearching = false;
      });
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.85,
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
                          'Koleksiyona Film Ekle',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
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
                        Expanded(
                          child: Container(
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
                                          'Film eklemek için arama yapın.',
                                          style:
                                              TextStyle(color: Colors.white38),
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: searchResults.length,
                                        itemBuilder: (context, index) {
                                          final movie = searchResults[index];
                                          final alreadyExists = items.any(
                                              (item) =>
                                                  item['tmdbId'] == movie.id);

                                          return ListTile(
                                            leading: movie
                                                    .posterUrlW200.isNotEmpty
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          movie.posterUrlW200,
                                                      width: 38,
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (context, url) =>
                                                              Container(
                                                        width: 38,
                                                        color: const Color(
                                                            0xFF2A2A2A),
                                                        child: const Icon(
                                                            Icons.movie,
                                                            color:
                                                                Colors.white30,
                                                            size: 20),
                                                      ),
                                                      errorWidget: (context,
                                                              url, error) =>
                                                          Container(
                                                        width: 38,
                                                        color: const Color(
                                                            0xFF2A2A2A),
                                                        child: const Icon(
                                                            Icons.error,
                                                            color: Colors
                                                                .redAccent,
                                                            size: 20),
                                                      ),
                                                    ),
                                                  )
                                                : const Icon(Icons.movie,
                                                    color: Colors.white54),
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
                                                alreadyExists
                                                    ? Icons.check_circle
                                                    : Icons.add_circle_outline,
                                                color: alreadyExists
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                              ),
                                              onPressed: alreadyExists
                                                  ? null
                                                  : () async {
                                                      final scaffoldMessenger =
                                                          ScaffoldMessenger.of(
                                                              context);

                                                      if (!mounted) return;
                                                      setSheetState(() =>
                                                          isSearching = true);
                                                      final res =
                                                          await ApiService
                                                              .addMovieToList(
                                                        listId: listId,
                                                        tmdbId: movie.id,
                                                        movieName: movie.title,
                                                        posterUrl:
                                                            movie.posterPath ??
                                                                '',
                                                      );

                                                      if (res != null &&
                                                          res['error'] ==
                                                              null) {
                                                        setState(() {
                                                          items.add({
                                                            'tmdbId': movie.id,
                                                            'movieName':
                                                                movie.title,
                                                            'posterUrl': movie
                                                                    .posterPath ??
                                                                '',
                                                          });
                                                        });
                                                        if (mounted) {
                                                          setSheetState(() =>
                                                              isSearching =
                                                                  false);
                                                        }

                                                        if (mounted) {
                                                          scaffoldMessenger
                                                              .showSnackBar(
                                                            SnackBar(
                                                                content: Text(
                                                                    '${movie.title} eklendi!')),
                                                          );
                                                        }
                                                      } else {
                                                        setSheetState(() =>
                                                            isSearching =
                                                                false);
                                                        if (mounted) {
                                                          scaffoldMessenger
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text((res?[
                                                                          'error'] ??
                                                                      'Film eklenemedi')
                                                                  .toString()),
                                                            ),
                                                          );
                                                        }
                                                      }
                                                    },
                                            ),
                                          );
                                        },
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
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: listName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title:
            const Text('İsmi Değiştir', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Yeni liste adı',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child:
                const Text('Kaydet', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == listName) return;

    setState(() => isLoading = true);
    final result = await ApiService.renameList(listId, newName);

    if (!mounted) return;
    if (result != null && result['error'] == null) {
      setState(() {
        listName = newName;
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste adı güncellendi!')),
      );
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text((result?['error'] ?? 'İsim güncellenemedi').toString())),
      );
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Listeyi Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '"$listName" listesi ve içindeki tüm filmler kalıcı olarak silinecek. Devam etmek istiyor musun?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);
    final success = await ApiService.deleteList(listId);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Liste silindi!')),
      );
      Navigator.pop(context); // Geri dön
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Liste silinemedi. Lütfen tekrar deneyin.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          listName,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (widget.isMe && !isEditing)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: _showAddMovieSheet,
            ),
          if (widget.isMe && isEditing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // İptal — pending silmeleri geri al
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: _cancelEdit,
                ),
                // Onayla — backend'e gönder
                IconButton(
                  icon: Badge(
                    isLabelVisible: _pendingRemovals.isNotEmpty,
                    label: Text('${_pendingRemovals.length}',
                        style: const TextStyle(fontSize: 10)),
                    child: const Icon(Icons.check, color: Colors.greenAccent),
                  ),
                  onPressed: isLoading ? null : _commitRemovals,
                ),
              ],
            ),
          if (widget.isMe && !isEditing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: const Color(0xFF1E1E1E),
              offset: const Offset(0, 48),
              constraints: const BoxConstraints(minWidth: 140, maxWidth: 140),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _showRenameDialog();
                    break;
                  case 'edit':
                    setState(() => isEditing = true);
                    break;
                  case 'delete':
                    _deleteList();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 10),
                      Text('İsmi Değiştir',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline,
                          color: Colors.white70, size: 16),
                      SizedBox(width: 10),
                      Text('Filmleri Düzenle',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 16),
                      SizedBox(width: 10),
                      Text('Listeyi Sil',
                          style:
                              TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : items.isEmpty
              ? const Center(
                  child: Text(
                    'Bu liste henüz boş.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isEditing
                      ? ReorderableGridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: items.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              final moved = items.removeAt(oldIndex);
                              items.insert(newIndex, moved);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final tmdbId = item['tmdbId'];
                            final posterUrl =
                                item['posterUrl']?.toString() ?? '';
                            final imageUrl = posterUrl.isNotEmpty
                                ? (posterUrl.startsWith('http')
                                    ? posterUrl
                                    : 'https://image.tmdb.org/t/p/w500$posterUrl')
                                : '';
                            final isPending = _pendingRemovals.contains(tmdbId);

                            return Stack(
                              key: ValueKey(tmdbId ?? index),
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Opacity(
                                    opacity: isPending ? 0.35 : 1.0,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          border: Border.all(
                                              color: isPending
                                                  ? Colors.redAccent
                                                  : Colors.white10,
                                              width: isPending ? 2 : 1),
                                          image: imageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image:
                                                      CachedNetworkImageProvider(
                                                          imageUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imageUrl.isEmpty
                                            ? const Center(
                                                child: Icon(Icons.movie,
                                                    color: Colors.white24,
                                                    size: 24))
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: GestureDetector(
                                    onTap: () {
                                      if (tmdbId != null) {
                                        _markForRemoval(tmdbId);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isPending
                                            ? Colors.redAccent
                                            : Colors.black,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.redAccent,
                                            width: 1.5),
                                      ),
                                      child: Icon(
                                        isPending ? Icons.check : Icons.close,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final posterUrl =
                                item['posterUrl']?.toString() ?? '';
                            final imageUrl = posterUrl.isNotEmpty
                                ? (posterUrl.startsWith('http')
                                    ? posterUrl
                                    : 'https://image.tmdb.org/t/p/w500$posterUrl')
                                : '';

                            return GestureDetector(
                              key: ValueKey(item['tmdbId'] ?? index),
                              onTap: () {
                                final tmdbId = item['tmdbId'];
                                if (tmdbId != null) {
                                  final dummyMovie = Movie(
                                    id: tmdbId,
                                    title: item['movieName'] ?? '',
                                    overview: '',
                                    releaseDate: '',
                                    voteAverage: 0.0,
                                    voteCount: 0,
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MovieDetailScreen(movie: dummyMovie),
                                    ),
                                  );
                                }
                              },
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          border:
                                              Border.all(color: Colors.white10),
                                          image: imageUrl.isNotEmpty
                                              ? DecorationImage(
                                                  image:
                                                      CachedNetworkImageProvider(
                                                          imageUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imageUrl.isEmpty
                                            ? const Center(
                                                child: Icon(Icons.movie,
                                                    color: Colors.white24,
                                                    size: 24))
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
