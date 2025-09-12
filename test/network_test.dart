import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/network/api_response.dart';
import 'package:treasure/core/network/network_exceptions.dart';
import 'package:treasure/core/network/treasure_api.dart';
import 'package:treasure/toy_model.dart';

void main() {
  group('Network Layer Tests', () {
    late TreasureApi api;

    setUp(() {
      api = TreasureApi();
      // Initialize with test configuration
      api.initialize(isDevelopMode: true);
    });

    group('ApiResponse Tests', () {
      test('should create successful response', () {
        const testData = 'test data';
        const statusCode = 200;
        const message = 'Success';

        final response = ApiResponse<String>.success(
          data: testData,
          statusCode: statusCode,
          message: message,
        );

        expect(response.isSuccess, true);
        expect(response.isError, false);
        expect(response.data, testData);
        expect(response.statusCode, statusCode);
        expect(response.message, message);
      });

      test('should create error response', () {
        const statusCode = 400;
        const message = 'Bad Request';

        final response = ApiResponse<String>.error(
          statusCode: statusCode,
          message: message,
        );

        expect(response.isSuccess, false);
        expect(response.isError, true);
        expect(response.data, null);
        expect(response.statusCode, statusCode);
        expect(response.message, message);
      });
    });

    group('Network Exceptions Tests', () {
      test('ConnectionTimeoutException should have correct message', () {
        final exception = ConnectionTimeoutException();
        expect(exception.message, '连接超时，请检查网络连接');
        expect(exception.statusCode, null);
      });

      test('ServerException should have correct status code and message', () {
        const statusCode = 500;
        const message = '服务器内部错误';
        
        final exception = ServerException(
          statusCode: statusCode,
          message: message,
        );
        
        expect(exception.statusCode, statusCode);
        expect(exception.message, message);
      });

      test('UnauthorizedException should have correct status code', () {
        final exception = UnauthorizedException();
        expect(exception.statusCode, 401);
        expect(exception.message, '未授权访问，请重新登录');
      });
    });

    group('Data Model Tests', () {
      test('OwnerModel should serialize and deserialize correctly', () {
        final originalModel = OwnerModel(
          name: 'Test User',
          uid: '123456',
          avatar: 'avatar_url',
          family: 'Test Family',
        );

        final json = originalModel.toJson();
        final deserializedModel = OwnerModel.fromJson(json);

        expect(deserializedModel.name, originalModel.name);
        expect(deserializedModel.uid, originalModel.uid);
        expect(deserializedModel.avatar, originalModel.avatar);
        expect(deserializedModel.family, originalModel.family);
      });

      test('PriceCountModel should handle numeric values correctly', () {
        const totalPrice = 1500.50;
        const count = 10;

        final model = PriceCountModel(
          totalPrice: totalPrice,
          count: count,
        );

        final json = model.toJson();
        final deserializedModel = PriceCountModel.fromJson(json);

        expect(deserializedModel.totalPrice, totalPrice);
        expect(deserializedModel.count, count);
      });

      test('ToyModel should handle null values gracefully', () {
        final jsonWithNulls = {
          '_id': '123',
          'toyName': 'Test Toy',
          'owner': null,
          'price': null,
          'sellPrice': null,
          'isSelled': null,
          'createAt': null,
          'sellAt': null,
        };

        expect(() => ToyModel.fromJson(jsonWithNulls), returnsNormally);
      });
    });
  });

  group('Integration Tests', () {
    // These would be integration tests that require network connectivity
    // They should be run separately from unit tests
    
    test('should handle network timeout gracefully', () async {
      // This test would simulate network timeout scenarios
      // Implementation would depend on your testing strategy
    }, skip: 'Integration test - run separately');

    test('should cache responses correctly', () async {
      // This test would verify caching behavior
      // Implementation would depend on your testing strategy
    }, skip: 'Integration test - run separately');
  });
}