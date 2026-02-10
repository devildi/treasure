// import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:treasure/core/storage/storage_manager.dart';
import 'package:treasure/toy_model.dart';

/// 存储服务 - 提供统一的存储接口
class StorageService {
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  
  StorageService._();
  
  late final StorageManager _storage;
  late final OfflineDataManager _offline;
  late final StorageCleanupManager _cleanup;
  late Box _cacheBox;
  
  bool _initialized = false;
  
  /// 初始化存储服务
  Future<void> initialize() async {
    if (_initialized) return;
    
    // 初始化 Hive
    await Hive.initFlutter();
    
    // 打开 Hive 盒子
    _cacheBox = await Hive.openBox('app_cache');
    
    _storage = StorageManager.instance;
    await _storage.initialize();
    
    _offline = OfflineDataManager();
    _cleanup = StorageCleanupManager();
    
    // 启动时执行智能清理
    _performStartupCleanup();
    
    _initialized = true;
    
    if (kDebugMode) {
      debugPrint('🚀 存储服务初始化完成 (Hive enabled)');
    }
  }
  
  /// 启动时清理
  void _performStartupCleanup() async {
    try {
      // 检查存储使用情况，必要时清理
      final stats = await _cleanup.getStorageStats();
      final usage = stats['usage'] as double? ?? 0;
      
      if (usage > 0.9) { // 使用量超过90%，强制清理
        await _cleanup.performSmartCleanup();
      }
    } catch (e) {
      debugPrint('❌ 启动清理失败: $e');
    }
  }
  
  // ===== 缓存管理 (Hive) =====
  
  /// 保存API响应缓存
  Future<void> cacheApiResponse(
    String endpoint, 
    Map<String, dynamic> response, {
    Duration? expiry,
  }) async {
    final key = 'api_$endpoint';
    final data = {
      'content': response,
      'expiry': DateTime.now().add(expiry ?? const Duration(hours: 1)).millisecondsSinceEpoch,
    };
    await _cacheBox.put(key, data);
  }
  
  /// 读取API响应缓存
  Future<Map<String, dynamic>?> getCachedApiResponse(String endpoint) async {
    final key = 'api_$endpoint';
    final data = _cacheBox.get(key);
    
    if (data != null && data is Map) {
      final expiry = data['expiry'] as int?;
      if (expiry != null && DateTime.now().millisecondsSinceEpoch < expiry) {
        return Map<String, dynamic>.from(data['content'] as Map);
      } else {
        await _cacheBox.delete(key);
      }
    }
    return null;
  }

  /// 清除API响应缓存
  Future<void> clearCachedApiResponse(String endpoint) async {
    await _cacheBox.delete('api_$endpoint');
    if (kDebugMode) {
      debugPrint('🗑️ 已清除API缓存: api_$endpoint');
    }
  }
  
  /// 缓存图片元数据
  Future<void> cacheImageMetadata(
    String imageUrl, 
    Map<String, dynamic> metadata,
  ) async {
    final key = 'img_meta_${imageUrl.hashCode}';
    await _cacheBox.put(key, metadata);
  }
  
