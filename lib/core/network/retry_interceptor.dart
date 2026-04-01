import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:developer';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final int initialDelayMillis;
  final Function()? onRetry;
  final Function()? onFinished;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelayMillis = 1000,
    this.onRetry,
    this.onFinished,
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    int retries = err.requestOptions.extra['retries'] ?? 0;

    if ((err.type == DioExceptionType.connectionError || 
         err.type == DioExceptionType.badResponse && err.response?.statusCode == 500) &&
        err.requestOptions.method == 'GET' &&
        retries < maxRetries) {
      
      onRetry?.call();
      
      retries++;
      int delay = initialDelayMillis * (1 << (retries - 1));
      
      await Future.delayed(Duration(milliseconds: delay));
      
      try {
        final options = err.requestOptions;
        options.extra['retries'] = retries;
        
        final response = await dio.fetch(options);
        onFinished?.call();
        return handler.resolve(response);
      } on DioException catch (e) {
        return super.onError(e, handler);
      }
    }
    
    onFinished?.call();
    return super.onError(err, handler);
  }
}
