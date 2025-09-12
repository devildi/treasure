import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration delay;
  final List<int> retryStatusCodes;

  RetryInterceptor({
    this.maxRetries = 3,
    this.delay = const Duration(milliseconds: 1000),
    this.retryStatusCodes = const [502, 503, 504, 408],
  });

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) async {
    final extra = err.requestOptions.extra;
    final retries = extra['retries'] ?? 0;

    if (retries < maxRetries && _shouldRetry(err)) {
      debugPrint('🔄 Retrying request (${retries + 1}/$maxRetries): ${err.requestOptions.path}');
      
      extra['retries'] = retries + 1;
      err.requestOptions.extra = extra;
      
      await Future.delayed(delay * (retries + 1)); // Exponential backoff
      
      try {
        final dio = Dio();
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        if (e is DioError) {
          super.onError(e, handler);
        } else {
          handler.reject(err);
        }
        return;
      }
    }
    
    super.onError(err, handler);
  }

  bool _shouldRetry(DioError error) {
    return error.type == DioErrorType.connectTimeout ||
           error.type == DioErrorType.sendTimeout ||
           error.type == DioErrorType.receiveTimeout ||
           (error.response != null && 
            retryStatusCodes.contains(error.response!.statusCode));
  }
}