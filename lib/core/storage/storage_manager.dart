import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/state/state_persistence.dart';

/// 存储管理器 - 统一管理所有本地存储
class StorageManager {
  static StorageManager? _instance;
  static StorageManager get instance => _instance ??= StorageManager._();

  StorageManager._();

  SharedPreferences? _prefs;
  Directory? _cacheDir;
  Directory? _dataDir;

  // 存储配置
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxFileAge = 7 * 24 * 60 * 60 * 1000; // 7天 (毫秒)
  static const int maxOfflineItems = 500; // 最多500个离线项目

  /// 初始化存储管理器
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _cacheDir = await _getCacheDirectory();
    _dataDir = await _getDataDirectory();

    // 启动时清理过期缓存
    final cacheManager = CacheManager();
    cacheManager.cleanExpiredCache();

    if (kDebugMode) {
      debugPrint('📁 存储管理器初始化完成');
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/treasure_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// 获取数据目录
  Future<Directory> _getDataDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${appDir.path}/treasure_data');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }

  SharedPreferences get prefs => _prefs!;
  Directory get cacheDir => _cacheDir!;
  Directory get dataDir => _dataDir!;
}

/// 缓存管理器 - 管理临时缓存数据
class CacheManager {
  final StorageManager _storage = StorageManager.instance;

  /// 保存缓存数据
  Future<void> saveCache<T>(
    String key,
    T data, {
    Duration? expiry,
    bool compress = false,
  }) async {
    try {
      final cacheFile = File('${_storage.cacheDir.path}/$key.cache');
      final metadata = File('${_storage.cacheDir.path}/$key.meta');

      String jsonData;
      if (data is String) {
        jsonData = data;
      } else {
        jsonData = jsonEncode(data);
      }

      // 可选压缩
      if (compress && jsonData.length > 1024) {
        final bytes = utf8.encode(jsonData);
        final compressed = gzip.encode(bytes);
        await cacheFile.writeAsBytes(compressed);
      } else {
        await cacheFile.writeAsString(jsonData);
      }

      // 保存元数据
      final metaData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiry': expiry?.inMilliseconds,
        'compressed': compress && jsonData.length > 1024,
        'size': jsonData.length,
      };

      await metadata.writeAsString(jsonEncode(metaData));

      if (kDebugMode) {
        debugPrint('💾 缓存已保存: $key (${jsonData.length} bytes)');
      }
    } catch (e) {
      debugPrint('❌ 保存缓存失败 [$key]: $e');
    }
  }

