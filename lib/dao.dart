import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/storage/storage_manager.dart';
// import 'package:treasure/core/network/treasure_api.dart';
// import 'package:treasure/core/network/network_exceptions.dart';
// import 'package:treasure/core/config/app_config.dart';

class TreasureDao {
  // 【单机模式】注释掉远端 API 客户端
  // static final TreasureApi _api = TreasureApi();
  // static bool _initialized = false;

  // 【单机模式】注释掉无需调用的 _ensureInitialized
  /*
  static void _ensureInitialized() {
  }
  */

  // 【单机模式】本地数据缓存列表
  static final List<ToyModel> _memoryToys = [];
  static bool _isLoadedFromDisk = false;

  static Future<void> _ensureLoaded() async {
    if (!_isLoadedFromDisk) {
      try {
        final offlineToys = await OfflineDataManager().getOfflineToys();
        _memoryToys.clear();
        _memoryToys.addAll(offlineToys);
        _memoryToys.sort((a, b) => b.createAt.compareTo(a.createAt));
        _isLoadedFromDisk = true;
      } catch (e) {
        debugPrint('⚠️ [单机模式] 读取本地玩具数据异常: $e');
      }
    }
  }

  /// 重新从本地存储加载内存数据（例如数据同步完成后）
  static Future<void> reloadFromStorage() async {
    _isLoadedFromDisk = false;
    await _ensureLoaded();
  }

  /// 获取当前所有玩具列表（已加载）
  static Future<List<ToyModel>> getAllToys() async {
    await _ensureLoaded();
    return List<ToyModel>.from(_memoryToys);
  }

  static Future register(Map<String, dynamic> data) async {
    // 【单机模式】已注释掉网络请求，返回模拟账号桩数据
    /*
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
    */
    return OwnerModel(
      uid: 'local_user',
      name: data['name'] ?? '本地用户',
      avatar: '',
    );
  }

  static Future login(Map<String, dynamic> data) async {
    // 【单机模式】已注释掉网络请求，返回模拟登录桩数据
    /*
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
    */
    return OwnerModel(
      uid: 'local_user',
      name: data['name'] ?? '本地用户',
      avatar: '',
    );
  }

  static Future<String> getToken(String type) async {
    // 【单机模式】已注释掉网络请求，返回本地虚拟 token
    /*
    _ensureInitialized();
    try {
      final response = await _api.getToken(type);
      if (response.isSuccess) {
        final token = _extractUploadToken(response.data);
        if (token != null && token.isNotEmpty) {
          return token;
        }
        throw Exception('Invalid upload token payload');
      } else {
        throw Exception('Failed to get token: ${response.message}');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
    */
    return 'local_mock_token:mock';
  }

  static Future poMicro(Map<String, dynamic> data) async {
    // 【单机模式】已注释掉网络发布请求，实现本地单机存储
    /*
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
    */
    debugPrint('📝 [单机模式] TreasureDao.poMicro: 收到发布数据: $data');
    if (data.isEmpty) {
      return {'status': 'success', 'data': data};
    }

    await _ensureLoaded();
    final newToy = ToyModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      toyName: data['toyName'] ?? '',
      toyPicUrl: data['toyPicUrl'] ?? '',
      localUrl: data['toyPicUrl'] ?? '',
      picWidth: data['picWidth'] ?? 300,
      picHeight: data['picHeight'] ?? 300,
      description: data['description'] ?? '',
      labels: data['labels'] ?? '',
      owner: OwnerModel(
        uid: data['owner'] ?? 'local_user',
        name: data['ownerName'] ?? '玩具收藏家',
        avatar: data['ownerAvatar'] ?? '',
      ),
      price: data['price'] ?? 0,
      sellPrice: data['sellPrice'] ?? 0,
      createAt: data['createAt'] ?? DateTime.now().toIso8601String(),
      sellAt: '',
      isSelled: false,
    );

    _memoryToys.insert(0, newToy);

    try {
      await OfflineDataManager().saveToyForOffline(newToy);
      debugPrint('💾 [单机模式] 玩具已持久化保存: ${newToy.toyName} (id: ${newToy.id})');
    } catch (e) {
      debugPrint('⚠️ [单机模式] 保存离线玩具异常: $e');
    }

