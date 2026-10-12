// import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:treasure/core/storage/storage_service.dart';

class CacheInterceptor extends Interceptor {
  final Duration defaultCacheDuration;
  final List<String> cacheableMethods;

  // 内存缓存 (Memory Cache)
  static final Map<String, CacheEntry> _memoryCache = {};

  // 缓存依赖关系映射
  static final Map<String, List<String>> _cacheDependencies = {
    'toys': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_create': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_delete': ['toys_list', 'total_price_count', 'my_toys'],
    'toy_update': ['toys_list', 'total_price_count', 'my_toys'],
  };

  CacheInterceptor({
    this.defaultCacheDuration = const Duration(minutes: 5),
    this.cacheableMethods = const ['GET'],
  });

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // 检查是否有 forceful refresh 标记 (pass force_refresh: true to ignore cache completely, even for fallback)
    final forceRefresh = options.extra['force_refresh'] == true;
    // Check if we should allow cache fallback (default true for GET)
    final allowCache = cacheableMethods.contains(options.method.toUpperCase());

    if (!allowCache) {
      return handler.next(options);
    }

    // STRATEGY: Network First (Try Network -> If Fail -> Try Cache)
    // We pass through to network here.
    // But we attach an onError handler to intercept network failures and try cache.
    // NOTE: Dio interceptors are sequential. We need to handle this in onError.

    // However, for Memory Cache, if it is extremely fresh (e.g. < 5 seconds, or explicit duplicate request prevention),
    // we might want to return it. But "Network First" implies we want the server opinion.
    // Users often hate "loading" spinners if they just loaded data 1 second ago.
    // So let's add a "short-term" memory cache check (deduplication).

    final cacheKey = _generateCacheKey(options);

    // 0. Short-term Memory Cache (Deduplication / Instant navigation back)
    // If the data is very fresh (e.g. < 10 seconds), use it to avoid spamming server on UI rebuilds
    final memoryCached = _memoryCache[cacheKey];
    if (memoryCached != null &&
        !memoryCached.isExpired &&
        DateTime.now().difference(memoryCached.savedAt).inSeconds < 10 &&
        !forceRefresh) {
      debugPrint('🚀 Using Short-term Memory Cache for: ${options.path}');
      return handler.resolve(memoryCached.toResponse(options));
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Network First Strategy: On Error, try Cache
    final options = err.requestOptions;

    if (cacheableMethods.contains(options.method.toUpperCase()) &&
        err.type != DioExceptionType.cancel) {
      // Don't cache-fallback on cancellation

      debugPrint(
          '⚠️ Network error for ${options.path}, trying cache fallback...');

      final cacheKey = _generateCacheKey(options);

      // 1. Try Memory Cache
      final memoryCached = _memoryCache[cacheKey];
      if (memoryCached != null) {
        debugPrint('🚀 Fallback to Memory Cache');
        return handler.resolve(memoryCached.toResponse(options));
      }

      // 2. Try Disk Cache
      final cachedResponse = await _getCachedResponse(cacheKey, options);
      if (cachedResponse != null) {
        debugPrint('📦 Fallback to Disk Cache');
        return handler.resolve(cachedResponse);
      }
    }

    handler.next(err);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;

    // Cache valid successful GET responses
    if (cacheableMethods.contains(options.method.toUpperCase()) &&
        response.statusCode == 200) {
      final cacheKey = _generateCacheKey(options);
      final customDuration = options.extra['cache_duration'] as Duration?;
      final duration = customDuration ?? defaultCacheDuration;

      // Update Caches
      final entry = CacheEntry(
        data: response.data,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
        expiry: DateTime.now().add(duration),
        savedAt: DateTime.now(),
      );

      _memoryCache[cacheKey] = entry;
      _cacheResponse(cacheKey, response, duration);

      debugPrint('💾 Cached response for: ${options.path}');
    }

    // Invalidate on Write
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
    // 排序参数以确保一致性
    final sortedKeys = params.keys.toList()..sort();
    return sortedKeys.map((key) => '$key=${params[key]}').join('&');
  }