  /// 读取缓存数据
  Future<T?> loadCache<T>(String key) async {
    try {
      final cacheFile = File('${_storage.cacheDir.path}/$key.cache');
      final metadata = File('${_storage.cacheDir.path}/$key.meta');

      if (!await cacheFile.exists() || !await metadata.exists()) {
        return null;
      }

      // 检查元数据
      final metaJson = jsonDecode(await metadata.readAsString());
      final timestamp = metaJson['timestamp'] as int;
      final expiry = metaJson['expiry'] as int?;
      final compressed = metaJson['compressed'] as bool? ?? false;

      // 检查是否过期
      if (expiry != null) {
        final expiryTime = timestamp + expiry;
        if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
          await deleteCache(key);
          return null;
        }
      }

      // 读取数据
      String jsonData;
      if (compressed) {
        final compressedBytes = await cacheFile.readAsBytes();
        final decompressed = gzip.decode(compressedBytes);
        jsonData = utf8.decode(decompressed);
      } else {
        jsonData = await cacheFile.readAsString();
      }

      if (T == String) {
        return jsonData as T;
      } else {
        return jsonDecode(jsonData) as T;
      }
    } catch (e) {
      debugPrint('❌ 读取缓存失败 [$key]: $e');
      await deleteCache(key);
      return null;
    }
  }

  /// 删除特定缓存
  Future<void> deleteCache(String key) async {
    try {
      final cacheFile = File('${_storage.cacheDir.path}/$key.cache');
      final metadata = File('${_storage.cacheDir.path}/$key.meta');

      if (await cacheFile.exists()) await cacheFile.delete();
      if (await metadata.exists()) await metadata.delete();

      if (kDebugMode) {
        debugPrint('🗑️ 缓存已删除: $key');
      }
    } catch (e) {
      debugPrint('❌ 删除缓存失败 [$key]: $e');
    }
  }

  /// 清理过期缓存
  Future<void> cleanExpiredCache() async {
    try {
      final files = await _storage.cacheDir.list().toList();
      final metaFiles =
          files.where((f) => f.path.endsWith('.meta')).cast<File>().toList();

      for (final metaFile in metaFiles) {
        try {
          final content = await metaFile.readAsString();
          final meta = jsonDecode(content);

          final timestamp = meta['timestamp'] as int;
          final expiry = meta['expiry'] as int?;

          bool shouldDelete = false;

          // 检查过期时间
          if (expiry != null) {
            final expiryTime = timestamp + expiry;
            if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
              shouldDelete = true;
            }
          }

          // 检查文件年龄
          final age = DateTime.now().millisecondsSinceEpoch - timestamp;
          if (age > StorageManager.maxFileAge) {
            shouldDelete = true;
          }

          if (shouldDelete) {
            final key = metaFile.path.split('/').last.replaceAll('.meta', '');
            await deleteCache(key);
          }
        } catch (e) {
          // 损坏的元数据文件，直接删除
          await metaFile.delete();
        }
      }

      if (kDebugMode) {
        debugPrint('🧹 过期缓存清理完成');
      }
    } catch (e) {
      debugPrint('❌ 清理过期缓存失败: $e');
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final files = await _storage.cacheDir.list(recursive: true).toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('❌ 计算缓存大小失败: $e');
      return 0;
    }
  }

  /// 清理缓存以释放空间
  Future<void> cleanupCache({int? targetSize}) async {
    final currentSize = await getCacheSize();
    final target = targetSize ?? (StorageManager.maxCacheSize ~/ 2);

    if (currentSize <= target) return;

    try {
      final files = await _storage.cacheDir.list().toList();
      final metaFiles =
          files.where((f) => f.path.endsWith('.meta')).cast<File>().toList();

      // 按时间排序，删除最旧的缓存
      final cacheInfos = <Map<String, dynamic>>[];

      for (final metaFile in metaFiles) {
        try {
          final content = await metaFile.readAsString();
          final meta = jsonDecode(content);
          final key = metaFile.path.split('/').last.replaceAll('.meta', '');

          cacheInfos.add({
            'key': key,
            'timestamp': meta['timestamp'] as int,
            'size': meta['size'] as int? ?? 0,
          });
        } catch (e) {
          continue;
        }
      }

      cacheInfos.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

      int deletedSize = 0;
      for (final info in cacheInfos) {
        await deleteCache(info['key']);
        deletedSize += info['size'] as int;

        if (currentSize - deletedSize <= target) break;
      }

      if (kDebugMode) {
        debugPrint('🧹 缓存清理完成，释放空间: ${deletedSize ~/ 1024}KB');
      }
    } catch (e) {
      debugPrint('❌ 缓存清理失败: $e');
    }
  }
}

/// 离线数据管理器 - 管理离线可用的数据
class OfflineDataManager {
  final StorageManager _storage = StorageManager.instance;
  static const String _offlineToysKey = 'offline_toys';
  static const String _lastSyncKey = 'last_sync_time';

  /// 保存玩具数据供离线使用
  Future<void> saveToyForOffline(ToyModel toy) async {
    try {
      final offlineToys = await getOfflineToys();

      // 检查是否已存在，更新或添加
      final existingIndex = offlineToys.indexWhere((t) => t.id == toy.id);
      if (existingIndex >= 0) {
        offlineToys[existingIndex] = toy;
      } else {
        offlineToys.add(toy);
      }

      // 限制离线数据量
      if (offlineToys.length > StorageManager.maxOfflineItems) {
        offlineToys.removeRange(
            0, offlineToys.length - StorageManager.maxOfflineItems);
      }

      await _saveOfflineToys(offlineToys);
      await updateLastSyncTime();

      if (kDebugMode) {
        debugPrint('💾 玩具已保存到离线存储: ${toy.toyName}');
      }
    } catch (e) {
      debugPrint('❌ 保存离线玩具失败: $e');
    }
  }

