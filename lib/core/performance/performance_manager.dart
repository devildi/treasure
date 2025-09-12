import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 性能管理器 - 监控和优化应用性能
class PerformanceManager {
  static PerformanceManager? _instance;
  static PerformanceManager get instance => _instance ??= PerformanceManager._();
  
  PerformanceManager._();
  
  Timer? _memoryMonitorTimer;
  Timer? _performanceLogTimer;
  final List<PerformanceMetric> _metrics = [];
  final List<MemorySnapshot> _memorySnapshots = [];
  
  // 性能监控配置
  static const Duration memoryCheckInterval = Duration(seconds: 30);
  static const Duration performanceLogInterval = Duration(minutes: 5);
  static const int maxMetricsHistory = 100;
  static const int maxMemorySnapshots = 50;
  
  // 内存警告阈值
  static const double memoryWarningThreshold = 0.8; // 80%
  static const double memoryCriticalThreshold = 0.9; // 90%
  
  bool _isMonitoring = false;
  VoidCallback? _onMemoryWarning;
  VoidCallback? _onMemoryCritical;
  
  /// 开始性能监控
  void startMonitoring({
    VoidCallback? onMemoryWarning,
    VoidCallback? onMemoryCritical,
  }) {
    if (_isMonitoring) return;
    
    _onMemoryWarning = onMemoryWarning;
    _onMemoryCritical = onMemoryCritical;
    _isMonitoring = true;
    
    // 开始内存监控
    _memoryMonitorTimer = Timer.periodic(memoryCheckInterval, (_) => _checkMemoryUsage());
    
    // 开始性能日志记录
    if (kDebugMode) {
      _performanceLogTimer = Timer.periodic(performanceLogInterval, (_) => _logPerformanceMetrics());
    }
    
    if (kDebugMode) {
      debugPrint('🚀 性能监控已启动');
    }
  }
  
  /// 停止性能监控
  void stopMonitoring() {
    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    _performanceLogTimer?.cancel();
    _memoryMonitorTimer = null;
    _performanceLogTimer = null;
    
    if (kDebugMode) {
      debugPrint('⏹️ 性能监控已停止');
    }
  }
  
  /// 记录性能指标
  void recordMetric(String name, double value, {String? unit, Map<String, dynamic>? metadata}) {
    final metric = PerformanceMetric(
      name: name,
      value: value,
      unit: unit ?? 'ms',
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );
    
    _metrics.add(metric);
    
    // 限制历史记录数量
    if (_metrics.length > maxMetricsHistory) {
      _metrics.removeAt(0);
    }
    
    if (kDebugMode && value > 100) { // 记录慢操作
      debugPrint('⚠️ 慢操作检测: $name = ${value.toStringAsFixed(1)}$unit');
    }
  }
  
