import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'performance_manager.dart';

/// Widget性能优化器
class WidgetPerformanceOptimizer {
  static WidgetPerformanceOptimizer? _instance;
  static WidgetPerformanceOptimizer get instance => _instance ??= WidgetPerformanceOptimizer._();
  
  WidgetPerformanceOptimizer._();
  
  final Map<String, PerformanceWidgetMetrics> _widgetMetrics = {};
  final Set<String> _expensiveWidgets = {};
  
  /// 记录Widget构建性能
  void recordWidgetBuildTime(String widgetName, Duration buildTime) {
    final metrics = _widgetMetrics[widgetName] ?? 
        PerformanceWidgetMetrics(widgetName: widgetName);
    
    metrics.addBuildTime(buildTime);
    _widgetMetrics[widgetName] = metrics;
    
    // 标记耗时Widget
    if (buildTime.inMilliseconds > 16) { // 超过一帧的时间
      _expensiveWidgets.add(widgetName);
      
      if (kDebugMode) {
        debugPrint('⚠️ 慢Widget检测: $widgetName 构建耗时 ${buildTime.inMilliseconds}ms');
      }
    }
    
    PerformanceManager.instance.recordMetric(
      'widget_build_$widgetName',
      buildTime.inMilliseconds.toDouble(),
    );
  }
  
  /// 获取Widget性能报告
  List<PerformanceWidgetMetrics> getPerformanceReport() {
    return _widgetMetrics.values.toList()
      ..sort((a, b) => b.averageBuildTime.compareTo(a.averageBuildTime));
  }
  
  /// 获取耗时Widget列表
  List<String> getExpensiveWidgets() {
    return _expensiveWidgets.toList();
  }
  
  /// 清理性能数据
  void clearMetrics() {
    _widgetMetrics.clear();
    _expensiveWidgets.clear();
  }
}

/// Widget性能指标
class PerformanceWidgetMetrics {
  final String widgetName;
  final List<Duration> _buildTimes = [];
  int _rebuildCount = 0;
  
  PerformanceWidgetMetrics({required this.widgetName});
  
  void addBuildTime(Duration buildTime) {
    _buildTimes.add(buildTime);
    _rebuildCount++;
    
    // 限制历史记录数量
    if (_buildTimes.length > 100) {
      _buildTimes.removeAt(0);
    }
  }
  
  Duration get averageBuildTime {
    if (_buildTimes.isEmpty) return Duration.zero;
    final totalMs = _buildTimes.fold(0, (sum, duration) => sum + duration.inMicroseconds);
    return Duration(microseconds: totalMs ~/ _buildTimes.length);
  }
  
  Duration get maxBuildTime {
    if (_buildTimes.isEmpty) return Duration.zero;
    return _buildTimes.reduce((a, b) => a.inMicroseconds > b.inMicroseconds ? a : b);
  }
  
  int get rebuildCount => _rebuildCount;
  
  bool get isExpensive => averageBuildTime.inMilliseconds > 16;
  
  @override
  String toString() {
    return 'WidgetMetrics($widgetName: avg=${averageBuildTime.inMilliseconds}ms, '
           'max=${maxBuildTime.inMilliseconds}ms, rebuilds=$rebuildCount)';
  }
}

/// 性能感知Widget Mixin
mixin PerformanceAwareMixin<T extends StatefulWidget> on State<T> {
  Stopwatch? _buildStopwatch;
  
  @override
  Widget build(BuildContext context) {
    _buildStopwatch = Stopwatch()..start();
    
    final widget = performanceBuild(context);
    
    _buildStopwatch?.stop();
    final buildTime = _buildStopwatch?.elapsed ?? Duration.zero;
    
    WidgetPerformanceOptimizer.instance.recordWidgetBuildTime(
      T.toString(),
      buildTime,
    );
    
    return widget;
  }
  
  /// 子类需要重写这个方法而不是build方法
  Widget performanceBuild(BuildContext context);
}