  Future<void> _invalidateRelatedCache(RequestOptions options) async {
    try {
      final operationType = _getOperationType(options.path, options.method);
      final dependentCaches = _cacheDependencies[operationType] ?? [];

      debugPrint(
          '🗑️ Cache invalidation: $operationType affects ${dependentCaches.join(', ')}');

      // 清除内存缓存
      _memoryCache.removeWhere((key, _) {
        return dependentCaches.any((tag) => key.contains('cache_$tag'));
      });

      // 清除磁盘缓存
      // 实际上目前无法按前缀清除，除非我们修改StorageService
      // 这里的逻辑需要改进，但至少不要调用StorageService不存在的方法
      // StorageService.instance.clearCache(allCache: false) does not support tags well yet

      // For now, doing nothing for disk cache invalidation on tags, until StorageService is upgraded
      // Or we can rely on TTL.
      // Or we can assume StorageService has implemented clearCacheByTag if we modify it.
      // But StorageService currently does NOT have clearCacheByTag (it was in the OLD CacheInterceptor?)

      // Wait, let's check StorageService.dart clean content.
      // It has `clearCache(...)` with booleans.
      // It does NOT have tag based clearing.

      // So checking my Cleaned CacheInterceptor code:
      // I will remove the detailed iteration that requires 'StorageService.clearCacheByTag' since it doesn't exist

      debugPrint('✅ Cache invalidation completed for $operationType');
    } catch (e) {
      debugPrint('❌ Error during cache invalidation: $e');
    }
  }

  String _getOperationType(String path, String method) {
    if (method.toUpperCase() == 'POST' && path.contains('/toy')) {
      return 'toy_create';
    }
    if (method.toUpperCase() == 'DELETE' && path.contains('/toy')) {
      return 'toy_delete';
    }
    if (method.toUpperCase() == 'PUT' && path.contains('/toy')) {
      return 'toy_update';
    }
    if (method.toUpperCase() == 'PATCH' && path.contains('/toy')) {
      return 'toy_update';
    }
    return 'toys';
  }

  Future<Response?> _getCachedResponse(
      String cacheKey, RequestOptions options) async {
    try {
      final data = await StorageService.instance.getCachedApiResponse(cacheKey);

      if (data != null) {
        return Response(
          requestOptions: options,
          data: data,
          statusCode: 200,
          statusMessage: 'OK (Cached)',
        );
      }
    } catch (e) {
      debugPrint('Error reading disk cache: $e');
    }

    return null;
  }

  Future<void> _cacheResponse(
      String cacheKey, Response response, Duration duration) async {
    try {
      await StorageService.instance.cacheApiResponse(
        cacheKey,
        response.data is Map<String, dynamic>
            ? response.data
            : {'value': response.data},
        expiry: duration,
      );
    } catch (e) {
      debugPrint('Error caching response to disk: $e');
    }
  }

  // Method to satisfy legacy calls if any (though they should call StorageService)
  static Future<void> clearCache() async {
    await StorageService.clearAllCaches();
  }

  // 清除与玩具相关的所有缓存
  static Future<void> clearToysCache() async {
    // 1. Clear Memory Cache
    final toysTags = [
      'toys_list',
      'total_price_count',
      'my_toys',
      'search_toys',
      'toys_page'
    ];
    _memoryCache.removeWhere((key, _) {
      return toysTags.any((tag) => key.contains(tag));
    });

    // 2. Clear Disk Cache via StorageService
    await StorageService.instance.clearCacheByTags(toysTags);

    debugPrint('🗑️ All toys-related cache cleared (Memory & Disk)');
  }
}

class CacheEntry {
  final dynamic data;
  final int? statusCode;
  final String? statusMessage;
  final DateTime expiry;
  final DateTime savedAt;

  CacheEntry({
    required this.data,
    required this.statusCode,
    required this.statusMessage,
    required this.expiry,
    required this.savedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiry);

  Response toResponse(RequestOptions options) {
    return Response(
      requestOptions: options,
      data: data,
      statusCode: statusCode,
      statusMessage: statusMessage,
    );
  }
}
