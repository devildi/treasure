import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_response.dart';
import 'network_exceptions.dart';
import 'retry_interceptor.dart';
// import 'cache_interceptor.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  Dio? _dio;

  void initialize({
    required String baseUrl,
    int connectTimeout = 15000,
    int receiveTimeout = 15000,
    int sendTimeout = 15000,
  }) {
    debugPrint('🔧 ApiClient.initialize: 初始化Dio客户端');
    debugPrint('🔧 ApiClient.initialize: baseUrl = $baseUrl');

    _dio?.close(); // Close existing instance if any
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    debugPrint('🔧 ApiClient.initialize: 设置拦截器...');
    _setupInterceptors();
    debugPrint('✅ ApiClient.initialize: Dio客户端初始化完成');
  }

  void _setupInterceptors() {
    if (_dio == null) return;

    // 临时禁用CacheInterceptor
    debugPrint('⚠️ ApiClient: 临时禁用CacheInterceptor');
    // _dio!.interceptors.add(CacheInterceptor(
    //   cacheDuration: const Duration(minutes: 10), // 延长缓存时间
    //   cacheableMethods: const ['GET'], // 只缓存GET请求
    // ));

    // Add retry interceptor
    _dio!.interceptors.add(RetryInterceptor(
      maxRetries: 3,
      delay: const Duration(milliseconds: 1000),
    ));

    // Add logging interceptor for debug mode
    if (kDebugMode) {
      _dio!.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }

    // Add custom request/response interceptor
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('🚀 Request: ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('✅ Response: ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('❌ Error: ${error.response?.statusCode} ${error.requestOptions.path}');
        handler.next(error);
      },
    ));
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    debugPrint('🌐 ApiClient.get: 准备发送GET请求');
    debugPrint('🌐 ApiClient.get: path = $path');
    debugPrint('🌐 ApiClient.get: queryParameters = $queryParameters');
    debugPrint('🌐 ApiClient.get: _dio是否已初始化 = ${_dio != null}');

    if (_dio == null) {
      debugPrint('❌ ApiClient.get: Dio客户端未初始化!');
      throw Exception('Dio客户端未初始化');
    }

    try {
      debugPrint('🚀 ApiClient.get: 执行_dio.get请求...');
      final response = await _dio!.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      debugPrint('✅ ApiClient.get: _dio.get响应完成 (statusCode=${response.statusCode})');
      return _handleResponse<T>(response, fromJson);
    } on DioError catch (e) {
      debugPrint('❌ ApiClient.get: DioError - ${e.type} - ${e.message}');
      throw _handleDioError(e);
    } catch (e) {
      debugPrint('❌ ApiClient.get: 未知错误 - $e (${e.runtimeType})');
      throw UnknownNetworkException(message: e.toString());
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio!.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioError catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownNetworkException(message: e.toString());
    }
  }

  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio!.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioError catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownNetworkException(message: e.toString());
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio!.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioError catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw UnknownNetworkException(message: e.toString());
    }
  }

  ApiResponse<T> _handleResponse<T>(Response response, T Function(dynamic)? fromJson) {
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      T? data;
      if (fromJson != null && response.data != null) {
        data = fromJson(response.data);
      } else {
        data = response.data as T?;
      }
      
      return ApiResponse.success(
        data: data,
        statusCode: response.statusCode!,
        message: 'Success',
      );
    } else {
      throw ServerException(
        statusCode: response.statusCode,
        message: 'Request failed with status: ${response.statusCode}',
      );
    }
  }

  NetworkException _handleDioError(DioError error) {
    switch (error.type) {
      case DioErrorType.connectTimeout:
        return ConnectionTimeoutException();
      case DioErrorType.sendTimeout:
        return SendTimeoutException();
      case DioErrorType.receiveTimeout:
        return ReceiveTimeoutException();
      case DioErrorType.response:
        return ServerException(
          statusCode: error.response?.statusCode,
          message: error.response?.data?.toString() ?? 'Server error',
        );
      case DioErrorType.cancel:
        return RequestCancelledException();
      case DioErrorType.other:
        if (error.error is SocketException) {
          return NoInternetException();
        }
        return UnknownNetworkException(message: error.message);
    }
  }

  void addAuthToken(String token) {
    _dio!.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio!.options.headers.remove('Authorization');
  }

  void dispose() {
    _dio?.close();
  }
}