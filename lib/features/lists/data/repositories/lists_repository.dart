import '../../../../core/base/result.dart';
import '../../../../models/movie.dart';
import '../../../profile/data/models/movie_list_model.dart';

abstract class ListsRepository {
  Future<List<MovieListModel>> getMyLists();

  Future<List<MovieListModel>> getUserLists(String userId);

  Future<Result<MovieListModel>> createList({
    required String name,
    required String description,
    bool isPublic = true,
  });

  Future<bool> addMovieToList({
    required String listId,
    required Movie movie,
  });

  Future<bool> removeMovieFromList(String listId, int tmdbId);

  Future<bool> reorderList(String listId, List<int> tmdbIds);

  Future<MovieListModel?> renameList(String listId, String newName);

  Future<bool> deleteList(String listId);
}
