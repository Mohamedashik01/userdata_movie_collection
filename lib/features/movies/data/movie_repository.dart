import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/database.dart';
import 'movie_model.dart';
import 'dart:developer';

class MovieRepository {
  final Dio _dio;
  final AppDatabase _db;
  final String _apiKey = '50d230287cbecb85f914864dcbfc30bf'; // User-provided TMDB key


  MovieRepository(this._dio, this._db);

  // Paginated movie fetch (trending)
  Future<List<Movie>> fetchTrendingMovies(int page) async {
    final response = await _dio.get(
      'https://api.themoviedb.org/3/trending/movie/day',
      queryParameters: {
        'api_key': _apiKey,
        'language': 'en-US',
        'page': page,
      },
    );
    
    final data = response.data['results'] as List;
    return data.map((json) => Movie.fromJson(json)).toList();
  }

  // Search movies by query
  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    
    final response = await _dio.get(
      'https://api.themoviedb.org/3/search/movie',
      queryParameters: {
        'api_key': _apiKey,
        'query': query,
        'language': 'en-US',
      },
    );
    
    final data = response.data['results'] as List;
    return data.map((json) => Movie.fromJson(json)).toList();
  }

  // Movie Details
  Future<Movie> fetchMovieDetails(int movieId) async {
    final response = await _dio.get(
      'https://api.themoviedb.org/3/movie/$movieId',
      queryParameters: {'api_key': _apiKey},
    );
    return Movie.fromJson(response.data);
  }

  // Bookmark Functionality (Toggle: Add if not exists, Remove if exists)
  Future<void> bookmarkMovie({required int movieId, required int internalUserId}) async {
    // Check if already bookmarked
    final existing = await (_db.select(_db.bookmarks)
      ..where((t) => t.movieId.equals(movieId))
      ..where((t) => t.userId.equals(internalUserId))).getSingleOrNull();

    if (existing == null) {
      log('Adding bookmark for movie $movieId, user $internalUserId');
      await _db.insertBookmark(BookmarksCompanion(
        movieId: Value(movieId),
        userId: Value(internalUserId),
        isSynced: const Value(false),
      ));
    } else {
      log('Removing bookmark for movie $movieId, user $internalUserId');
      await _db.deleteBookmark(movieId, internalUserId);
    }
  }

  // Get Bookmarked IDs for current user (to show bookmark icon state)
  Future<List<int>> getBookmarkedMovieIds(int internalUserId) async {
    final list = await _db.getBookmarksForUser(internalUserId);
    return list.map((e) => e.movieId).toList();
  }
}

final movieRepositoryProvider = Provider<MovieRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  return MovieRepository(dio, db);
});
