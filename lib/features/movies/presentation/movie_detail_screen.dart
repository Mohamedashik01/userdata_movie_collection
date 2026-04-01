import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/movie_model.dart';
import '../data/movie_repository.dart';
import 'providers/selected_user_provider.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  final int movieId;
  const MovieDetailScreen({super.key, required this.movieId});

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  late Future<Movie> _movieFuture;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _movieFuture = ref.read(movieRepositoryProvider).fetchMovieDetails(widget.movieId);
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final userId = ref.read(selectedUserProvider);
    if (userId != null) {
      final ids = await ref.read(movieRepositoryProvider).getBookmarkedMovieIds(userId);
      if (mounted) setState(() => _isBookmarked = ids.contains(widget.movieId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedUserId = ref.watch(selectedUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movie Detail'),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.blue : null),
            onPressed: () async {
              if (selectedUserId != null) {
                await ref.read(movieRepositoryProvider).bookmarkMovie(
                      movieId: widget.movieId,
                      internalUserId: selectedUserId,
                    );
                  await _checkBookmark();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isBookmarked ? 'Bookmark added' : 'Bookmark removed')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<Movie>(
        future: _movieFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No details found.'));
          }

          final movie = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CachedNetworkImage(
                  imageUrl: movie.fullPosterPath,
                  height: 350,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const Icon(Icons.error, size: 100),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(movie.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Release Date: ${movie.releaseDate}', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      Text('Overview', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(movie.overview ?? 'No overview available.', style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
