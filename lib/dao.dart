import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/network/treasure_api.dart';
import 'package:treasure/core/network/network_exceptions.dart';
import 'package:treasure/core/config/app_config.dart';

class TreasureDao {
  static final TreasureApi _api = TreasureApi();
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      debugPrint('🔧 TreasureDao: 初始化API客户端...');
      debugPrint('🔧 TreasureDao: 开发模式 = ${AppConfig.isDevelopment}');
      _api.initialize(isDevelopMode: AppConfig.isDevelopment);
      _initialized = true;
      debugPrint('✅ TreasureDao: API客户端初始化完成');
    }
  }

  static Future register(Map<String, dynamic> data) async {
    _ensureInitialized();
    try {
      final response = await _api.register(data);
      if (response.isSuccess) {
        return response.data;
      } else {
        if (response.statusCode == 401) {
          return '授权码错误！';
        }
        return response.message;
      }
    } on NetworkException catch (e) {
      if (e is UnauthorizedException) {
        return '授权码错误！';
      }
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load data!');
    }
  }

  static Future login(Map<String, dynamic> data) async {
    _ensureInitialized();
    try {
      final response = await _api.login(data);
      if (response.isSuccess) {
        return response.data ?? OwnerModel();
      } else {
        return OwnerModel();
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      return OwnerModel();
    }
  }

  static Future getToken(String type) async {
    _ensureInitialized();
    try {
      final response = await _api.getToken(type);
      if (response.isSuccess) {
        return response.data;
      } else {
        throw Exception('Failed to get token');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }

  static Future poMicro(Map<String, dynamic> data) async {
    _ensureInitialized();
    try {
      final response = await _api.createToy(data);
      if (response.isSuccess) {
        return response.data;
      } else {
        throw Exception('Failed to create toy');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }

  static Future<AllToysModel> searchToies(String keyword, String uid) async {
    _ensureInitialized();
    try {
      final response = await _api.searchToys(keyword, uid);
      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception('Search failed');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }

  static Future<AllToysModel> getAllToies(int page, String uid) async {
    debugPrint('📡 TreasureDao.getAllToies: 开始请求 (page=$page, uid=$uid)');
    _ensureInitialized();

    try {
      debugPrint('📡 TreasureDao.getAllToies: 调用 _api.getAllToys...');
      final response = await _api.getAllToys(page, uid);
      debugPrint('📡 TreasureDao.getAllToies: API响应完成 (success=${response.isSuccess})');

      if (response.isSuccess) {
        debugPrint('✅ TreasureDao.getAllToies: 成功获取 ${response.data?.toyList.length ?? 0} 个物品');
        return response.data!;
      } else {
        debugPrint('❌ TreasureDao.getAllToies: 响应失败 - ${response.message}');
        throw Exception('Failed to get toys: ${response.message}');
      }
    } on NetworkException catch (e) {
      debugPrint('❌ TreasureDao.getAllToies: 网络异常 - ${e.message}');
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      debugPrint('❌ TreasureDao.getAllToies: 未知错误 - $e (${e.runtimeType})');
      throw Exception('NetWork Error: $e');
    }
  }

  static Future getTotalPriceAndCount(String uid) async {
    _ensureInitialized();
    try {
      final response = await _api.getTotalPriceAndCount(uid);
      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception('Failed to get total price and count');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }

  static Future modifyToy(Map<String, dynamic> data) async {
    _ensureInitialized();
    try {
      final response = await _api.modifyToy(data);
      if (response.isSuccess) {
        return response.data;
      } else {
        throw Exception('Failed to modify toy');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }

  static Future deleteToy(String id, String key) async {
    debugPrint('📡 TreasureDao.deleteToy: 开始删除 (id=$id, key=$key)');
    _ensureInitialized();

    try {
      debugPrint('📡 TreasureDao.deleteToy: 调用 _api.deleteToy...');
      final response = await _api.deleteToy(id, key);
      debugPrint('📡 TreasureDao.deleteToy: API响应完成 (success=${response.isSuccess})');

      if (response.isSuccess) {
        debugPrint('✅ TreasureDao.deleteToy: 删除成功');
        return response.data!;
      } else {
        debugPrint('❌ TreasureDao.deleteToy: 响应失败 - ${response.message}');
        throw Exception('Failed to delete toy: ${response.message}');
      }
    } on NetworkException catch (e) {
      debugPrint('❌ TreasureDao.deleteToy: 网络异常 - ${e.message}');
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      debugPrint('❌ TreasureDao.deleteToy: 未知错误 - $e (${e.runtimeType})');
      throw Exception('Delete Error: $e');
    }
  }

  /// 清除网络缓存
  static void clearNetworkCache() {
    try {
      debugPrint('🧹 TreasureDao: 开始清除网络缓存...');

      // 重新初始化API客户端，这会清除任何内存中的缓存
      _initialized = false;
      _ensureInitialized();

      debugPrint('✅ TreasureDao: 网络缓存已清除，API客户端已重新初始化');
    } catch (e) {
      debugPrint('⚠️ TreasureDao: 清除网络缓存失败 - $e');
    }
  }
}