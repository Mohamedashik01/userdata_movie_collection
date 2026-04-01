import 'dart:math';
import 'package:dio/dio.dart';
import 'dart:io';

class FailureInterceptor extends Interceptor {
  final Random _random = Random();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Only fail GET requests as per assignment
    if (options.method == 'GET' && _random.nextDouble() < 0.3) {
      final shouldBeSocketException = _random.nextBool();
      
      if (shouldBeSocketException) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const SocketException('Simulated network failure'),
            type: DioExceptionType.connectionError,
          ),
        );
      } else {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 500,
            statusMessage: 'Simulated Internal Server Error',
            data: {'error': 'Internal Server Error'},
          ),
        );
      }
    }
    return super.onRequest(options, handler);
  }
}
