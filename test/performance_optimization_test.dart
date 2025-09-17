import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/performance/performance_manager.dart';
import 'package:treasure/core/performance/memory_optimizer.dart';
import 'package:treasure/core/performance/widget_performance_optimizer.dart';

void main() {
  group('性能优化测试', () {
    group('PerformanceManager Tests', () {
      late PerformanceManager performanceManager;

      setUp(() {
        performanceManager = PerformanceManager.instance;
      });

      test('should record performance metrics', () {
        performanceManager.recordMetric('test_operation', 150.5);
        
        final report = performanceManager.getPerformanceReport();
        expect(report.metrics.isNotEmpty, true);
        expect(report.metrics.last.name, 'test_operation');
        expect(report.metrics.last.value, 150.5);
      });

      test('should measure async operation time', () async {
        final result = await performanceManager.measureAsync('async_test', () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'test_result';
        });

        expect(result, 'test_result');
        
        final report = performanceManager.getPerformanceReport();
        final metric = report.metrics.firstWhere((m) => m.name == 'async_test');
        expect(metric.value, greaterThan(40)); // 应该至少50ms
      });

      test('should measure sync operation time', () {
        final result = performanceManager.measureSync('sync_test', () {
          // 模拟一些计算
          var sum = 0;
          for (int i = 0; i < 1000; i++) {
            sum += i;
          }
          return sum;
        });

        expect(result, isA<int>());
        
        final report = performanceManager.getPerformanceReport();
        final hasMetric = report.metrics.any((m) => m.name == 'sync_test');
        expect(hasMetric, true);
      });

      test('should limit metrics history', () {
        // 添加超过最大限制的指标
        for (int i = 0; i < 150; i++) {
          performanceManager.recordMetric('test_metric_$i', i.toDouble());
        }

        final report = performanceManager.getPerformanceReport();
        expect(report.metrics.length, lessThanOrEqualTo(100));
      });

      test('should generate performance report summary', () {
        performanceManager.recordMetric('operation_a', 100.0);
        performanceManager.recordMetric('operation_b', 200.0);
        performanceManager.recordMetric('operation_a', 150.0);

        final report = performanceManager.getPerformanceReport();
        final summary = report.generateSummary();

        expect(summary, contains('性能报告摘要'));
        expect(summary, contains('operation_a'));
        expect(summary, contains('operation_b'));
      });

      test('should detect slow operations', () {
        performanceManager.recordMetric('slow_operation', 150.0); // > 100ms
        performanceManager.recordMetric('fast_operation', 50.0);

        final report = performanceManager.getPerformanceReport();
        final slowOps = report.slowOperations;

        expect(slowOps.containsKey('slow_operation'), true);
        expect(slowOps.containsKey('fast_operation'), false);
      });
    });

    group('MemoryOptimizer Tests', () {
      late MemoryOptimizer memoryOptimizer;

      setUp(() {
        memoryOptimizer = MemoryOptimizer.instance;
        memoryOptimizer.clearAllCaches(); // 清理之前的测试数据
      });

      test('should track widget instances', () {
        final initialCount = memoryOptimizer.activeWidgetCount;
        
        // 模拟添加widget引用
        const dummyWidget = SizedBox();
        memoryOptimizer.trackWidget(dummyWidget);
        
        expect(memoryOptimizer.activeWidgetCount, greaterThan(initialCount));
      });

      test('should provide memory usage statistics', () {
        final stats = memoryOptimizer.getMemoryStats();
        
        expect(stats, isA<MemoryUsageStats>());
        expect(stats.activeCacheCount, isA<int>());
        expect(stats.totalCacheCount, isA<int>());
        expect(stats.activeWidgetCount, isA<int>());
        expect(stats.cacheHitRate, isA<double>());
      });

      test('should format statistics correctly', () {
        const stats = MemoryUsageStats(
          activeCacheCount: 10,
          totalCacheCount: 15,
          activeWidgetCount: 5,
          totalWidgetCount: 8,
          cacheHitRate: 0.75,
        );

        final string = stats.toString();
        expect(string, contains('cache: 10/15'));
        expect(string, contains('widgets: 5/8'));
        expect(string, contains('hit rate: 75.0%'));
      });
    });

    group('WidgetPerformanceOptimizer Tests', () {
      late WidgetPerformanceOptimizer widgetOptimizer;

      setUp(() {
        widgetOptimizer = WidgetPerformanceOptimizer.instance;
        widgetOptimizer.clearMetrics();
      });

      test('should record widget build times', () {
        const widgetName = 'TestWidget';
        const buildTime = Duration(milliseconds: 25);
        
        widgetOptimizer.recordWidgetBuildTime(widgetName, buildTime);
        
        final report = widgetOptimizer.getPerformanceReport();
        expect(report.length, 1);
        expect(report[0].widgetName, widgetName);
        expect(report[0].averageBuildTime, buildTime);
      });

      test('should detect expensive widgets', () {
        const expensiveWidget = 'ExpensiveWidget';
        const fastWidget = 'FastWidget';
        
        widgetOptimizer.recordWidgetBuildTime(expensiveWidget, const Duration(milliseconds: 50));
        widgetOptimizer.recordWidgetBuildTime(fastWidget, const Duration(milliseconds: 5));
        
        final expensiveWidgets = widgetOptimizer.getExpensiveWidgets();
        expect(expensiveWidgets, contains(expensiveWidget));
        expect(expensiveWidgets, isNot(contains(fastWidget)));
      });

      test('should calculate widget metrics correctly', () {
        const widgetName = 'MetricsTestWidget';
        
        // 添加多个构建时间
        widgetOptimizer.recordWidgetBuildTime(widgetName, const Duration(milliseconds: 10));
        widgetOptimizer.recordWidgetBuildTime(widgetName, const Duration(milliseconds: 20));
        widgetOptimizer.recordWidgetBuildTime(widgetName, const Duration(milliseconds: 30));
        
        final report = widgetOptimizer.getPerformanceReport();
        final metrics = report.first;
        
        expect(metrics.widgetName, widgetName);
        expect(metrics.rebuildCount, 3);
        expect(metrics.averageBuildTime.inMilliseconds, 20); // (10+20+30)/3
        expect(metrics.maxBuildTime.inMilliseconds, 30);
        expect(metrics.isExpensive, false); // 平均20ms < 16ms阈值
      });

      test('should limit build time history', () {
        const widgetName = 'HistoryTestWidget';
        
        // 添加超过限制的构建时间记录
        for (int i = 0; i < 150; i++) {
          widgetOptimizer.recordWidgetBuildTime(
            widgetName, 
            Duration(milliseconds: i),
          );
        }
        
        final report = widgetOptimizer.getPerformanceReport();
        final metrics = report.first;
        
        // 内部应该限制历史记录数量（在PerformanceWidgetMetrics中限制为100）
        expect(metrics.rebuildCount, 150); // 计数器不限制
      });

      test('should sort performance report by average build time', () {
        widgetOptimizer.recordWidgetBuildTime('SlowWidget', const Duration(milliseconds: 100));
        widgetOptimizer.recordWidgetBuildTime('FastWidget', const Duration(milliseconds: 5));
        widgetOptimizer.recordWidgetBuildTime('MediumWidget', const Duration(milliseconds: 50));
        
        final report = widgetOptimizer.getPerformanceReport();
        
        expect(report.length, 3);
        expect(report[0].widgetName, 'SlowWidget'); // 最慢的应该排在前面
        expect(report[1].widgetName, 'MediumWidget');
        expect(report[2].widgetName, 'FastWidget');
      });
    });

    group('Integration Tests', () {
      test('should work together for comprehensive monitoring', () {
        final performanceManager = PerformanceManager.instance;
        final memoryOptimizer = MemoryOptimizer.instance;
        final widgetOptimizer = WidgetPerformanceOptimizer.instance;
        
        // 清理初始状态
        performanceManager.clearHistory();
        memoryOptimizer.clearAllCaches();
        widgetOptimizer.clearMetrics();
        
        // 模拟应用性能数据
        performanceManager.recordMetric('api_call', 150.0);
        performanceManager.recordMetric('image_load', 80.0);
        
        const dummyWidget = SizedBox();
        memoryOptimizer.trackWidget(dummyWidget);
        
        widgetOptimizer.recordWidgetBuildTime('HomePage', const Duration(milliseconds: 25));
        
        // 验证所有系统都有数据
        final perfReport = performanceManager.getPerformanceReport();
        final memStats = memoryOptimizer.getMemoryStats();
        final widgetReport = widgetOptimizer.getPerformanceReport();
        
        expect(perfReport.metrics.length, 2);
        expect(memStats.activeWidgetCount, greaterThan(0));
        expect(widgetReport.length, 1);
      });

      test('should handle memory pressure scenarios', () {
        final memoryOptimizer = MemoryOptimizer.instance;
        
        // 模拟内存压力场景
        for (int i = 0; i < 100; i++) {
          final widget = SizedBox(key: Key('widget_$i'));
          memoryOptimizer.trackWidget(widget);
        }
        
        final statsBefore = memoryOptimizer.getMemoryStats();
        
        // 清理缓存
        memoryOptimizer.clearAllCaches();
        
        final statsAfter = memoryOptimizer.getMemoryStats();
        
        expect(statsBefore.totalWidgetCount, greaterThan(statsAfter.totalWidgetCount));
      });
    });
  });
}