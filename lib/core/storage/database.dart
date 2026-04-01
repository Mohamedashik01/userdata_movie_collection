import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class LocalUsers extends Table {
  IntColumn get id => integer().autoIncrement()(); // SQLite ID/Local identifier
  IntColumn get remoteId => integer().nullable().unique()(); // ID from ReqRes API
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get avatar => text()();
  TextColumn get job => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();
}

class LocalMovies extends Table {
  IntColumn get id => integer()(); // TMDB ID
  TextColumn get title => text()();
  TextColumn get posterPath => text()();
  TextColumn get releaseDate => text()();
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get movieId => integer()();
  IntColumn get userId => integer()(); // References LocalUsers.id (internal ID)
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [LocalUsers, LocalMovies, Bookmarks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ==========================================
  // USER OPERATIONS
  // ==========================================

  /// Retrieves all users stored locally. 
  /// Used for offline display and when merging with remote data.
  Future<List<LocalUser>> getAllUsers() {
    return (select(localUsers)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  Future<LocalUser?> fetchUserByRemoteId(int remoteId) {
    return (select(localUsers)..where((t) => t.remoteId.equals(remoteId))).getSingleOrNull();
  }

  /// Filters local users by first or last name using a LIKE query.
  Future<List<LocalUser>> searchLocalUsers(String query) {
    return (select(localUsers)
      ..where((t) => t.firstName.like('%$query%') | t.lastName.like('%$query%'))
      ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }
  
  /// Inserts a new user into the local database. 
  /// Returns the internal SQLite auto-generated ID.
  Future<int> insertUser(LocalUsersCompanion user) => into(localUsers).insert(user);
  
  /// Updates a local user's sync status and attaches the remote ID provided by the API.
  Future updateUserSyncStatus(int localId, int remoteId) {
    return (update(localUsers)..where((t) => t.id.equals(localId))).write(
      LocalUsersCompanion(
        remoteId: Value(remoteId),
        isSynced: const Value(true),
      ),
    );
  }

  // ==========================================
  // BOOKMARK OPERATIONS
  // ==========================================

  /// Fetches all bookmarks associated with a specific local user.
  Future<List<Bookmark>> getBookmarksForUser(int userId) {
    return (select(bookmarks)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// Persists a new movie bookmark locally.
  Future<int> insertBookmark(BookmarksCompanion bookmark) => into(bookmarks).insert(bookmark);

  /// Removes a bookmark for a specific movie/user pair.
  Future<int> deleteBookmark(int movieId, int userId) {
    return (delete(bookmarks)
      ..where((t) => t.movieId.equals(movieId))
      ..where((t) => t.userId.equals(userId))).go();
  }

  /// Marks a bookmark as successfully synchronized to the remote server.
  Future updateBookmarkSyncStatus(int id) {
    return (update(bookmarks)..where((t) => t.id.equals(id))).write(
      const BookmarksCompanion(isSynced: Value(true)),
    );
  }

  // ==========================================
  // SYNCHRONIZATION HELPERS
  // ==========================================

  /// Finds all users created while offline that have not yet been sent to the API.
  Future<List<LocalUser>> getUnsyncedUsers() {
    return (select(localUsers)
      ..where((t) => t.isSynced.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

  /// Finds all bookmarks created while offline that have not yet been sent to the API.
  Future<List<Bookmark>> getUnsyncedBookmarks() {
    return (select(bookmarks)
      ..where((t) => t.isSynced.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  }

}


LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
