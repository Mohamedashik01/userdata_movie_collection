import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_model.dart';
import '../data/user_repository.dart';
import '../../movies/presentation/movie_list_screen.dart';
import '../../movies/presentation/providers/selected_user_provider.dart';

class UserSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  UserSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) {
    return _search(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _search(context);
  }

  Widget _search(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text('Search for users...'));

    return FutureBuilder<List<User>>(
      future: _getSearchResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const Center(child: Text('No users found.'));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final user = results[index];
            return ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(user.avatar)),
              title: Text('${user.firstName} ${user.lastName}'),
              onTap: () {
                ref.read(selectedUserProvider.notifier).state = user.id;
                close(context, null);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MovieListScreen()));
              },
            );
          },
        );
      },
    );
  }

  Future<List<User>> _getSearchResults() async {
    // Search local database
    final localResults = await ref.read(userRepositoryProvider).searchLocalUsers(query);
    return localResults.map((u) => User(
      id: u.remoteId ?? u.id,
      firstName: u.firstName,
      lastName: u.lastName,
      avatar: u.avatar,
    )).toList();
  }
}