  /// 获取缓存的图片元数据
  Future<Map<String, dynamic>?> getCachedImageMetadata(String imageUrl) async {
    final key = 'img_meta_${imageUrl.hashCode}';
    final data = _cacheBox.get(key);
    if (data != null && data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }
  
  /// 缓存搜索结果
  Future<void> cacheSearchResults(
    String query, 
    List<ToyModel> results,
  ) async {
    final key = 'search_${query.toLowerCase().hashCode}';
    final data = {
      'query': query,
      'results': results.map((toy) => toy.toJson()).toList(),
      'count': results.length,
      'expiry': DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch,
    };
    
    await _cacheBox.put(key, data);
  }
  
  /// 获取缓存的搜索结果
  Future<List<ToyModel>?> getCachedSearchResults(String query) async {
    final key = 'search_${query.toLowerCase().hashCode}';
    final data = _cacheBox.get(key);
    
    if (data != null && data is Map) {
      final expiry = data['expiry'] as int?;
      if (expiry != null && DateTime.now().millisecondsSinceEpoch < expiry) {
        final resultsList = data['results'] as List?;
        if (resultsList == null) return null;
        return resultsList
            .map((json) => ToyModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      } else {
        await _cacheBox.delete(key);
      }
    }
    return null;
  }
  
  // ===== 离线数据管理 =====
  
  /// 同步数据到离线存储
  Future<void> syncToOffline(List<ToyModel> toys) async {
    await _offline.saveToysForOffline(toys);
  }
  
  /// 获取离线数据
  Future<List<ToyModel>> getOfflineData() async {
    return await _offline.getOfflineToys();
  }
  
  /// 搜索离线数据
  Future<List<ToyModel>> searchOffline(String query) async {
    return await _offline.searchOfflineToys(query);
  }
  
  /// 检查是否有离线数据
  Future<bool> hasOfflineData() async {
    final toys = await _offline.getOfflineToys();
    return toys.isNotEmpty;
  }
  
  /// 获取离线数据状态
  Future<OfflineDataStatus> getOfflineStatus() async {
    final status = await _offline.getOfflineStatus();
    return OfflineDataStatus(
      totalItems: status['totalItems'] ?? 0,
      lastSyncTime: status['lastSyncTime'],
      isStale: status['isStale'] ?? true,
    );
  }
  
  // ===== 存储管理 =====
  
  /// 获取存储统计信息
  Future<StorageStats> getStorageStats() async {
    final stats = await _cleanup.getStorageStats();
    
    // Include Hive cache size estimation involves file checking, 
    // for simplicity we use cleanup stats which might need update for Hive,
    // but here we just return what we have plus dummy for Hive or implement properly if needed.
    // For now, keep existing logic but acknowledge Hive usage exists.
    
    return StorageStats(
      cacheSize: stats['cacheSize'] ?? 0,
      dataSize: stats['dataSize'] ?? 0,
      totalSize: stats['totalSize'] ?? 0,
      maxSize: stats['maxSize'] ?? 0,
      offlineItems: stats['offlineItems'] ?? 0,
      usage: stats['usage'] ?? 0.0,
    );
  }
  
  /// 执行存储清理
  Future<void> cleanupStorage() async {
    await _cleanup.performSmartCleanup();
    // Compact Hive box
    await _cacheBox.compact();
  }
  
  /// 清理特定类型的缓存
  Future<void> clearCache({
    bool apiCache = false,
    bool imageCache = false,
    bool searchCache = false,
    bool allCache = false,
  }) async {
    if (allCache) {
      await _cacheBox.clear();
      return;
    }
    
    final keys = _cacheBox.keys.toList();
    for (final key in keys) {
      final strKey = key.toString();
      bool shouldDelete = false;
      if (apiCache && strKey.startsWith('api_')) shouldDelete = true;
      if (imageCache && strKey.startsWith('img_meta_')) shouldDelete = true;
      if (searchCache && strKey.startsWith('search_')) shouldDelete = true;
      
      if (shouldDelete) {
        await _cacheBox.delete(key);
      }
    }
  }

  /// 按标签清除缓存 (包含任意标签的key)
  Future<void> clearCacheByTags(List<String> tags) async {
    final keys = _cacheBox.keys.toList();
    for (final key in keys) {
      final strKey = key.toString();
      for (final tag in tags) {
        if (strKey.contains(tag)) {
          await _cacheBox.delete(key);
          break; // Deleted, move to next key
        }
      }
    }
  }
  
  /// 清空所有数据
  Future<void> clearAllData() async {
    await _offline.clearOfflineData();
    await clearCache(allCache: true);
    
    if (kDebugMode) {
      debugPrint('🧹 所有存储数据已清空');
    }
  }
  
  // ===== 偏好设置存储 =====
  
  /// 保存应用设置
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = _storage.prefs;
    
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw ArgumentError('不支持的数据类型: ${value.runtimeType}');
    }
  }
  
