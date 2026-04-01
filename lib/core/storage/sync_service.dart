import 'package:dio/dio.dart';
import 'database.dart';
import 'dart:developer' as dev;

/// Orchestrates the background synchronization process between the local 
/// database and the remote ReqRes API. 
/// 
/// This service is designed to be called periodically (e.g. via WorkManager) 
/// to ensure data consistency when the device regains connectivity.
class SyncService {
  final AppDatabase db;
  final Dio dio;

  final String _apiKey = 'reqres_6702507bb265440aa046132c5bbd64d4';
  final String _usersUrl = 'https://reqres.in/api/users';

  SyncService(this.db, this.dio);

  /// Main entry point for the synchronization process.
  /// 
  /// Important: We process Users before Bookmarks to ensure that any newly 
  /// created local users have a valid remote ID before we attempt to sync 
  /// their associated bookmarks.
  Future<void> syncData() async {
    dev.log('SYNC: Starting background data synchronization...', name: 'SyncService');

    try {
      // 1. Sync any users created while offline
      await _syncUnsyncedUsers();

      // 2. Sync bookmarks attached to those users
      await _syncUnsyncedBookmarks();

      dev.log('SYNC: Synchronization cycle completed.', name: 'SyncService');
    } catch (e) {
      dev.log('SYNC ERR: Unexpected synchronization error: $e', name: 'SyncService', error: e);
    }
  }

  /// Iterates through unsynced local users and posts them to ReqRes.
  Future<void> _syncUnsyncedUsers() async {
    final unsyncedUsers = await db.getUnsyncedUsers();
    
    if (unsyncedUsers.isEmpty) return;

    for (var user in unsyncedUsers) {
      try {
        dev.log('SYNC: Syncing user "${user.firstName} ${user.lastName}" (ID: ${user.id})...', name: 'SyncService');
        
        final response = await dio.post(
          _usersUrl,
          queryParameters: {'api_key': _apiKey},
          data: {
            'name': '${user.firstName} ${user.lastName}',
            'job': user.job ?? 'Developer',
          },
        );

        if (response.statusCode == 201) {
          final remoteId = int.tryParse(response.data['id'].toString()) ?? 0;
          
          await db.updateUserSyncStatus(user.id, remoteId);
          dev.log('SYNC SUCCESS: User synced. Remote ID assigned: $remoteId', name: 'SyncService');
        } else {
          dev.log('SYNC WARNING: Post returned status ${response.statusCode} for user ${user.id}', name: 'SyncService');
        }
      } on DioException catch (e) {
        dev.log('SYNC ERR: Network error syncing user ${user.id}: ${e.message}', name: 'SyncService');
      } catch (e) {
        dev.log('SYNC ERR: General error syncing user ${user.id}: $e', name: 'SyncService');
      }
    }
  }

  /// Iterates through unsynced bookmarks. 
  /// 
  /// Note: A bookmark is only eligible for sync if its associated user 
  /// has already been successfully synced to the remote server.
  Future<void> _syncUnsyncedBookmarks() async {
    final unsyncedBookmarks = await db.getUnsyncedBookmarks();
    
    if (unsyncedBookmarks.isEmpty) return;

    for (var bookmark in unsyncedBookmarks) {
      try {
        // Look up the local user to check their sync status
        final userQuery = db.select(db.localUsers)..where((u) => u.id.equals(bookmark.userId));
        final linkedUser = await userQuery.getSingleOrNull();
        
        if (linkedUser == null) {
          dev.log('SYNC ERR: Linked user not found for bookmark (ID: ${bookmark.id})', name: 'SyncService');
          continue;
        }

        if (linkedUser.isSynced && linkedUser.remoteId != null) {
          dev.log('SYNC: Syncing bookmark for movie ${bookmark.movieId} liked by user ${linkedUser.remoteId}', name: 'SyncService');
          
          // Simulated POST for movie bookmark (ReqRes has no specific bookmark endpoint)
          // In a real environment, we would post to e.g. /api/users/{remoteId}/bookmarks
          
          // Mimic a successful remote operation:
          await Future.delayed(const Duration(milliseconds: 300)); 
          await db.updateBookmarkSyncStatus(bookmark.id);
          
          dev.log('SYNC SUCCESS: Bookmark synced for movieId: ${bookmark.movieId}', name: 'SyncService');
        } else {
          dev.log('SYNC SKIP: User ${linkedUser.id} not synced yet. Waiting for next cycle.', name: 'SyncService');
        }
      } catch (e) {
        dev.log('SYNC ERR: Failed to sync bookmark ${bookmark.id}: $e', name: 'SyncService');
      }
    }
  }
}