  /// 批量保存玩具数据
  Future<void> saveToysForOffline(List<ToyModel> toys) async {
    try {
      final existingToys = await getOfflineToys();
      final toyMap = <String, ToyModel>{};

      // 合并现有数据和新数据
      for (final toy in existingToys) {
        toyMap[toy.id] = toy;
      }

      for (final toy in toys) {
        toyMap[toy.id] = toy;
      }

      final allToys = toyMap.values.toList();

      // 限制数量
      if (allToys.length > StorageManager.maxOfflineItems) {
        allToys.sort((a, b) => b.createAt.compareTo(a.createAt));
        allToys.removeRange(StorageManager.maxOfflineItems, allToys.length);
      }

      await _saveOfflineToys(allToys);
      await updateLastSyncTime();

      if (kDebugMode) {
        debugPrint('💾 批量保存离线玩具: ${toys.length} 个');
      }
    } catch (e) {
      debugPrint('❌ 批量保存离线玩具失败: $e');
    }
  }

  /// 获取离线玩具数据
  Future<List<ToyModel>> getOfflineToys() async {
    try {
      final dataFile = File('${_storage.dataDir.path}/$_offlineToysKey.json');

      if (!await dataFile.exists()) {
        return [];
      }

      final jsonString = await dataFile.readAsString();
      final jsonList = jsonDecode(jsonString) as List;

      return jsonList.map((json) => ToyModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ 读取离线玩具失败: $e');
      return [];
    }
  }

  /// 搜索离线玩具
  Future<List<ToyModel>> searchOfflineToys(String query) async {
    try {
      final allToys = await getOfflineToys();

      if (query.isEmpty) return allToys;

      final lowerQuery = query.toLowerCase();
      return allToys.where((toy) {
        return toy.toyName.toLowerCase().contains(lowerQuery) ||
            toy.description.toLowerCase().contains(lowerQuery) ||
            toy.labels.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      debugPrint('❌ 搜索离线玩具失败: $e');
      return [];
    }
  }

  /// 删除离线玩具
  Future<void> removeOfflineToy(String toyId) async {
    try {
      final toys = await getOfflineToys();
      toys.removeWhere((toy) => toy.id == toyId);
      await _saveOfflineToys(toys);

      if (kDebugMode) {
        debugPrint('🗑️ 离线玩具已删除: $toyId');
      }
    } catch (e) {
      debugPrint('❌ 删除离线玩具失败: $e');
    }
  }

  /// 清空离线数据
  Future<void> clearOfflineData() async {
    try {
      final dataFile = File('${_storage.dataDir.path}/$_offlineToysKey.json');
      if (await dataFile.exists()) {
        await dataFile.delete();
      }

      _storage.prefs.remove(_lastSyncKey);

      if (kDebugMode) {
        debugPrint('🧹 离线数据已清空');
      }
    } catch (e) {
      debugPrint('❌ 清空离线数据失败: $e');
    }
  }

  /// 获取离线数据状态
  Future<Map<String, dynamic>> getOfflineStatus() async {
    final toys = await getOfflineToys();
    final lastSync = _storage.prefs.getInt(_lastSyncKey);

    return {
      'totalItems': toys.length,
      'lastSyncTime': lastSync != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSync)
          : null,
      'isStale': lastSync != null
          ? DateTime.now()
                  .difference(DateTime.fromMillisecondsSinceEpoch(lastSync))
                  .inHours >
              24
          : true,
    };
  }

  /// 更新最后同步时间
  Future<void> updateLastSyncTime() async {
    await _storage.prefs
        .setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// 保存离线玩具数据到文件
  Future<void> _saveOfflineToys(List<ToyModel> toys) async {
    final dataFile = File('${_storage.dataDir.path}/$_offlineToysKey.json');
    final jsonList = toys.map((toy) => toy.toJson()).toList();
    await dataFile.writeAsString(jsonEncode(jsonList));
  }
}

/// 存储清理管理器 - 管理存储容量和清理策略
class StorageCleanupManager {
  final StorageManager _storage = StorageManager.instance;
  final CacheManager _cache = CacheManager();
  final OfflineDataManager _offline = OfflineDataManager();

  /// 获取存储使用情况统计
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final cacheSize = await _cache.getCacheSize();
      final dataSize = await _getDataDirectorySize();
      final offlineStatus = await _offline.getOfflineStatus();

      return {
        'cacheSize': cacheSize,
        'dataSize': dataSize,
        'totalSize': cacheSize + dataSize,
        'maxSize': StorageManager.maxCacheSize,
        'offlineItems': offlineStatus['totalItems'],
        'lastSync': offlineStatus['lastSyncTime'],
        'usage': (cacheSize + dataSize) / StorageManager.maxCacheSize,
      };
    } catch (e) {
      debugPrint('❌ 获取存储统计失败: $e');
      return {};
    }
  }

  /// 执行智能清理
  Future<void> performSmartCleanup() async {
    try {
      final stats = await getStorageStats();
      final usage = stats['usage'] as double? ?? 0;

      if (usage > 0.8) {
        // 使用量超过80%
        // 清理过期缓存
        await _cache.cleanExpiredCache();

        // 如果还是超量，进行缓存清理
        final newStats = await getStorageStats();
        final newUsage = newStats['usage'] as double? ?? 0;

        if (newUsage > 0.7) {
          await _cache.cleanupCache();
        }

        // 如果离线数据过多，清理旧数据
        final offlineCount = stats['offlineItems'] as int? ?? 0;
        if (offlineCount > StorageManager.maxOfflineItems * 0.9) {
          await _cleanupOldOfflineData();
        }
      }

      if (kDebugMode) {
        debugPrint('🧹 智能清理完成');
      }
    } catch (e) {
      debugPrint('❌ 智能清理失败: $e');
    }
  }

  /// 清理旧的离线数据
  Future<void> _cleanupOldOfflineData() async {
    try {
      final toys = await _offline.getOfflineToys();
      if (toys.length <= StorageManager.maxOfflineItems ~/ 2) return;

      // 按创建时间排序，保留最新的一半
      toys.sort((a, b) => b.createAt.compareTo(a.createAt));
      const keepCount = StorageManager.maxOfflineItems ~/ 2;
      final toKeep = toys.take(keepCount).toList();

      await _offline._saveOfflineToys(toKeep);

      if (kDebugMode) {
        debugPrint('🧹 清理旧离线数据: 保留 $keepCount 个最新项目');
      }
    } catch (e) {
      debugPrint('❌ 清理旧离线数据失败: $e');
    }
  }

  /// 获取数据目录大小
  Future<int> _getDataDirectorySize() async {
    try {
      final files = await _storage.dataDir.list(recursive: true).toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('❌ 计算数据目录大小失败: $e');
      return 0;
    }
  }

  /// 格式化大小显示
  static String formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// 扩展现有的状态持久化，使其支持过期时间
extension StatePersistenceExtended on StatePersistence {
  Future<void> saveWithExpiry(
    String key,
    Map<String, dynamic> data,
    Duration expiry,
  ) async {
    final wrappedData = {
      'data': data,
      'expiry': DateTime.now().add(expiry).millisecondsSinceEpoch,
    };
    await save(key, wrappedData);
  }

  Future<Map<String, dynamic>?> loadWithExpiryCheck(String key) async {
    final wrapped = await load(key);
    if (wrapped == null) return null;

    final expiry = wrapped['expiry'] as int?;
    if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
      await delete(key);
      return null;
    }

    return wrapped['data'] as Map<String, dynamic>?;
  }
}