  /// 读取应用设置
  T? getSetting<T>(String key, {T? defaultValue}) {
    final prefs = _storage.prefs;
    
    if (T == bool) {
      return (prefs.getBool(key) ?? defaultValue) as T?;
    } else if (T == int) {
      return (prefs.getInt(key) ?? defaultValue) as T?;
    } else if (T == double) {
      return (prefs.getDouble(key) ?? defaultValue) as T?;
    } else if (T == String) {
      return (prefs.getString(key) ?? defaultValue) as T?;
    } else if (T == List<String>) {
      return (prefs.getStringList(key) ?? defaultValue) as T?;
    } else {
      return defaultValue;
    }
  }
  
  /// 删除设置
  Future<void> removeSetting(String key) async {
    await _storage.prefs.remove(key);
  }
  
  // ===== 数据导出/导入 =====
  
  /// 导出离线数据
  Future<Map<String, dynamic>> exportOfflineData() async {
    final toys = await _offline.getOfflineToys();
    final status = await _offline.getOfflineStatus();
    
    return {
      'version': '1.0',
      'exportTime': DateTime.now().toIso8601String(),
      'totalItems': toys.length,
      'lastSync': status['lastSyncTime']?.toIso8601String(),
      'toys': toys.map((toy) => toy.toJson()).toList(),
    };
  }
  
  /// 导入离线数据
  Future<bool> importOfflineData(Map<String, dynamic> data) async {
    try {
      final toysData = data['toys'] as List?;
      if (toysData == null) return false;
      
      final toys = toysData
          .map((json) => ToyModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      await _offline.saveToysForOffline(toys);
      return true;
    } catch (e) {
      debugPrint('❌ 导入离线数据失败: $e');
      return false;
    }
  }

  /// 清除所有缓存
  static Future<void> clearAllCaches() async {
    try {
      final service = StorageService.instance;
      await service.initialize();

      // 清除所有类型的缓存
      await service.clearCache(
        apiCache: true,
        imageCache: true,
        searchCache: true,
        allCache: false, // 不清除本地存储，只清除缓存
      );

      debugPrint('🧹 StorageService: 所有缓存已清除');
    } catch (e) {
      debugPrint('⚠️ StorageService: 清除缓存失败 - $e');
    }
  }
}

/// 离线数据状态
class OfflineDataStatus {
  final int totalItems;
  final DateTime? lastSyncTime;
  final bool isStale;
  
  const OfflineDataStatus({
    required this.totalItems,
    this.lastSyncTime,
    required this.isStale,
  });
  
  String get statusText {
    if (totalItems == 0) return '无离线数据';
    if (isStale) return '数据已过期，建议刷新';
    return '数据最新';
  }
}

/// 存储统计信息
class StorageStats {
  final int cacheSize;
  final int dataSize;
  final int totalSize;
  final int maxSize;
  final int offlineItems;
  final double usage;
  
  const StorageStats({
    required this.cacheSize,
    required this.dataSize,
    required this.totalSize,
    required this.maxSize,
    required this.offlineItems,
    required this.usage,
  });
  
  String get formattedCacheSize => StorageCleanupManager.formatSize(cacheSize);
  String get formattedDataSize => StorageCleanupManager.formatSize(dataSize);
  String get formattedTotalSize => StorageCleanupManager.formatSize(totalSize);
  String get formattedMaxSize => StorageCleanupManager.formatSize(maxSize);
  
  bool get isLowSpace => usage > 0.8;
  bool get isCriticalSpace => usage > 0.95;
  
  String get usageText {
    if (isCriticalSpace) return '存储空间严重不足';
    if (isLowSpace) return '存储空间不足';
    return '存储空间充足';
  }
}