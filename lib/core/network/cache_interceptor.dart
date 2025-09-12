import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheInterceptor extends Interceptor {
  final Duration cacheDuration;
  final List<String> cacheableMethods;
  
  CacheInterceptor({
    this.cacheDuration = const Duration(minutes: 5),
    this.cacheableMethods = const ['GET'],
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!cacheableMethods.contains(options.method.toUpperCase())) {
      return handler.next(options);
    }

    final cacheKey = _generateCacheKey(options);
    final cachedResponse = await _getCachedResponse(cacheKey);
    
    if (cachedResponse != null) {
      debugPrint('📦 Using cached response for: ${options.path}');
      return handler.resolve(cachedResponse);
    }
    
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;
    
    if (cacheableMethods.contains(options.method.toUpperCase()) && 
        response.statusCode == 200) {
      final cacheKey = _generateCacheKey(options);
      await _cacheResponse(cacheKey, response);
      debugPrint('💾 Cached response for: ${options.path}');
    }
    
    handler.next(response);
  }

  String _generateCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    final method = options.method;
    final data = options.data?.toString() ?? '';
    return 'cache_${method}_${uri.hashCode}_${data.hashCode}';
  }

  Future<Response?> _getCachedResponse(String cacheKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final timestampKey = '${cacheKey}_timestamp';
      final timestamp = prefs.getInt(timestampKey);
      
      if (cachedData != null && timestamp != null) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        
        if (now.difference(cachedTime) < cacheDuration) {
          final Map<String, dynamic> responseData = json.decode(cachedData);
          return Response(
            requestOptions: RequestOptions(path: ''),
            data: responseData['data'],
            statusCode: responseData['statusCode'],
            statusMessage: responseData['statusMessage'],
          );
        } else {
          // Cache expired, remove it
          await prefs.remove(cacheKey);
          await prefs.remove(timestampKey);
        }
      }
    } catch (e) {
      debugPrint('Error reading cache: $e');
    }
    
    return null;
  }

  Future<void> _cacheResponse(String cacheKey, Response response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final responseData = {
        'data': response.data,
        'statusCode': response.statusCode,
        'statusMessage': response.statusMessage,
      };
      
      await prefs.setString(cacheKey, json.encode(responseData));
      await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching response: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
      debugPrint('🗑️ Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}