import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'core/storage/database.dart';
import 'core/storage/sync_service.dart';
import 'features/users/presentation/user_list_screen.dart';
import 'package:dio/dio.dart';
import 'core/network/failure_interceptor.dart';
import 'core/network/retry_interceptor.dart';

const syncTaskName = 'com.ashik.assignment.syncTask';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Note: In a background task, we don't have the ProviderContainer 
    // from the main app, so we initialize dependencies manually.
    final db = AppDatabase();
    final dio = Dio();
    dio.interceptors.addAll([
      FailureInterceptor(),
      RetryInterceptor(dio: dio),
    ]);
    
    final syncService = SyncService(db, dio);
    
    try {
      await syncService.syncData();
      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    } finally {
      await db.close();
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to false for release
  );

  // Register a periodic task for syncing (every 15 mins is the minimum for Android)
  await Workmanager().registerPeriodicTask(
    'sync-task-id',
    syncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Assignment',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const UserListScreen(),
    );
  }
}
