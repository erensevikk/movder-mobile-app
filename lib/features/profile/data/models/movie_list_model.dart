import 'movie_list_item_model.dart';

class MovieListModel {
  const MovieListModel({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });

  factory MovieListModel.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map>()
        .map((item) => MovieListItemModel.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    return MovieListModel(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      items: rawItems,
    );
  }

  final String id;
  final String name;
  final String description;
  final List<MovieListItemModel> items;
}
