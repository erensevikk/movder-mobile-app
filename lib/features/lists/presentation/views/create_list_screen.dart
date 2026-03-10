import 'package:flutter/material.dart';

import '../../../../core/mixins/view_effect_listener_mixin.dart';
import '../../../../core/mixins/view_model_binding_mixin.dart';
import '../view_models/create_list_view_model.dart';

class CreateListScreen extends StatefulWidget {
  const CreateListScreen({super.key});

  @override
  State<CreateListScreen> createState() => _CreateListScreenState();
}

class _CreateListScreenState extends State<CreateListScreen>
    with
        ViewModelBindingMixin<CreateListScreen, CreateListViewModel>,
        ViewEffectListenerMixin<CreateListScreen, CreateListViewModel> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  CreateListViewModel createViewModel() => CreateListViewModel();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget buildWithViewModel(BuildContext context, CreateListViewModel vm) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Yeni Liste'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _titleController,
              onChanged: vm.updateTitle,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Liste Adi',
                labelStyle: const TextStyle(color: Colors.white54),
                errorText: vm.titleError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              onChanged: vm.updateDescription,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Aciklama',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: vm.onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Film Ara',
                labelStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            if (vm.selectedMovies.isNotEmpty)
              Wrap(
                spacing: 8,
                children: vm.selectedMovies
                    .map(
                      (movie) => Chip(
                        label: Text(movie.title),
                        onDeleted: () => vm.toggleMovie(movie),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: vm.isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    )
                  : ListView.builder(
                      itemCount: vm.searchResults.length,
                      itemBuilder: (context, index) {
                        final movie = vm.searchResults[index];
                        final selected = vm.selectedMovies.any(
                          (item) => item.id == movie.id,
                        );
                        return ListTile(
                          title: Text(
                            movie.title,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            movie.releaseYear,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: IconButton(
                            onPressed: () => vm.toggleMovie(movie),
                            icon: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: selected
                                  ? Colors.greenAccent
                                  : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isLoading ? null : vm.createList,
                child: vm.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Listeyi Olustur (${vm.selectedMovies.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