    return {'status': 'success', 'data': newToy.toJson()};
  }

  static Future<AllToysModel> searchToies(String keyword, String uid) async {
    // 【单机模式】已注释掉网络搜索，实现本地单机搜索
    /*
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
    */
    debugPrint('🔍 [单机模式] TreasureDao.searchToies: 搜索 "$keyword"');
    await _ensureLoaded();
    if (keyword.isEmpty) {
      return AllToysModel(toyList: List<ToyModel>.from(_memoryToys));
    }
    final lower = keyword.toLowerCase();
    final results = _memoryToys.where((toy) {
      return toy.toyName.toLowerCase().contains(lower) ||
          toy.description.toLowerCase().contains(lower) ||
          toy.labels.toLowerCase().contains(lower);
    }).toList();
    return AllToysModel(toyList: results);
  }

  static Future<AllToysModel> getAllToies(int page, String uid) async {
    // 【单机模式】已注释掉网络请求，实现本地单机加载
    /*
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
    */
    debugPrint('📦 [单机模式] TreasureDao.getAllToies: 读取第 $page 页');
    await _ensureLoaded();
    return AllToysModel(toyList: List<ToyModel>.from(_memoryToys));
  }

  static Future getTotalPriceAndCount(String uid) async {
    // 【单机模式】已注释掉网络统计请求，实现本地单机统计
    /*
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
    */
    debugPrint('📊 [单机模式] TreasureDao.getTotalPriceAndCount: 读取总览统计');
    await _ensureLoaded();
    double total = 0.0;
    for (var toy in _memoryToys) {
      total += toy.price.toDouble();
    }
    return PriceCountModel(totalPrice: total, count: _memoryToys.length);
  }

  static Future modifyToy(Map<String, dynamic> data) async {
    // 【单机模式】已注释掉网络修改请求，实现本地单机修改
    /*
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
    */
    debugPrint('✏️ [单机模式] TreasureDao.modifyToy: 修改数据: $data');
    await _ensureLoaded();
    final id = data['_id'] ?? data['id'];
    if (id != null) {
      final index = _memoryToys.indexWhere((t) => t.id == id);
      if (index >= 0) {
        final existing = _memoryToys[index];
        final updated = ToyModel(
          id: existing.id,
          toyName: data['toyName'] ?? existing.toyName,
          toyPicUrl: data['toyPicUrl'] ?? existing.toyPicUrl,
          localUrl: data['localUrl'] ?? existing.localUrl,
          picWidth: data['picWidth'] ?? existing.picWidth,
          picHeight: data['picHeight'] ?? existing.picHeight,
          description: data['description'] ?? existing.description,
          labels: data['labels'] ?? existing.labels,
          owner: existing.owner,
          price: data['price'] ?? existing.price,
          sellPrice: data['sellPrice'] ?? existing.sellPrice,
          createAt: existing.createAt,
          sellAt: data['sellAt'] ?? existing.sellAt,
          isSelled: data['isSelled'] ?? existing.isSelled,
        );
        _memoryToys[index] = updated;
        try {
          await OfflineDataManager().saveToyForOffline(updated);
        } catch (e) {
          debugPrint('⚠️ [单机模式] 修改离线玩具异常: $e');
        }
      }
    }
    return {'status': 'success'};
  }

  static Future deleteToy(String id, String key) async {
    // 【单机模式】已注释掉网络删除请求，实现本地单机删除
    /*
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
    */
    debugPrint('🗑️ [单机模式] TreasureDao.deleteToy: 删除 $id');
    await _ensureLoaded();
    _memoryToys.removeWhere((t) => t.id == id);
    try {
      await OfflineDataManager().removeOfflineToy(id);
    } catch (e) {
      debugPrint('⚠️ [单机模式] 删除离线玩具异常: $e');
    }
    return ResultModel(ok: 1, n: 1, deletedCount: 1);
  }

  /// 清除网络缓存
  static void clearNetworkCache() {
    // 【单机模式】无需清除远端网络缓存
    debugPrint('🧹 [单机模式] TreasureDao: 网络缓存已被忽略');
  }
}
