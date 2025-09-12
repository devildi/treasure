import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/storage/storage_manager.dart';
import 'package:treasure/core/storage/storage_service.dart';
import 'package:treasure/toy_model.dart';

void main() {
  group('本地存储优化测试', () {
    group('CacheManager Tests', () {
      late CacheManager cacheManager;

      setUp(() {
        cacheManager = CacheManager();
      });

      test('should save and load cache data', () async {
        const testData = {'key': 'value', 'number': 42};
        const cacheKey = 'test_cache';

        await cacheManager.saveCache(cacheKey, testData);
        final loadedData = await cacheManager.loadCache<Map<String, dynamic>>(cacheKey);

        expect(loadedData, isNotNull);
        expect(loadedData!['key'], 'value');
        expect(loadedData['number'], 42);
      });

      test('should handle cache expiry', () async {
        const testData = {'test': 'expired'};
        const cacheKey = 'expiry_test';

        await cacheManager.saveCache(
          cacheKey, 
          testData,
          expiry: const Duration(milliseconds: 100),
        );

        // 等待过期
        await Future.delayed(const Duration(milliseconds: 150));

        final loadedData = await cacheManager.loadCache(cacheKey);
        expect(loadedData, isNull);
      });

      test('should support data compression', () async {
        // 创建较大的测试数据
        final largeData = List.generate(1000, (i) => 'item_$i');
        const cacheKey = 'compression_test';

        await cacheManager.saveCache(
          cacheKey,
          {'data': largeData},
          compress: true,
        );

        final loadedData = await cacheManager.loadCache<Map<String, dynamic>>(cacheKey);
        expect(loadedData, isNotNull);
        expect((loadedData!['data'] as List).length, 1000);
      });
    });

    group('OfflineDataManager Tests', () {
      late OfflineDataManager offlineManager;

      setUp(() {
        offlineManager = OfflineDataManager();
      });

      test('should save and retrieve offline toys', () async {
        final testToy = ToyModel(
          id: 'test_001',
          toyName: 'Test Toy',
          toyPicUrl: 'https://example.com/toy.jpg',
          picWidth: 100,
          picHeight: 100,
          description: 'Test Description',
          labels: 'test,toy',
          owner: OwnerModel(uid: 'test_user'),
          price: 100,
          sellPrice: 80,
          createAt: '2025-01-01',
          sellAt: '',
          isSelled: false,
        );

        await offlineManager.saveToyForOffline(testToy);
        final offlineToys = await offlineManager.getOfflineToys();

        expect(offlineToys.length, 1);
        expect(offlineToys[0].id, 'test_001');
        expect(offlineToys[0].toyName, 'Test Toy');
      });

      test('should search offline toys', () async {
        final toys = [
          ToyModel(
            id: 'toy_1',
            toyName: 'Red Car',
            toyPicUrl: '',
            picWidth: 0,
            picHeight: 0,
            description: 'A red toy car',
            labels: 'car,red',
            owner: OwnerModel(),
            price: 50,
            sellPrice: 40,
            createAt: '2025-01-01',
            sellAt: '',
            isSelled: false,
          ),
          ToyModel(
            id: 'toy_2',
            toyName: 'Blue Ball',
            toyPicUrl: '',
            picWidth: 0,
            picHeight: 0,
            description: 'A blue rubber ball',
            labels: 'ball,blue',
            owner: OwnerModel(),
            price: 20,
            sellPrice: 15,
            createAt: '2025-01-01',
            sellAt: '',
            isSelled: false,
          ),
        ];

        await offlineManager.saveToysForOffline(toys);
        
        final carResults = await offlineManager.searchOfflineToys('car');
        expect(carResults.length, 1);
        expect(carResults[0].toyName, 'Red Car');
        
        final blueResults = await offlineManager.searchOfflineToys('blue');
        expect(blueResults.length, 1);
        expect(blueResults[0].toyName, 'Blue Ball');
      });

      test('should get offline status', () async {
        final initialStatus = await offlineManager.getOfflineStatus();
        expect(initialStatus['totalItems'], 0);

        // 添加一些测试数据
        final testToy = ToyModel(
          id: 'status_test',
          toyName: 'Status Test Toy',
          toyPicUrl: '',
          picWidth: 0,
          picHeight: 0,
          description: '',
          labels: '',
          owner: OwnerModel(),
          price: 100,
          sellPrice: 80,
          createAt: '2025-01-01',
          sellAt: '',
          isSelled: false,
        );

        await offlineManager.saveToyForOffline(testToy);
        
        final updatedStatus = await offlineManager.getOfflineStatus();
        expect(updatedStatus['totalItems'], 1);
        expect(updatedStatus['lastSyncTime'], isNotNull);
      });
    });

    group('StorageCleanupManager Tests', () {
      late StorageCleanupManager cleanupManager;

      setUp(() {
        cleanupManager = StorageCleanupManager();
      });

      test('should get storage statistics', () async {
        final stats = await cleanupManager.getStorageStats();
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('cacheSize'), true);
        expect(stats.containsKey('dataSize'), true);
        expect(stats.containsKey('totalSize'), true);
        expect(stats.containsKey('usage'), true);
      });

      test('should format file sizes correctly', () {
        expect(StorageCleanupManager.formatSize(500), '500B');
        expect(StorageCleanupManager.formatSize(1536), '1.5KB'); // 1.5 * 1024
        expect(StorageCleanupManager.formatSize(2097152), '2.0MB'); // 2 * 1024 * 1024
      });
    });

    group('StorageService Integration Tests', () {
      test('should handle API response caching', () async {
        final service = StorageService.instance;
        
        const endpoint = 'test_api';
        const response = {'data': 'test', 'status': 'ok'};
        
        await service.cacheApiResponse(endpoint, response);
        final cachedResponse = await service.getCachedApiResponse(endpoint);
        
        expect(cachedResponse, isNotNull);
        expect(cachedResponse!['data'], 'test');
        expect(cachedResponse['status'], 'ok');
      });

      test('should handle search result caching', () async {
        final service = StorageService.instance;
        
        final testToys = [
          ToyModel(
            id: 'search_1',
            toyName: 'Search Test 1',
            toyPicUrl: '',
            picWidth: 0,
            picHeight: 0,
            description: '',
            labels: '',
            owner: OwnerModel(),
            price: 100,
            sellPrice: 80,
            createAt: '2025-01-01',
            sellAt: '',
            isSelled: false,
          ),
        ];
        
        const query = 'search test';
        await service.cacheSearchResults(query, testToys);
        
        final cachedResults = await service.getCachedSearchResults(query);
        expect(cachedResults, isNotNull);
        expect(cachedResults!.length, 1);
        expect(cachedResults[0].toyName, 'Search Test 1');
      });

      test('should manage storage settings', () async {
        final service = StorageService.instance;
        
        await service.saveSetting('test_bool', true);
        await service.saveSetting('test_int', 42);
        await service.saveSetting('test_string', 'hello');
        
        expect(service.getSetting<bool>('test_bool'), true);
        expect(service.getSetting<int>('test_int'), 42);
        expect(service.getSetting<String>('test_string'), 'hello');
        
        // 测试默认值
        expect(service.getSetting<bool>('non_existent', defaultValue: false), false);
      });
    });

    group('Performance and Edge Cases', () {
      test('should handle large data sets efficiently', () async {
        final cacheManager = CacheManager();
        
        // 测试大量数据
        final largeDataSet = List.generate(10000, (i) => {
          'id': i,
          'name': 'Item $i',
          'data': List.generate(10, (j) => 'data_${i}_$j'),
        });
        
        final startTime = DateTime.now();
        await cacheManager.saveCache('large_dataset', largeDataSet, compress: true);
        final saveTime = DateTime.now().difference(startTime);
        
        final loadStartTime = DateTime.now();
        final loaded = await cacheManager.loadCache('large_dataset');
        final loadTime = DateTime.now().difference(loadStartTime);
        
        expect(loaded, isNotNull);
        expect((loaded as List).length, 10000);
        expect(saveTime.inMilliseconds, lessThan(5000)); // 应该在5秒内完成
        expect(loadTime.inMilliseconds, lessThan(2000)); // 应该在2秒内完成
      });

      test('should handle concurrent operations', () async {
        final cacheManager = CacheManager();
        
        // 并发保存多个缓存
        final futures = List.generate(10, (i) => 
          cacheManager.saveCache('concurrent_$i', {'index': i, 'data': 'test_$i'})
        );
        
        await Future.wait(futures);
        
        // 验证所有数据都正确保存
        for (int i = 0; i < 10; i++) {
          final data = await cacheManager.loadCache<Map<String, dynamic>>('concurrent_$i');
          expect(data, isNotNull);
          expect(data!['index'], i);
          expect(data['data'], 'test_$i');
        }
      });

      test('should handle storage limit gracefully', () async {
        final offlineManager = OfflineDataManager();
        
        // 测试超出存储限制的情况
        final toys = List.generate(600, (i) => ToyModel( // 超过maxOfflineItems
          id: 'limit_test_$i',
          toyName: 'Toy $i',
          toyPicUrl: '',
          picWidth: 0,
          picHeight: 0,
          description: '',
          labels: '',
          owner: OwnerModel(),
          price: 100,
          sellPrice: 80,
          createAt: DateTime.now().subtract(Duration(days: i)).toIso8601String(),
          sellAt: '',
          isSelled: false,
        ));
        
        await offlineManager.saveToysForOffline(toys);
        final savedToys = await offlineManager.getOfflineToys();
        
        // 应该不超过最大限制
        expect(savedToys.length, lessThanOrEqualTo(StorageManager.maxOfflineItems));
        
        // 应该保留最新的数据
        expect(savedToys.first.toyName, contains('Toy'));
      });
    });
  });
}