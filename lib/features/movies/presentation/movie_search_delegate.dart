import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/movie_model.dart';
import '../data/movie_repository.dart';
import 'movie_detail_screen.dart';

class MovieSearchDelegate extends SearchDelegate {
  final MovieRepository repository;
  MovieSearchDelegate(this.repository);

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
    if (query.isEmpty) return const Center(child: Text('Search for movies...'));

    return FutureBuilder<List<Movie>>(
      future: repository.searchMovies(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final results = snapshot.data ?? [];
        if (results.isEmpty) return const Center(child: Text('No movies found.'));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final movie = results[index];
            return ListTile(
              leading: CachedNetworkImage(
                imageUrl: movie.fullPosterPath,
                width: 50,
                errorWidget: (context, url, err) => const Icon(Icons.error),
              ),
              title: Text(movie.title),
              subtitle: Text(movie.releaseDate ?? ''),
              onTap: () {
                close(context, null);
                Navigator.push(context, MaterialPageRoute(builder: (context) => MovieDetailScreen(movieId: movie.id)));
              },
            );
          },
        );
      },
    );
  }
}
