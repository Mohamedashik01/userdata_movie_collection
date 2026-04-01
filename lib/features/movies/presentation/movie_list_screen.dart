import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/movie_model.dart';
import '../data/movie_repository.dart';
import 'movie_detail_screen.dart';
import 'movie_search_delegate.dart';
import 'providers/selected_user_provider.dart';
import '../../../core/network/network_status.dart';

class MovieListScreen extends ConsumerStatefulWidget {
  const MovieListScreen({super.key});

  @override
  ConsumerState<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends ConsumerState<MovieListScreen> {
  static const _pageSize = 20;
  final PagingController<int, Movie> _pagingController = PagingController(firstPageKey: 1);
  List<int> _bookmarkedIds = [];

  @override
  void initState() {
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _loadBookmarks();
    super.initState();
  }

  Future<void> _loadBookmarks() async {
    final userId = ref.read(selectedUserProvider);
    if (userId != null) {
      final ids = await ref.read(movieRepositoryProvider).getBookmarkedMovieIds(userId);
      if (mounted) setState(() => _bookmarkedIds = ids);
    }
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await ref.read(movieRepositoryProvider).fetchTrendingMovies(pageKey);
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedUserProvider);
    final networkStatus = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: MovieSearchDelegate(ref.read(movieRepositoryProvider)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Column(
            children: [
              if (selectedId != null)
                Text('Bookmarking for User ID: $selectedId',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (networkStatus == NetworkStatus.connecting)
                const Text('Reconnecting...',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: PagedListView<int, Movie>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Movie>(
          itemBuilder: (context, movie, index) => ListTile(
            leading: CachedNetworkImage(
              imageUrl: movie.fullPosterPath,
              placeholder: (context, url) => const SizedBox(width: 50, height: 75, child: Center(child: CircularProgressIndicator())),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              width: 50,
            ),
            title: Text(movie.title),
            subtitle: Text(movie.releaseDate ?? 'No Release Date'),
            trailing: IconButton(
              icon: Icon(
                _bookmarkedIds.contains(movie.id) ? Icons.bookmark : Icons.bookmark_border,
                color: _bookmarkedIds.contains(movie.id) ? Colors.blue : null,
              ),
              onPressed: () async {
                if (selectedId != null) {
                  await ref.read(movieRepositoryProvider).bookmarkMovie(
                        movieId: movie.id,
                        internalUserId: selectedId,
                      );
                  await _loadBookmarks();
                  if (context.mounted) {
                    final isNowBookmarked = _bookmarkedIds.contains(movie.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isNowBookmarked ? 'Movie bookmarked locally!' : 'Bookmark removed')),
                    );
                  }
                }
              },
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => MovieDetailScreen(movieId: movie.id)),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}