  /// 测量代码块执行时间
  Future<T> measureAsync<T>(String name, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      recordMetric(name, stopwatch.elapsedMilliseconds.toDouble());
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric(name, stopwatch.elapsedMilliseconds.toDouble(), metadata: {'error': e.toString()});
      rethrow;
    }
  }
  
  /// 测量同步代码块执行时间
  T measureSync<T>(String name, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    try {
      final result = operation();
      stopwatch.stop();
      recordMetric(name, stopwatch.elapsedMilliseconds.toDouble());
      return result;
    } catch (e) {
      stopwatch.stop();
      recordMetric(name, stopwatch.elapsedMilliseconds.toDouble(), metadata: {'error': e.toString()});
      rethrow;
    }
  }
  
  /// 检查内存使用情况
  Future<void> _checkMemoryUsage() async {
    try {
      final info = await _getMemoryInfo();
      final snapshot = MemorySnapshot(
        timestamp: DateTime.now(),
        usedMemory: info['usedMemory'] ?? 0,
        totalMemory: info['totalMemory'] ?? 0,
        availableMemory: info['availableMemory'] ?? 0,
      );
      
      _memorySnapshots.add(snapshot);
      
      // 限制快照数量
      if (_memorySnapshots.length > maxMemorySnapshots) {
        _memorySnapshots.removeAt(0);
      }
      
      // 检查内存警告
      final usage = snapshot.memoryUsageRatio;
      if (usage >= memoryCriticalThreshold) {
        _onMemoryCritical?.call();
        if (kDebugMode) {
          debugPrint('🚨 内存使用率危险: ${(usage * 100).toStringAsFixed(1)}%');
        }
      } else if (usage >= memoryWarningThreshold) {
        _onMemoryWarning?.call();
        if (kDebugMode) {
          debugPrint('⚠️ 内存使用率偏高: ${(usage * 100).toStringAsFixed(1)}%');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 内存检查失败: $e');
      }
    }
  }
  
  /// 获取内存信息
  Future<Map<String, int>> _getMemoryInfo() async {
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('performance/memory');
        final result = await platform.invokeMethod<Map>('getMemoryInfo');
        return Map<String, int>.from(result ?? {});
      } catch (e) {
        // 如果平台通道不可用，使用估算值
        return _estimateMemoryInfo();
      }
    } else if (Platform.isIOS) {
      try {
        const platform = MethodChannel('performance/memory');
        final result = await platform.invokeMethod<Map>('getMemoryInfo');
        return Map<String, int>.from(result ?? {});
      } catch (e) {
        return _estimateMemoryInfo();
      }
    } else {
      return _estimateMemoryInfo();
    }
  }
  
  /// 估算内存信息（当平台通道不可用时）
  Map<String, int> _estimateMemoryInfo() {
    // 这是一个简单的估算，实际项目中应该使用平台特定的API
    const estimatedTotal = 4 * 1024 * 1024 * 1024; // 4GB
    const estimatedUsed = 1 * 1024 * 1024 * 1024; // 1GB
    
    return {
      'totalMemory': estimatedTotal,
      'usedMemory': estimatedUsed,
      'availableMemory': estimatedTotal - estimatedUsed,
    };
  }
  
  /// 记录性能日志
  void _logPerformanceMetrics() {
    if (_metrics.isEmpty) return;
    
    final recentMetrics = _metrics.where((m) => 
        DateTime.now().difference(m.timestamp).inMinutes < 5).toList();
    
    if (recentMetrics.isEmpty) return;
    
    // 计算统计信息
    final groupedMetrics = <String, List<PerformanceMetric>>{};
    for (final metric in recentMetrics) {
      groupedMetrics.putIfAbsent(metric.name, () => []).add(metric);
    }
    
    debugPrint('📊 性能统计 (最近5分钟):');
    for (final entry in groupedMetrics.entries) {
      final metrics = entry.value;
      final avgValue = metrics.map((m) => m.value).reduce((a, b) => a + b) / metrics.length;
      final maxValue = metrics.map((m) => m.value).reduce((a, b) => a > b ? a : b);
      
      debugPrint('  ${entry.key}: 平均${avgValue.toStringAsFixed(1)}ms, 最大${maxValue.toStringAsFixed(1)}ms, 次数${metrics.length}');
    }
    
    // 内存使用统计
    if (_memorySnapshots.isNotEmpty) {
      final recentSnapshots = _memorySnapshots.where((s) => 
          DateTime.now().difference(s.timestamp).inMinutes < 5).toList();
      
      if (recentSnapshots.isNotEmpty) {
        final avgUsage = recentSnapshots.map((s) => s.memoryUsageRatio).reduce((a, b) => a + b) / recentSnapshots.length;
        debugPrint('  内存使用率: 平均${(avgUsage * 100).toStringAsFixed(1)}%');
      }
    }
  }
  
  /// 触发垃圾回收
  void triggerGarbageCollection() {
    if (kDebugMode) {
      try {
        // 在debug模式下可以尝试调用 developer timeline
        developer.Timeline.startSync('gc');
        developer.Timeline.finishSync();
        
        // 触发一些操作来促进垃圾回收
        <dynamic>[];
        
        debugPrint('🗑️ 已触发垃圾回收相关操作');
      } catch (e) {
        debugPrint('❌ 触发垃圾回收失败: $e');
      }
    }
  }
  
  /// 获取性能报告
  PerformanceReport getPerformanceReport() {
    final now = DateTime.now();
    final recentMetrics = _metrics.where((m) => 
        now.difference(m.timestamp).inHours < 1).toList();
    
    final recentSnapshots = _memorySnapshots.where((s) => 
        now.difference(s.timestamp).inHours < 1).toList();
    
    return PerformanceReport(
      metrics: List.from(recentMetrics),
      memorySnapshots: List.from(recentSnapshots),
      generatedAt: now,
    );
  }
  
  /// 清理历史数据
  void clearHistory() {
    _metrics.clear();
    _memorySnapshots.clear();
    
    if (kDebugMode) {
      debugPrint('🧹 性能历史数据已清理');
    }
  }
  
  /// 检查是否有内存泄漏
  List<String> detectPotentialMemoryLeaks() {
    final issues = <String>[];
    
    if (_memorySnapshots.length < 10) {
      return issues; // 需要足够的数据点
    }
    
    // 检查内存是否持续增长
    final recent10 = _memorySnapshots.takeLast(10).toList();
    var increasingCount = 0;
    
    for (int i = 1; i < recent10.length; i++) {
      if (recent10[i].usedMemory > recent10[i-1].usedMemory) {
        increasingCount++;
      }
    }
    
    if (increasingCount >= 7) { // 70%的时间在增长
      issues.add('检测到内存持续增长趋势，可能存在内存泄漏');
    }
    
    // 检查内存使用率是否过高
    final avgUsage = recent10.map((s) => s.memoryUsageRatio).reduce((a, b) => a + b) / recent10.length;
    if (avgUsage > memoryWarningThreshold) {
      issues.add('内存使用率持续偏高: ${(avgUsage * 100).toStringAsFixed(1)}%');
    }
    
    return issues;
  }
}

