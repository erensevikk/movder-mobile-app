import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/movie.dart';
import '../../../movies/presentation/views/movie_detail_screen.dart';
import '../../../profile/data/models/movie_list_model.dart';
import '../view_models/list_detail_view_model.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({
    super.key,
    required this.list,
    required this.isMe,
  });

  final MovieListModel list;
  final bool isMe;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen>
    with
        ViewModelBindingMixin<ListDetailScreen, ListDetailViewModel>,
        ViewEffectListenerMixin<ListDetailScreen, ListDetailViewModel> {
  @override
  ListDetailViewModel createViewModel() => ListDetailViewModel(
        list: widget.list,
        isMe: widget.isMe,
      );

  @override
  Widget buildWithViewModel(BuildContext context, ListDetailViewModel vm) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(vm.listName),
        backgroundColor: AppColors.surface,
        actions: <Widget>[
          if (widget.isMe && !vm.isEditing)
            IconButton(
              onPressed: _showAddMovieSheet,
              icon: const Icon(Icons.add),
            ),
          if (widget.isMe)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') vm.toggleEdit();
                if (value == 'rename') _showRenameDialog(vm);
                if (value == 'delete') _confirmDelete(vm);
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'rename', child: Text('İsmi Değiştir')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
        ],
      ),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : vm.items.isEmpty
              ? const Center(
                  child: Text(
                    'Bu liste henuz bos.',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: vm.isEditing
                      ? Column(
                          children: <Widget>[
                            Expanded(
                              child: ReorderableGridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  childAspectRatio: 2 / 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: vm.items.length,
                                onReorder: vm.reorder,
                                itemBuilder: (context, index) {
                                  final item = vm.items[index];
                                  final pending =
                                      vm.pendingRemovals.contains(item.tmdbId);
                                  return Stack(
                                    key: ValueKey<int>(item.tmdbId),
                                    children: <Widget>[
                                      _PosterCard(item.posterUrl),
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: GestureDetector(
                                          onTap: () => vm.markForRemoval(
                                            item.tmdbId,
                                          ),
                                          child: CircleAvatar(
                                            radius: 12,
                                            backgroundColor: pending
                                                ? AppColors.success
                                                : AppColors.error,
                                            child: Icon(
                                              pending
                                                  ? Icons.undo
                                                  : Icons.close,
                                              size: 14,
                                              color: AppColors.background,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: vm.commitChanges,
                                child: Text(
                                  'Kaydet (${vm.pendingRemovals.length})',
                                ),
                              ),
                            ),
                          ],
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2 / 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: vm.items.length,
                          itemBuilder: (context, index) {
                            final item = vm.items[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MovieDetailScreen(
                                    movie: Movie(
                                      id: item.tmdbId,
                                      title: item.movieName,
                                      overview: '',
                                      voteAverage: 0,
                                      releaseDate: '',
                                      voteCount: 0,
                                      posterPath:
                                          item.posterUrl.startsWith('http')
                                              ? item.posterUrl.replaceFirst(
                                                  'https://image.tmdb.org/t/p/w500',
                                                  '',
                                                )
                                              : item.posterUrl,
                                    ),
                                  ),
                                ),
                              ),
                              child: _PosterCard(item.posterUrl),
                            );
                          },
                        ),
                ),
    );
  }

  Future<void> _showRenameDialog(ListDetailViewModel vm) async {
    final controller = TextEditingController(text: vm.listName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste Adi'),
        content: TextField(controller: controller),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await vm.rename(result);
    }
  }

  Future<void> _confirmDelete(ListDetailViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listeyi Sil'),
        content: Text('"${vm.listName}" silinsin mi?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.delete();
    }
  }

  Future<void> _showAddMovieSheet() async {
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: 500,
            child: Column(
              children: <Widget>[
                TextField(
                  controller: searchController,
                  onChanged: viewModel.onSearchChanged,
                  style: const TextStyle(color: AppColors.textHigh),
                  decoration: const InputDecoration(
                    hintText: 'Film ara',
                    hintStyle: TextStyle(color: AppColors.textMedium),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: viewModel.isSearching
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : ListView.builder(
                          itemCount: viewModel.searchResults.length,
                          itemBuilder: (context, index) {
                            final movie = viewModel.searchResults[index];
                            return ListTile(
                              title: Text(
                                movie.title,
                                style:
                                    const TextStyle(color: AppColors.textHigh),
                              ),
                              subtitle: Text(
                                movie.releaseYear,
                                style: const TextStyle(
                                    color: AppColors.textMedium),
                              ),
                              onTap: () async {
                                await viewModel.addMovie(movie);
                                if (context.mounted) Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard(this.posterUrl);

  final String posterUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = posterUrl.isNotEmpty && !posterUrl.startsWith('http')
        ? 'https://image.tmdb.org/t/p/w500$posterUrl'
        : posterUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: imageUrl.isEmpty
          ? Container(
              color: AppColors.surface,
              child: const Icon(Icons.movie, color: AppColors.textMedium),
            )
          : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
    );
  }
}