/// 高性能的瀑布流Grid组件
class PerformantMasonryGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  
  const PerformantMasonryGrid({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.padding,
  }) : super(key: key);
  
  @override
  State<PerformantMasonryGrid> createState() => _PerformantMasonryGridState();
}

class _PerformantMasonryGridState extends State<PerformantMasonryGrid> {
  final GlobalKey _containerKey = GlobalKey();
  final Map<int, GlobalKey> _itemKeys = {};
  
  @override
  void initState() {
    super.initState();
    _initializeItemKeys();
  }
  
  void _initializeItemKeys() {
    for (int i = 0; i < widget.children.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 
            (widget.padding?.horizontal ?? 0);
        final itemWidth = (availableWidth - 
            (widget.crossAxisCount - 1) * widget.crossAxisSpacing) / 
            widget.crossAxisCount;
        
        return Container(
          key: _containerKey,
          padding: widget.padding,
          child: _buildMasonryLayout(itemWidth),
        );
      },
    );
  }
  
  Widget _buildMasonryLayout(double itemWidth) {
    final List<List<Widget>> columns = List.generate(
      widget.crossAxisCount,
      (_) => <Widget>[],
    );
    final List<double> columnHeights = List.filled(widget.crossAxisCount, 0);
    
    for (int i = 0; i < widget.children.length; i++) {
      // 找到最短的列
      final shortestColumnIndex = columnHeights
          .asMap()
          .entries
          .reduce((a, b) => a.value < b.value ? a : b)
          .key;
      
      final child = SizedBox(
        key: _itemKeys[i],
        width: itemWidth,
        child: widget.children[i],
      );
      
      columns[shortestColumnIndex].add(child);
      
      // 估算高度（这里可以根据实际情况优化）
      final estimatedHeight = _estimateItemHeight(i, itemWidth);
      columnHeights[shortestColumnIndex] += estimatedHeight + widget.mainAxisSpacing;
    }
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: columns.asMap().entries.map((entry) {
        final columnIndex = entry.key;
        final columnChildren = entry.value;
        
        return Expanded(
          child: Column(
            children: [
              ...columnChildren.asMap().entries.map((childEntry) {
                final childIndex = childEntry.key;
                final child = childEntry.value;
                
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: childIndex < columnChildren.length - 1 
                        ? widget.mainAxisSpacing 
                        : 0,
                    right: columnIndex < widget.crossAxisCount - 1 
                        ? widget.crossAxisSpacing 
                        : 0,
                  ),
                  child: child,
                );
              }).toList(),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  double _estimateItemHeight(int index, double width) {
    // 这里可以根据内容类型来估算高度
    // 为了示例，我们使用一个简单的估算
    return width * 0.6 + 50; // 假设是卡片类型的内容
  }
}

/// 高性能图片组件
class PerformantImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  
  const PerformantImage({
    Key? key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
  }) : super(key: key);
  
  @override
  State<PerformantImage> createState() => _PerformantImageState();
}

class _PerformantImageState extends State<PerformantImage>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => widget.enableMemoryCache;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }
    
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.network(
          widget.imageUrl!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          cacheHeight: widget.height?.toInt(),
          cacheWidth: widget.width?.toInt(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            return widget.errorWidget ?? _buildErrorWidget();
          },
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
  }
  
  Widget _buildErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: const Icon(Icons.error, color: Colors.red),
    );
  }
}

/// 智能重建检测Widget
class SmartRebuildDetector extends StatefulWidget {
  final Widget child;
  final String name;
  final VoidCallback? onUnnecessaryRebuild;
  
  const SmartRebuildDetector({
    Key? key,
    required this.child,
    required this.name,
    this.onUnnecessaryRebuild,
  }) : super(key: key);
  
  @override
  State<SmartRebuildDetector> createState() => _SmartRebuildDetectorState();
}

