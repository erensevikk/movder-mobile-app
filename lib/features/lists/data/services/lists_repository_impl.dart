import '../../../../core/base/app_failure.dart';
import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';
import '../../../../services/api_service.dart';
import '../../../profile/data/models/movie_list_item_model.dart';
import '../../../profile/data/models/movie_list_model.dart';
import '../repositories/lists_repository.dart';

class ListsRepositoryImpl implements ListsRepository {
  @override
  Future<bool> addMovieToList({
    required String listId,
    required Movie movie,
  }) async {
    final result = await ApiService.addMovieToList(
      listId: listId,
      tmdbId: movie.id,
      movieName: movie.title,
      posterUrl: movie.posterUrl,
    );
    return result != null && result['error'] == null;
  }

  @override
  Future<Result<MovieListModel>> createList({
    required String name,
    required String description,
    bool isPublic = true,
  }) async {
    final result = await ApiService.createList(
      name: name,
      description: description,
      isPublic: isPublic,
    );
    if (result == null || result['error'] != null) {
      return const Result.failure(
        AppFailure(message: 'Liste oluşturulamadı.'),
      );
    }

    final listId = _extractListId(result['listId']);
    if (listId == null) {
      return const Result.failure(
        AppFailure(message: 'Liste ID alınamadı.'),
      );
    }

    return Result.success(MovieListModel(
      id: listId,
      name: name,
      description: description,
      items: const <MovieListItemModel>[],
    ));
  }

  @override
  Future<bool> deleteList(String listId) {
    return ApiService.deleteList(listId);
  }

  @override
  Future<List<MovieListModel>> getMyLists() async {
    final lists = await ApiService.getMyLists();
    return _enrichLists(lists);
  }

  @override
  Future<List<MovieListModel>> getUserLists(String userId) async {
    final lists = await ApiService.getUserLists(userId);
    return _enrichLists(lists);
  }

  @override
  Future<MovieListModel?> renameList(String listId, String newName) async {
    final result = await ApiService.renameList(listId, newName);
    if (result == null || result['error'] != null) return null;

    final items = await ApiService.getListItems(listId);
    return MovieListModel.fromMap(
      <String, dynamic>{
        'id': listId,
        'name': newName,
        'description': (result['description'] ?? '').toString(),
        'items': items,
      },
    );
  }

  @override
  Future<bool> removeMovieFromList(String listId, int tmdbId) {
    return ApiService.removeMovieFromList(listId, tmdbId);
  }

  @override
  Future<bool> reorderList(String listId, List<int> tmdbIds) {
    return ApiService.reorderList(listId, tmdbIds);
  }

  Future<List<MovieListModel>> _enrichLists(
    List<Map<String, dynamic>> rawLists,
  ) async {
    final results = await Future.wait<Map<String, dynamic>>(
      rawLists.map((list) async {
        final id = (list['id'] ?? list['_id'] ?? '').toString();
        final items = id.isEmpty
            ? <Map<String, dynamic>>[]
            : await ApiService.getListItems(id);
        return <String, dynamic>{
          ...list,
          'items': items,
        };
      }),
    );

    return results.map(MovieListModel.fromMap).toList();
  }

  String? _extractListId(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final oid = value[r'$oid']?.toString();
      if (oid != null && oid.isNotEmpty) return oid;
    }
    return null;
  }
}
