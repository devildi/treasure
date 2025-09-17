import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheInterceptor extends Interceptor {
  final Duration cacheDuration;
  final List<String> cacheableMethods;

  // 缓存依赖关系映射
  static final Map<String, List<String>> _cacheDependencies = {
    'toys': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_create': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_delete': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_update': ['toys_list', 'total_price_count', 'my_toys'],
  };

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

    // 处理GET请求的缓存存储
    if (cacheableMethods.contains(options.method.toUpperCase()) &&
        response.statusCode == 200) {
      final cacheKey = _generateCacheKey(options);
      await _cacheResponse(cacheKey, response);
      debugPrint('💾 Cached response for: ${options.path}');
    }

    // 处理写操作的缓存失效
    if (!cacheableMethods.contains(options.method.toUpperCase()) &&
        response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      await _invalidateRelatedCache(options);
    }

    handler.next(response);
  }

  String _generateCacheKey(RequestOptions options) {
    final path = options.path;
    final method = options.method;
    final queryParams = options.queryParameters;

    // 生成更智能的缓存key，基于路径和参数
    String cacheTag = _getCacheTag(path);
    String queryString = _buildQueryString(queryParams);

    return 'cache_${cacheTag}_${method}_${queryString.hashCode}';
  }

  String _getCacheTag(String path) {
    if (path.contains('/getAllToies')) return 'toys_list';
    if (path.contains('/getTotalPriceAndCount')) return 'total_price_count';
    if (path.contains('/searchToys')) return 'search_toys';
    if (path.contains('/toy') && path.contains('/delete')) return 'toy_delete';
    if (path.contains('/toy') && path.contains('/create')) return 'toy_create';
    if (path.contains('/toy') && path.contains('/update')) return 'toy_update';
    if (path.contains('/getToken')) return 'token';
    return 'generic';
  }

  String _buildQueryString(Map<String, dynamic> params) {
    if (params.isEmpty) return '';
    return params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
  }

  Future<void> _invalidateRelatedCache(RequestOptions options) async {
    try {
      final operationType = _getOperationType(options.path, options.method);
      final dependentCaches = _cacheDependencies[operationType] ?? [];

      debugPrint('🗑️ Cache invalidation: $operationType affects ${dependentCaches.join(', ')}');

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      for (final cacheTag in dependentCaches) {
        final keysToRemove = allKeys.where((key) =>
            key.startsWith('cache_$cacheTag') ||
            key.contains('_${cacheTag}_timestamp')).toList();

        for (final key in keysToRemove) {
          await prefs.remove(key);
          debugPrint('🗑️ Removed cache key: $key');
        }
      }

      debugPrint('✅ Cache invalidation completed for $operationType');
    } catch (e) {
      debugPrint('❌ Error during cache invalidation: $e');
    }
  }

  String _getOperationType(String path, String method) {
    if (method.toUpperCase() == 'POST' && path.contains('/toy')) return 'toy_create';
    if (method.toUpperCase() == 'DELETE' && path.contains('/toy')) return 'toy_delete';
    if (method.toUpperCase() == 'PUT' && path.contains('/toy')) return 'toy_update';
    if (method.toUpperCase() == 'PATCH' && path.contains('/toy')) return 'toy_update';
    return 'toys';
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
      debugPrint('🗑️ All cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // 清除特定类型的缓存
  static Future<void> clearCacheByTag(String cacheTag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      final keysToRemove = allKeys.where((key) =>
          key.startsWith('cache_$cacheTag') ||
          key.contains('_${cacheTag}_timestamp')).toList();

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      debugPrint('🗑️ Cleared cache for tag: $cacheTag (${keysToRemove.length} keys)');
    } catch (e) {
      debugPrint('Error clearing cache by tag: $e');
    }
  }

  // 清除与玩具相关的所有缓存
  static Future<void> clearToysCache() async {
    final toysCaches = ['toys_list', 'total_price_count', 'my_toys', 'search_toys'];
    for (final cacheTag in toysCaches) {
      await clearCacheByTag(cacheTag);
    }
    debugPrint('🗑️ All toys-related cache cleared');
  }

  // 获取缓存统计信息
  static Future<Map<String, int>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      final cacheKeys = allKeys.where((key) => key.startsWith('cache_')).toList();

      Map<String, int> stats = {};
      for (final key in cacheKeys) {
        final parts = key.split('_');
        if (parts.length >= 3) {
          final cacheTag = parts[1];
          stats[cacheTag] = (stats[cacheTag] ?? 0) + 1;
        }
      }

      stats['total'] = cacheKeys.length;
      return stats;
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }
}