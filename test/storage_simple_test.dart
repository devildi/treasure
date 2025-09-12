import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/storage/storage_service.dart';
import 'package:treasure/core/storage/storage_manager.dart';

void main() {
  group('存储优化基础测试', () {
    test('should create storage service instance', () {
      final service = StorageService.instance;
      expect(service, isNotNull);
    });

    test('should format storage sizes correctly', () {
      expect(StorageCleanupManager.formatSize(500), '500B');
      expect(StorageCleanupManager.formatSize(1536), '1.5KB');
      expect(StorageCleanupManager.formatSize(2097152), '2.0MB');
    });

    test('should create storage stats object', () {
      const stats = StorageStats(
        cacheSize: 1024,
        dataSize: 2048,
        totalSize: 3072,
        maxSize: 10240,
        offlineItems: 10,
        usage: 0.3,
      );

      expect(stats.formattedCacheSize, '1.0KB');
      expect(stats.formattedDataSize, '2.0KB');
      expect(stats.formattedTotalSize, '3.0KB');
      expect(stats.isLowSpace, false);
      expect(stats.isCriticalSpace, false);
      expect(stats.usageText, '存储空间充足');
    });

    test('should create offline data status object', () {
      const status = OfflineDataStatus(
        totalItems: 0,
        lastSyncTime: null,
        isStale: true,
      );

      expect(status.statusText, '无离线数据');
      expect(status.totalItems, 0);
      expect(status.isStale, true);
    });

    test('should handle storage warnings correctly', () {
      const lowSpaceStats = StorageStats(
        cacheSize: 8000,
        dataSize: 2000,
        totalSize: 10000,
        maxSize: 10240,
        offlineItems: 100,
        usage: 0.85, // 85% usage
      );

      expect(lowSpaceStats.isLowSpace, true);
      expect(lowSpaceStats.isCriticalSpace, false);
      expect(lowSpaceStats.usageText, '存储空间不足');

      const criticalSpaceStats = StorageStats(
        cacheSize: 9500,
        dataSize: 1000,
        totalSize: 10500,
        maxSize: 10240,
        offlineItems: 200,
        usage: 0.97, // 97% usage
      );

      expect(criticalSpaceStats.isLowSpace, true);
      expect(criticalSpaceStats.isCriticalSpace, true);
      expect(criticalSpaceStats.usageText, '存储空间严重不足');
    });
  });
}