import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/failure_interceptor.dart';
import '../network/retry_interceptor.dart';
import '../network/network_status.dart';
import '../storage/database.dart';
import '../storage/sync_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  
  dio.interceptors.addAll([
    FailureInterceptor(),
    RetryInterceptor(
      dio: dio,
      onRetry: () => ref.read(networkStatusProvider.notifier).setConnecting(),
      onFinished: () => ref.read(networkStatusProvider.notifier).setIdle(),
    ),
  ]);
  
  return dio;
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final dio = ref.watch(dioProvider);
  return SyncService(db, dio);
});
