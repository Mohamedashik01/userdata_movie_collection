import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/database.dart';
import 'user_model.dart';
import 'dart:developer' as dev;

/// Abstract interface for User related operations.
/// 
/// Decoupling the interface from the implementation allows for easier testing
/// and flexibility should we decide to change the data source in the future.
abstract class IUserRepository {
  /// Fetches a paginated list of users from the remote API,
  /// seamlessly merging them with locally created users.
  Future<List<User>> getPaginatedUsers(int page);

  /// Orchestrates the 'Offline-First' creation of a user.
  /// 
  /// Attempts an immediate API post if online, otherwise stores locally
  /// and marks for background synchronization.
  Future<void> createUser({required String name, required String job});

  /// Retrieves all users stored in the local SQLite database.
  Future<List<LocalUser>> getStoredUsers();

  /// Searches local users by first or last name.
  Future<List<LocalUser>> searchLocalUsers(String query);
}

/// A repository implementation that handles data orchestration between
/// the ReqRes remote API and a local Drift SQLite database.
class UserRepository implements IUserRepository {
  final Dio _dio;
  final AppDatabase _db;

  // The ReqRes API doesn't strictly require an API key for public GETs, 
  // but using one for identification and to simulate production requirements.
  final String _apiKey = 'reqres_6702507bb265440aa046132c5bbd64d4';
  final String _baseUrl = 'https://reqres.in/api/users';

  UserRepository(this._dio, this._db);

  @override
  Future<List<User>> getPaginatedUsers(int page) async {
    dev.log('REPOS: Fetching page $page users...', name: 'UserRepository');
    List<User> remoteUsers = [];

    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'page': page,
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        remoteUsers = data.map((json) => User.fromJson(json)).toList();
      }
    } catch (e) {
      dev.log('REPOS WARNING: Remote fetch failed, likely offline. $e', name: 'UserRepository');
      // On the first page, we don't throw; we fallback to local data.
      // For subsequent pages, we rethrow so the paging controller can show an error state.
      if (page != 1) rethrow; 
    }

    // Merge logic: Combine remote results with users created locally but not yet in API.
    // We only perform this merge on the first page to avoid duplication and complexity across pages.
    if (page == 1) {
      final localDbEntries = await _db.getAllUsers();
      
      final localUsers = localDbEntries.map((u) => User(
        id: u.remoteId ?? u.id, 
        firstName: u.firstName,
        lastName: u.lastName,
        avatar: u.avatar,
      )).toList();

      dev.log('REPOS: Found ${localUsers.length} local and ${remoteUsers.length} remote users on Page 1.', name: 'UserRepository');

      // We use a Set to ensure unique IDs, prioritizing local entries (most recent).
      final combined = [...localUsers, ...remoteUsers];
      final seenIds = <int>{};
      final uniqueResults = combined.where((u) => seenIds.add(u.id)).toList();
      
      dev.log('REPOS: Returning ${uniqueResults.length} unique users for Page 1.', name: 'UserRepository');
      return uniqueResults;
    }

    dev.log('REPOS: Returning ${remoteUsers.length} users for Page $page.', name: 'UserRepository');
    return remoteUsers;
  }


  @override
  Future<void> createUser({required String name, required String job}) async {
    final results = await Connectivity().checkConnectivity();
    final bool isOnline;
    if (results is List) {
      isOnline = (results as List).any((element) => element != ConnectivityResult.none);
    } else {
      isOnline = (results as dynamic) != ConnectivityResult.none;
    }

    // Split 'Full Name' into first and last for consistent storage schema
    final parts = name.trim().split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    if (isOnline) {
      try {
        dev.log('REPOS: Posting user to remote API...', name: 'UserRepository');
        final response = await _dio.post(
          _baseUrl,
          queryParameters: {'api_key': _apiKey},
          data: {'name': name, 'job': job},
        );

        if (response.statusCode == 201) {
          final remoteId = int.tryParse(response.data['id'].toString()) ?? 0;
          
          // Even when online, we cache locally for offline access (Single Source of Truth)
          await _saveToDatabase(firstName, lastName, job, remoteId: remoteId, synced: true);
          dev.log('REPOS: User successfuly synced. Remote ID: $remoteId', name: 'UserRepository');
          return;
        }
      } catch (e) {
        dev.log('REPOS ERR: Remote creation failed. Falling back to offline save.', name: 'UserRepository');
      }
    }

    // Offline or Failure Fallback
    dev.log('REPOS: Saving user locally for later sync...', name: 'UserRepository');
    await _saveToDatabase(firstName, lastName, job, synced: false);
  }

  /// Internal helper to DRY the database insertion logic.
  Future<void> _saveToDatabase(
    String first, 
    String last, 
    String job, {
    int? remoteId, 
    bool synced = false
  }) async {
    await _db.insertUser(LocalUsersCompanion(
      firstName: Value(first),
      lastName: Value(last),
      // Mock avatar since ReqRes doesn't generate one for us on POST
      avatar: const Value('https://reqres.in/img/faces/1-image.jpg'), 
      job: Value(job),
      remoteId: remoteId != null ? Value(remoteId) : const Value.absent(),
      isSynced: Value(synced),
    ));
  }
  
  @override
  Future<List<LocalUser>> getStoredUsers() => _db.getAllUsers();

  @override
  Future<List<LocalUser>> searchLocalUsers(String query) => _db.searchLocalUsers(query);
}

/// Provider for the User Repository.
/// Using [IUserRepository] as the type to adhere to Interface Segregation.
final userRepositoryProvider = Provider<IUserRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(databaseProvider);
  return UserRepository(dio, db);
});

