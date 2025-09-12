import 'package:treasure/toy_model.dart';
import 'api_client.dart';
import 'api_response.dart';

class TreasureApi {
  static final TreasureApi _instance = TreasureApi._internal();
  factory TreasureApi() => _instance;
  TreasureApi._internal();

  final ApiClient _apiClient = ApiClient();

  void initialize({
    required bool isDevelopMode,
    String? baseUrl,
  }) {
    final url = baseUrl ?? 
        (isDevelopMode ? 'http://172.20.10.13:4000/' : 'https://nextsticker.cn/');
    
    _apiClient.initialize(
      baseUrl: url,
      connectTimeout: 15000,
      receiveTimeout: 15000,
      sendTimeout: 15000,
    );
  }

  // Authentication APIs
  Future<ApiResponse<OwnerModel>> register(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<dynamic>(
        'api/treasure/register',
        data: data,
      );
      
      if (response.isSuccess && response.data != null) {
        if (response.data == '此用户名已经注册！') {
          return ApiResponse.error(
            statusCode: 409,
            message: '此用户名已经注册！',
          );
        } else if (response.data == '未授权！') {
          return ApiResponse.error(
            statusCode: 401,
            message: '未授权！',
          );
        } else {
          final user = OwnerModel.fromJson(response.data as Map<String, dynamic>);
          return ApiResponse.success(
            data: user,
            statusCode: response.statusCode,
            message: '注册成功',
          );
        }
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<OwnerModel>> login(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<dynamic>(
        'api/treasure/login',
        data: data,
      );
      
      if (response.isSuccess) {
        if (response.data == null || response.data == '') {
          return ApiResponse.success(
            data: OwnerModel(),
            statusCode: response.statusCode,
            message: '登录失败',
          );
        } else {
          final user = OwnerModel.fromJson(response.data as Map<String, dynamic>);
          return ApiResponse.success(
            data: user,
            statusCode: response.statusCode,
            message: '登录成功',
          );
        }
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  // Token APIs
  Future<ApiResponse<dynamic>> getToken(String type) async {
    try {
      final response = await _apiClient.get<dynamic>(
        'api/trip/getUploadToken',
        queryParameters: {'type': type},
      );
      
      return response;
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  // Toy APIs
  Future<ApiResponse<AllToysModel>> getAllToys(int page, String uid) async {
    try {
      final response = await _apiClient.get<dynamic>(
        'api/treasure/getAllTreasures',
        queryParameters: {'page': page, 'uid': uid},
        fromJson: (data) => AllToysModel.fromJson(data as List),
      );
      
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          data: response.data as AllToysModel,
          statusCode: response.statusCode,
          message: response.message,
        );
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<PriceCountModel>> getTotalPriceAndCount(String uid) async {
    try {
      final response = await _apiClient.get<dynamic>(
        'api/treasure/getTotalPriceAndCount',
        queryParameters: {'uid': uid},
        fromJson: (data) => PriceCountModel.fromJson(data as Map<String, dynamic>),
      );
      
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          data: response.data as PriceCountModel,
          statusCode: response.statusCode,
          message: response.message,
        );
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<AllToysModel>> searchToys(String keyword, String uid) async {
    try {
      final response = await _apiClient.get<dynamic>(
        'api/treasure/search',
        queryParameters: {'keyword': keyword, 'uid': uid},
        fromJson: (data) => AllToysModel.fromJson(data as List),
      );
      
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          data: response.data as AllToysModel,
          statusCode: response.statusCode,
          message: response.message,
        );
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<dynamic>> createToy(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<dynamic>(
        'api/treasure/newItem',
        data: data,
      );
      
      return response;
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<dynamic>> modifyToy(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post<dynamic>(
        'api/treasure/modify',
        data: data,
      );
      
      return response;
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }

  Future<ApiResponse<ResultModel>> deleteToy(String id, String key) async {
    try {
      final response = await _apiClient.post<dynamic>(
        'api/treasure/delete',
        data: {'id': id, 'key': key},
        fromJson: (data) => ResultModel.fromJson(data as Map<String, dynamic>),
      );
      
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          data: response.data as ResultModel,
          statusCode: response.statusCode,
          message: response.message,
        );
      }
      
      return ApiResponse.error(
        statusCode: response.statusCode,
        message: response.message,
      );
    } catch (e) {
      return ApiResponse.error(
        statusCode: 500,
        message: e.toString(),
      );
    }
  }
}