# Flutter Developer Assignment

This project is a mobile application built with Flutter that features a paginated list of users, offline-first user creation with background sync, movie discovery, and user-linked movie bookmarking.

## Key Features

- **User List:** Fetches and displays a paginated list of users from the ReqRes API.
- **Add User (Offline-First):** Create new users even without an internet connection. Data is stored locally using **Drift (SQLite)** and automatically synced via **WorkManager** when the device is back online.
- **Movie Discovery:** Browse trending movies from **TMDB** with pagination support.
- **Movie Details:** View detailed information about any movie.
- **User-Specific Bookmarks:** Bookmark movies and link them to a specific user profile. Bookmarks created offline are synchronized in the background.
- **Network Resilience:**
  - **30% Random Failure:** A custom network interceptor simulates unstable connections (SocketException/500 errors).
  - **Exponential Backoff:** Requests automatically retry with increasing delays.
  - **UI Feedback:** A non-intrusive "Reconnecting..." indicator appears in the app bar during retries.

## Technical Stack

- **State Management:** Flutter Riverpod
- **Architecture:** Clean/Feature-based Architecture
- **Networking:** Dio with custom interceptors
- **Local Storage:** Drift (SQLite)
- **Background Tasks:** WorkManager for automatic data synchronization
- **Image Loading:** CachedNetworkImage

## Setup Instructions

### 1. TMDB API Key
This project requires a TMDB API Key to fetch movie data.
- Open `lib/features/movies/data/movie_repository.dart`.
- Replace the placeholder `_apiKey` with your actual TMDB key.

### 2. Manual Native Setup (Important)

#### Android
The **WorkManager** plugin requires the following in `android/app/src/main/AndroidManifest.xml`:
- Ensure you have the `INTERNET` and `ACCESS_NETWORK_STATE` permissions.
- WorkManager 0.5.0+ should handle manifest merger automatically, but if you encounter issues, ensure your `compileSdkVersion` is at least 33.

#### iOS
Periodic tasks on iOS require specific capabilities:
- Open the project in Xcode.
- Enable **Background Modes** and check **Background fetch** and **Background processing**.
- Refer to the [WorkManager documentation](https://pub.dev/packages/workmanager) for the `Info.plist` entries required for `BGTaskScheduler`.

## Running the App

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Implementation Notes

- **Sync Order:** The `SyncService` is designed to sync users first, then their bookmarks, ensuring relationship integrity even for data created entirely offline.
- **UI Resilience:** The `PagingController` from `infinite_scroll_pagination` is integrated with the custom retry logic to ensure the infinite list doesn't "break" during transient network failures.