/// 性能指标
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  const PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.metadata,
  });
}

/// 内存快照
class MemorySnapshot {
  final DateTime timestamp;
  final int usedMemory;
  final int totalMemory;
  final int availableMemory;
  
  const MemorySnapshot({
    required this.timestamp,
    required this.usedMemory,
    required this.totalMemory,
    required this.availableMemory,
  });
  
  double get memoryUsageRatio => totalMemory > 0 ? usedMemory / totalMemory : 0;
  
  String get formattedUsedMemory => _formatBytes(usedMemory);
  String get formattedTotalMemory => _formatBytes(totalMemory);
  String get formattedAvailableMemory => _formatBytes(availableMemory);
  
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// 性能报告
class PerformanceReport {
  final List<PerformanceMetric> metrics;
  final List<MemorySnapshot> memorySnapshots;
  final DateTime generatedAt;
  
  const PerformanceReport({
    required this.metrics,
    required this.memorySnapshots,
    required this.generatedAt,
  });
  
  /// 获取慢操作统计
  Map<String, List<PerformanceMetric>> get slowOperations {
    final slow = <String, List<PerformanceMetric>>{};
    
    for (final metric in metrics) {
      if (metric.value > 100) { // 超过100ms的操作
        slow.putIfAbsent(metric.name, () => []).add(metric);
      }
    }
    
    return slow;
  }
  
  /// 获取内存使用趋势
  String get memoryTrend {
    if (memorySnapshots.length < 2) return '数据不足';
    
    final first = memorySnapshots.first;
    final last = memorySnapshots.last;
    
    if (last.usedMemory > first.usedMemory * 1.1) {
      return '上升趋势';
    } else if (last.usedMemory < first.usedMemory * 0.9) {
      return '下降趋势';
    } else {
      return '稳定';
    }
  }
  
  /// 生成报告摘要
  String generateSummary() {
    final buffer = StringBuffer();
    buffer.writeln('性能报告摘要 - ${generatedAt.toIso8601String()}');
    buffer.writeln('');
    
    // 性能指标摘要
    if (metrics.isNotEmpty) {
      final groupedMetrics = <String, List<PerformanceMetric>>{};
      for (final metric in metrics) {
        groupedMetrics.putIfAbsent(metric.name, () => []).add(metric);
      }
      
      buffer.writeln('性能指标:');
      for (final entry in groupedMetrics.entries) {
        final values = entry.value.map((m) => m.value).toList();
        final avg = values.reduce((a, b) => a + b) / values.length;
        final max = values.reduce((a, b) => a > b ? a : b);
        
        buffer.writeln('  ${entry.key}: 平均${avg.toStringAsFixed(1)}ms, 最大${max.toStringAsFixed(1)}ms');
      }
      buffer.writeln('');
    }
    
    // 内存使用摘要
    if (memorySnapshots.isNotEmpty) {
      final latest = memorySnapshots.last;
      buffer.writeln('内存使用:');
      buffer.writeln('  当前: ${latest.formattedUsedMemory} / ${latest.formattedTotalMemory}');
      buffer.writeln('  使用率: ${(latest.memoryUsageRatio * 100).toStringAsFixed(1)}%');
      buffer.writeln('  趋势: $memoryTrend');
      buffer.writeln('');
    }
    
    // 慢操作警告
    final slow = slowOperations;
    if (slow.isNotEmpty) {
      buffer.writeln('慢操作警告:');
      for (final entry in slow.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value.length}次超过100ms');
      }
    }
    
    return buffer.toString();
  }
}

/// 扩展方法
extension ListExtension<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count);
  }
}