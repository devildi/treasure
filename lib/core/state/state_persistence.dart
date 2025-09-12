import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// 状态持久化接口
abstract class StatePersistence {
  factory StatePersistence() => _SharedPreferencesPersistence();

  /// 保存数据
  Future<void> save(String key, Map<String, dynamic> data);
  
  /// 加载数据
  Future<Map<String, dynamic>?> load(String key);
  
  /// 删除数据
  Future<void> delete(String key);
  
  /// 清除所有数据
  Future<void> clear();
  
  /// 检查数据是否存在
  Future<bool> exists(String key);
}

/// SharedPreferences实现
class _SharedPreferencesPersistence implements StatePersistence {
  static SharedPreferences? _prefs;
  
  Future<SharedPreferences> get prefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      final preferences = await prefs;
      await preferences.setString(key, jsonString);
      
      if (kDebugMode) {
        debugPrint('💾 状态已保存: $key');
      }
    } catch (e) {
      debugPrint('❌ 保存状态失败 [$key]: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final preferences = await prefs;
      final jsonString = preferences.getString(key);
      
      if (jsonString == null) {
        if (kDebugMode) {
          debugPrint('📂 状态不存在: $key');
        }
        return null;
      }
      
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (kDebugMode) {
        debugPrint('📖 状态已加载: $key');
      }
      
      return data;
    } catch (e) {
      debugPrint('❌ 加载状态失败 [$key]: $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final preferences = await prefs;
      await preferences.remove(key);
      
      if (kDebugMode) {
        debugPrint('🗑️ 状态已删除: $key');
      }
    } catch (e) {
      debugPrint('❌ 删除状态失败 [$key]: $e');
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final preferences = await prefs;
      await preferences.clear();
      
      if (kDebugMode) {
        debugPrint('🧹 所有状态已清除');
      }
    } catch (e) {
      debugPrint('❌ 清除状态失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      final preferences = await prefs;
      return preferences.containsKey(key);
    } catch (e) {
      debugPrint('❌ 检查状态存在性失败 [$key]: $e');
      return false;
    }
  }
}

/// 文件系统持久化实现（用于大数据量）
class FilePersistence implements StatePersistence {
  static const String _folderName = 'app_state';
  Directory? _stateDirectory;

  Future<Directory> get stateDirectory async {
    if (_stateDirectory != null) return _stateDirectory!;
    
    final appDocDir = await getApplicationDocumentsDirectory();
    _stateDirectory = Directory('${appDocDir.path}/$_folderName');
    
    if (!await _stateDirectory!.exists()) {
      await _stateDirectory!.create(recursive: true);
    }
    
    return _stateDirectory!;
  }

  File _getFile(String key) {
    final sanitizedKey = key.replaceAll(RegExp(r'[^\w\-_]'), '_');
    return File('${_stateDirectory!.path}/$sanitizedKey.json');
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    try {
      await stateDirectory; // 确保目录存在
      final file = _getFile(key);
      final jsonString = jsonEncode(data);
      
      await file.writeAsString(jsonString);
      
      if (kDebugMode) {
        debugPrint('💾 文件状态已保存: $key (${jsonString.length} bytes)');
      }
    } catch (e) {
      debugPrint('❌ 保存文件状态失败 [$key]: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      await stateDirectory; // 确保目录存在
      final file = _getFile(key);
      
      if (!await file.exists()) {
        if (kDebugMode) {
          debugPrint('📂 文件状态不存在: $key');
        }
        return null;
      }
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (kDebugMode) {
        debugPrint('📖 文件状态已加载: $key (${jsonString.length} bytes)');
      }
      
      return data;
    } catch (e) {
      debugPrint('❌ 加载文件状态失败 [$key]: $e');
      return null;
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await stateDirectory; // 确保目录存在
      final file = _getFile(key);
      
      if (await file.exists()) {
        await file.delete();
        
        if (kDebugMode) {
          debugPrint('🗑️ 文件状态已删除: $key');
        }
      }
    } catch (e) {
      debugPrint('❌ 删除文件状态失败 [$key]: $e');
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = await stateDirectory;
      
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
        
        if (kDebugMode) {
          debugPrint('🧹 所有文件状态已清除');
        }
      }
    } catch (e) {
      debugPrint('❌ 清除文件状态失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      await stateDirectory; // 确保目录存在
      final file = _getFile(key);
      return await file.exists();
    } catch (e) {
      debugPrint('❌ 检查文件状态存在性失败 [$key]: $e');
      return false;
    }
  }
}

/// 混合持久化策略：小数据用SharedPreferences，大数据用文件系统
class HybridPersistence implements StatePersistence {
  final StatePersistence _sharedPrefs = _SharedPreferencesPersistence();
  final StatePersistence _fileStorage = FilePersistence();
  
  static const int _fileSizeThreshold = 1024 * 50; // 50KB

  StatePersistence _getStorage(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    return jsonString.length > _fileSizeThreshold 
        ? _fileStorage 
        : _sharedPrefs;
  }

  @override
  Future<void> save(String key, Map<String, dynamic> data) async {
    final storage = _getStorage(data);
    await storage.save(key, data);
  }

  @override
  Future<Map<String, dynamic>?> load(String key) async {
    // 优先从SharedPreferences加载
    var data = await _sharedPrefs.load(key);
    if (data != null) return data;
    
    // 然后尝试从文件系统加载
    return await _fileStorage.load(key);
  }

  @override
  Future<void> delete(String key) async {
    // 从两个存储中都删除
    await Future.wait([
      _sharedPrefs.delete(key),
      _fileStorage.delete(key),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _sharedPrefs.clear(),
      _fileStorage.clear(),
    ]);
  }

  @override
  Future<bool> exists(String key) async {
    final results = await Future.wait([
      _sharedPrefs.exists(key),
      _fileStorage.exists(key),
    ]);
    
    return results.any((exists) => exists);
  }
}