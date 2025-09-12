import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'performance_manager.dart';
import 'widget_performance_optimizer.dart';
import 'memory_optimizer.dart';

/// 性能调试面板
class PerformanceDebugPanel extends StatefulWidget {
  const PerformanceDebugPanel({Key? key}) : super(key: key);
  
  @override
  State<PerformanceDebugPanel> createState() => _PerformanceDebugPanelState();
}

class _PerformanceDebugPanelState extends State<PerformanceDebugPanel>
    with TickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  
  PerformanceReport? _performanceReport;
  MemoryUsageStats? _memoryStats;
  List<PerformanceWidgetMetrics>? _widgetMetrics;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _startRefreshTimer();
    _refreshData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        _refreshData();
      }
    });
  }
  
  void _refreshData() {
    setState(() {
      _performanceReport = PerformanceManager.instance.getPerformanceReport();
      _memoryStats = MemoryOptimizer.instance.getMemoryStats();
      _widgetMetrics = WidgetPerformanceOptimizer.instance.getPerformanceReport();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('性能调试面板'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearAllData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '性能概览'),
            Tab(text: '内存监控'),
            Tab(text: 'Widget性能'),
            Tab(text: '诊断工具'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerformanceOverview(),
          _buildMemoryMonitor(),
          _buildWidgetPerformance(),
          _buildDiagnosticTools(),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceOverview() {
    if (_performanceReport == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            '性能摘要',
            _performanceReport!.generateSummary(),
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildMetricsChart(),
          const SizedBox(height: 16),
          _buildSlowOperations(),
        ],
      ),
    );
  }
  
  Widget _buildMemoryMonitor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_memoryStats != null) ...[
            _buildInfoCard(
              '内存统计',
              _memoryStats.toString(),
              Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          _buildMemoryChart(),
          const SizedBox(height: 16),
          _buildMemoryActions(),
        ],
      ),
    );
  }
  
  Widget _buildWidgetPerformance() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Widget构建性能',
            'Top 10 最耗时的Widget',
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildWidgetMetricsList(),
          const SizedBox(height: 16),
          _buildExpensiveWidgets(),
        ],
      ),
    );
  }
  
  Widget _buildDiagnosticTools() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDiagnosticActions(),
          const SizedBox(height: 16),
          _buildMemoryLeakDetection(),
          const SizedBox(height: 16),
          _buildPerformanceSettings(),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String content, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMetricsChart() {
    if (_performanceReport?.metrics.isEmpty ?? true) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无性能数据'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '性能指标趋势',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: CustomPaint(
                painter: MetricsChartPainter(_performanceReport!.metrics),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryChart() {
    if (_performanceReport?.memorySnapshots.isEmpty ?? true) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无内存数据'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '内存使用趋势',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: CustomPaint(
                painter: MemoryChartPainter(_performanceReport!.memorySnapshots),
                size: Size.infinite,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSlowOperations() {
    final slowOps = _performanceReport?.slowOperations ?? {};
    
    if (slowOps.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无慢操作记录'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '慢操作警告',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            ...slowOps.entries.map((entry) {
              final avgTime = entry.value.map((m) => m.value).reduce((a, b) => a + b) / entry.value.length;
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text(entry.key),
                subtitle: Text('平均耗时: ${avgTime.toStringAsFixed(1)}ms'),
                trailing: Text('${entry.value.length}次'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWidgetMetricsList() {
    if (_widgetMetrics?.isEmpty ?? true) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无Widget性能数据'),
        ),
      );
    }
    
    final topWidgets = _widgetMetrics!.take(10).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 耗时Widget',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...topWidgets.map((metric) {
              return ListTile(
                leading: Icon(
                  metric.isExpensive ? Icons.warning : Icons.check_circle,
                  color: metric.isExpensive ? Colors.red : Colors.green,
                ),
                title: Text(metric.widgetName),
                subtitle: Text(
                  '平均: ${metric.averageBuildTime.inMilliseconds}ms, '
                  '最大: ${metric.maxBuildTime.inMilliseconds}ms',
                ),
                trailing: Text('${metric.rebuildCount}次'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpensiveWidgets() {
    final expensiveWidgets = WidgetPerformanceOptimizer.instance.getExpensiveWidgets();
    
    if (expensiveWidgets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('暂无耗时Widget'),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '耗时Widget列表',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            ...expensiveWidgets.map((widget) {
              return ListTile(
                leading: const Icon(Icons.speed, color: Colors.red),
                title: Text(widget),
                subtitle: const Text('构建时间超过16ms'),
                trailing: const Icon(Icons.arrow_forward_ios),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '内存管理',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      MemoryOptimizer.instance.clearAllCaches();
                      _showSnackBar('已清理所有缓存');
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清理缓存'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      PerformanceManager.instance.triggerGarbageCollection();
                      _showSnackBar('已触发垃圾回收');
                    },
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('垃圾回收'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDiagnosticActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '诊断工具',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('生成性能报告'),
              subtitle: const Text('导出详细的性能分析报告'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _exportPerformanceReport,
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('检测内存泄漏'),
              subtitle: const Text('分析可能的内存泄漏问题'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _detectMemoryLeaks,
            ),
            ListTile(
              leading: const Icon(Icons.timeline),
              title: const Text('性能时间线'),
              subtitle: const Text('查看详细的性能时间线'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showPerformanceTimeline,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryLeakDetection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '内存泄漏检测',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: Future.value(PerformanceManager.instance.detectPotentialMemoryLeaks()),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final issues = snapshot.data!;
                  if (issues.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('未检测到内存泄漏'),
                    );
                  }
                  
                  return Column(
                    children: issues.map((issue) {
                      return ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(issue),
                      );
                    }).toList(),
                  );
                }
                
                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPerformanceSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '性能设置',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('启用性能监控'),
              subtitle: const Text('实时监控应用性能'),
              value: true,
              onChanged: (value) {
                // 实现性能监控开关
              },
            ),
            SwitchListTile(
              title: const Text('启用Widget性能追踪'),
              subtitle: const Text('追踪Widget构建性能'),
              value: true,
              onChanged: (value) {
                // 实现Widget性能追踪开关
              },
            ),
            SwitchListTile(
              title: const Text('自动内存清理'),
              subtitle: const Text('自动清理过期的缓存'),
              value: true,
              onChanged: (value) {
                // 实现自动内存清理开关
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _clearAllData() {
    PerformanceManager.instance.clearHistory();
    WidgetPerformanceOptimizer.instance.clearMetrics();
    MemoryOptimizer.instance.clearAllCaches();
    _refreshData();
    _showSnackBar('已清理所有性能数据');
  }
  
  void _exportPerformanceReport() {
    final report = PerformanceManager.instance.getPerformanceReport();
    final summary = report.generateSummary();
    
    if (kDebugMode) {
      debugPrint('=== 性能报告 ===');
      debugPrint(summary);
    }
    
    _showSnackBar('性能报告已导出到调试控制台');
  }
  
  void _detectMemoryLeaks() {
    final issues = PerformanceManager.instance.detectPotentialMemoryLeaks();
    
    if (issues.isEmpty) {
      _showSnackBar('未检测到内存泄漏');
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('内存泄漏检测结果'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: issues.map((issue) => 
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(issue),
              )
            ).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }
  
  void _showPerformanceTimeline() {
    // 显示性能时间线的实现
    _showSnackBar('性能时间线功能开发中');
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

/// 性能指标图表绘制器
class MetricsChartPainter extends CustomPainter {
  final List<PerformanceMetric> metrics;
  
  MetricsChartPainter(this.metrics);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    // 简化的图表绘制逻辑
    final maxValue = metrics.map((m) => m.value).reduce((a, b) => a > b ? a : b);
    final minValue = metrics.map((m) => m.value).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    for (int i = 0; i < metrics.length; i++) {
      final x = (i / (metrics.length - 1)) * size.width;
      final y = size.height - ((metrics[i].value - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 内存图表绘制器
class MemoryChartPainter extends CustomPainter {
  final List<MemorySnapshot> snapshots;
  
  MemoryChartPainter(this.snapshots);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    for (int i = 0; i < snapshots.length; i++) {
      final x = (i / (snapshots.length - 1)) * size.width;
      final y = size.height - (snapshots[i].memoryUsageRatio * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}