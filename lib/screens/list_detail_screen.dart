import 'package:flutter/material.dart';

import '../features/lists/presentation/views/list_detail_screen.dart' as feature;
import '../features/profile/data/models/movie_list_model.dart';

class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({
    super.key,
    required this.listData,
    required this.isMe,
  });

  final Map<String, dynamic> listData;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return feature.ListDetailScreen(
      list: MovieListModel.fromMap(listData),
      isMe: isMe,
    );
  }
}
