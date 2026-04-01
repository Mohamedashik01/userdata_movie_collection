import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { idle, connecting, success, failure }

class NetworkStatusState extends StateNotifier<NetworkStatus> {
  NetworkStatusState() : super(NetworkStatus.idle);

  void setConnecting() => state = NetworkStatus.connecting;
  void setIdle() => state = NetworkStatus.idle;
  void setFailure() => state = NetworkStatus.failure;
}

final networkStatusProvider = StateNotifierProvider<NetworkStatusState, NetworkStatus>((ref) {
  return NetworkStatusState();
});
