import 'dart:async';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/network/treasure_api.dart';
import 'package:treasure/core/network/network_exceptions.dart';
import 'package:treasure/core/config/app_config.dart';

class TreasureDao {
  static final TreasureApi _api = TreasureApi();
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (!_initialized) {
      _api.initialize(isDevelopMode: AppConfig.isDevelopment);
      _initialized = true;
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
    _ensureInitialized();
    try {
      final response = await _api.getAllToys(page, uid);
      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception('Failed to get toys');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
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
    _ensureInitialized();
    try {
      final response = await _api.deleteToy(id, key);
      if (response.isSuccess) {
        return response.data!;
      } else {
        throw Exception('Failed to delete toy');
      }
    } on NetworkException catch (e) {
      throw Exception('Network Error: ${e.message}');
    } catch (e) {
      throw Exception('NetWork Error!');
    }
  }
}