class _SmartRebuildDetectorState extends State<SmartRebuildDetector> {
  Widget? _previousChild;
  int _rebuildCount = 0;
  
  @override
  Widget build(BuildContext context) {
    _rebuildCount++;
    
    // 检测是否是不必要的重建
    if (_previousChild != null && 
        _previousChild.runtimeType == widget.child.runtimeType) {
      widget.onUnnecessaryRebuild?.call();
      
      if (kDebugMode) {
        debugPrint('🔄 检测到可能的不必要重建: ${widget.name} (第$_rebuildCount次)');
      }
    }
    
    _previousChild = widget.child;
    
    return widget.child;
  }
}

/// 性能优化的AnimatedBuilder
class PerformantAnimatedBuilder extends StatefulWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;
  
  const PerformantAnimatedBuilder({
    Key? key,
    required this.animation,
    required this.builder,
    this.child,
  }) : super(key: key);
  
  @override
  State<PerformantAnimatedBuilder> createState() => _PerformantAnimatedBuilderState();
}

class _PerformantAnimatedBuilderState extends State<PerformantAnimatedBuilder> {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: widget.builder,
        child: widget.child,
      ),
    );
  }
}

/// 延迟加载Widget
class LazyWidget extends StatefulWidget {
  final Widget Function() builder;
  final Widget? placeholder;
  final Duration delay;
  
  const LazyWidget({
    Key? key,
    required this.builder,
    this.placeholder,
    this.delay = const Duration(milliseconds: 100),
  }) : super(key: key);
  
  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  Widget? _builtWidget;
  bool _isBuilding = false;
  
  @override
  void initState() {
    super.initState();
    _scheduleBuilder();
  }
  
  void _scheduleBuilder() {
    if (!_isBuilding) {
      _isBuilding = true;
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() {
            _builtWidget = widget.builder();
          });
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_builtWidget != null) {
      return _builtWidget!;
    }
    
    return widget.placeholder ?? const SizedBox.shrink();
  }
}

/// 可见性感知Widget
class VisibilityAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget Function()? placeholderBuilder;
  final double visibilityThreshold;
  
  const VisibilityAwareWidget({
    Key? key,
    required this.child,
    this.placeholderBuilder,
    this.visibilityThreshold = 0.1,
  }) : super(key: key);
  
  @override
  State<VisibilityAwareWidget> createState() => _VisibilityAwareWidgetState();
}

class _VisibilityAwareWidgetState extends State<VisibilityAwareWidget> {
  bool _isVisible = false;
  
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > widget.visibilityThreshold;
        if (visible != _isVisible) {
          setState(() {
            _isVisible = visible;
          });
        }
      },
      child: _isVisible 
          ? widget.child 
          : (widget.placeholderBuilder?.call() ?? const SizedBox.shrink()),
    );
  }
}

/// 简单的可见性检测器（如果没有visibility_detector包）
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
  });
  
  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    // 简化的可见性检测实现
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisibilityChanged(const VisibilityInfo(visibleFraction: 1.0));
    });
    
    return widget.child;
  }
}

class VisibilityInfo {
  final double visibleFraction;
  
  const VisibilityInfo({required this.visibleFraction});
}

/// 防抖动按钮
class DebouncedButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Duration debounceTime;
  
  const DebouncedButton({
    Key? key,
    this.onPressed,
    required this.child,
    this.debounceTime = const Duration(milliseconds: 300),
  }) : super(key: key);
  
  @override
  State<DebouncedButton> createState() => _DebouncedButtonState();
}

class _DebouncedButtonState extends State<DebouncedButton> {
  DateTime? _lastPressTime;
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onPressed != null ? _handlePress : null,
      child: widget.child,
    );
  }
  
  void _handlePress() {
    final now = DateTime.now();
    if (_lastPressTime == null || 
        now.difference(_lastPressTime!) > widget.debounceTime) {
      _lastPressTime = now;
      widget.onPressed?.call();
    }
  }
}