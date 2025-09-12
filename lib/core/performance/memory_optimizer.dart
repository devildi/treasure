import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 内存优化工具类
class MemoryOptimizer {
  static MemoryOptimizer? _instance;
  static MemoryOptimizer get instance => _instance ??= MemoryOptimizer._();
  
  MemoryOptimizer._();
  
  // 图片缓存管理
  final Map<String, WeakReference<Uint8List>> _imageCache = {};
  final Map<String, DateTime> _imageCacheTimestamps = {};
  
  // Widget实例追踪
  final Set<WeakReference<Widget>> _widgetReferences = {};
  
  // 清理定时器
  Timer? _cleanupTimer;
  
  // 配置
  static const Duration cacheCleanupInterval = Duration(minutes: 5);
  static const Duration imageCacheExpiry = Duration(minutes: 30);
  static const int maxImageCacheSize = 50;
  
  /// 初始化内存优化器
  void initialize() {
    _startCleanupTimer();
    
    if (kDebugMode) {
      debugPrint('🧠 内存优化器已初始化');
    }
  }
  
  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _imageCache.clear();
    _imageCacheTimestamps.clear();
    _widgetReferences.clear();
    
    if (kDebugMode) {
      debugPrint('🧠 内存优化器已释放');
    }
  }
  
  /// 开始清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(cacheCleanupInterval, (_) {
      _cleanupExpiredCache();
      _cleanupWeakReferences();
    });
  }
  
  /// 缓存图片数据
  void cacheImageData(String key, Uint8List data) {
    // 检查缓存大小限制
    if (_imageCache.length >= maxImageCacheSize) {
      _evictOldestImageCache();
    }
    
    _imageCache[key] = WeakReference(data);
    _imageCacheTimestamps[key] = DateTime.now();
  }
  
  /// 获取缓存的图片数据
  Uint8List? getCachedImageData(String key) {
    final weakRef = _imageCache[key];
    if (weakRef == null) return null;
    
    final data = weakRef.target;
    if (data == null) {
      // 弱引用已失效，清理缓存
      _imageCache.remove(key);
      _imageCacheTimestamps.remove(key);
      return null;
    }
    
    // 检查是否过期
    final timestamp = _imageCacheTimestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp) > imageCacheExpiry) {
      _imageCache.remove(key);
      _imageCacheTimestamps.remove(key);
      return null;
    }
    
    return data;
  }
  
  /// 清理过期缓存
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _imageCacheTimestamps.entries) {
      if (now.difference(entry.value) > imageCacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _imageCache.remove(key);
      _imageCacheTimestamps.remove(key);
    }
    
    if (kDebugMode && expiredKeys.isNotEmpty) {
      debugPrint('🧹 清理过期图片缓存: ${expiredKeys.length} 个');
    }
  }
  
  /// 驱逐最旧的图片缓存
  void _evictOldestImageCache() {
    if (_imageCacheTimestamps.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _imageCacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value;
      }
    }
    
    if (oldestKey != null) {
      _imageCache.remove(oldestKey);
      _imageCacheTimestamps.remove(oldestKey);
      
      if (kDebugMode) {
        debugPrint('🗑️ 驱逐最旧的图片缓存: $oldestKey');
      }
    }
  }
  
  /// 清理失效的弱引用
  void _cleanupWeakReferences() {
    _widgetReferences.removeWhere((ref) => ref.target == null);
    
    // 清理失效的图片缓存弱引用
    final invalidKeys = <String>[];
    for (final entry in _imageCache.entries) {
      if (entry.value.target == null) {
        invalidKeys.add(entry.key);
      }
    }
    
    for (final key in invalidKeys) {
      _imageCache.remove(key);
      _imageCacheTimestamps.remove(key);
    }
    
    if (kDebugMode && invalidKeys.isNotEmpty) {
      debugPrint('🧹 清理失效弱引用: ${invalidKeys.length} 个');
    }
  }
  
  /// 追踪Widget实例
  void trackWidget(Widget widget) {
    _widgetReferences.add(WeakReference(widget));
  }
  
  /// 获取活动Widget数量
  int get activeWidgetCount {
    return _widgetReferences.where((ref) => ref.target != null).length;
  }
  
  /// 强制清理所有缓存
  void clearAllCaches() {
    _imageCache.clear();
    _imageCacheTimestamps.clear();
    _widgetReferences.clear();
    
    if (kDebugMode) {
      debugPrint('🧹 强制清理所有缓存');
    }
  }
  
  /// 获取内存使用统计
  MemoryUsageStats getMemoryStats() {
    final activeCacheCount = _imageCache.values.where((ref) => ref.target != null).length;
    final totalCacheCount = _imageCache.length;
    final activeWidgetCount = _widgetReferences.where((ref) => ref.target != null).length;
    final totalWidgetCount = _widgetReferences.length;
    
    return MemoryUsageStats(
      activeCacheCount: activeCacheCount,
      totalCacheCount: totalCacheCount,
      activeWidgetCount: activeWidgetCount,
      totalWidgetCount: totalWidgetCount,
      cacheHitRate: totalCacheCount > 0 ? activeCacheCount / totalCacheCount : 0,
    );
  }
}

/// 内存使用统计
class MemoryUsageStats {
  final int activeCacheCount;
  final int totalCacheCount;
  final int activeWidgetCount;
  final int totalWidgetCount;
  final double cacheHitRate;
  
  const MemoryUsageStats({
    required this.activeCacheCount,
    required this.totalCacheCount,
    required this.activeWidgetCount,
    required this.totalWidgetCount,
    required this.cacheHitRate,
  });
  
  @override
  String toString() {
    return 'MemoryStats('
        'cache: $activeCacheCount/$totalCacheCount, '
        'widgets: $activeWidgetCount/$totalWidgetCount, '
        'hit rate: ${(cacheHitRate * 100).toStringAsFixed(1)}%'
        ')';
  }
}

/// 内存感知的图片缓存Mixin
mixin MemoryAwareImageCacheMixin {
  /// 缓存图片数据
  void cacheImageData(String url, Uint8List data) {
    MemoryOptimizer.instance.cacheImageData(_getImageCacheKey(url), data);
  }
  
  /// 获取缓存的图片数据
  Uint8List? getCachedImageData(String url) {
    return MemoryOptimizer.instance.getCachedImageData(_getImageCacheKey(url));
  }
  
  String _getImageCacheKey(String url) {
    return 'image_${url.hashCode}';
  }
}

/// 内存感知的State Mixin
mixin MemoryAwareStateMixin<T extends StatefulWidget> on State<T> {
  bool _memoryOptimized = false;
  
  @override
  void initState() {
    super.initState();
    _enableMemoryOptimization();
  }
  
  @override
  void dispose() {
    _disableMemoryOptimization();
    super.dispose();
  }
  
  void _enableMemoryOptimization() {
    if (!_memoryOptimized) {
      MemoryOptimizer.instance.trackWidget(widget);
      _memoryOptimized = true;
    }
  }
  
  void _disableMemoryOptimization() {
    _memoryOptimized = false;
  }
  
  /// 获取是否应该构建复杂UI（基于内存压力）
  bool get shouldBuildComplexUI {
    final stats = MemoryOptimizer.instance.getMemoryStats();
    return stats.cacheHitRate > 0.5; // 缓存命中率高时才构建复杂UI
  }
}

/// 内存敏感的滚动控制器
class MemoryAwareScrollController extends ScrollController {
  final VoidCallback? _onMemoryPressure;
  
  MemoryAwareScrollController({VoidCallback? onMemoryPressure}) 
      : _onMemoryPressure = onMemoryPressure;
  
  @override
  void dispose() {
    _onMemoryPressure?.call();
    super.dispose();
  }
}

/// 内存优化的ListView Builder
class MemoryOptimizedListView extends StatefulWidget {
  final IndexedWidgetBuilder itemBuilder;
  final int? itemCount;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  
  const MemoryOptimizedListView({
    Key? key,
    required this.itemBuilder,
    this.itemCount,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  }) : super(key: key);
  
  @override
  State<MemoryOptimizedListView> createState() => _MemoryOptimizedListViewState();
}

class _MemoryOptimizedListViewState extends State<MemoryOptimizedListView> 
    with MemoryAwareStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => false; // 不保持状态以节省内存
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // 根据内存压力决定是否使用简化版本
    if (!shouldBuildComplexUI && widget.itemCount != null && widget.itemCount! > 100) {
      return _buildSimplifiedList();
    }
    
    return ListView.builder(
      itemBuilder: widget.itemBuilder,
      itemCount: widget.itemCount,
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      cacheExtent: 200, // 减少缓存范围以节省内存
    );
  }
  
  Widget _buildSimplifiedList() {
    return ListView.builder(
      itemBuilder: (context, index) {
        // 为大列表提供简化的item构建器
        return SizedBox(
          height: 60,
          child: widget.itemBuilder(context, index),
        );
      },
      itemCount: widget.itemCount,
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      cacheExtent: 100, // 更小的缓存范围
    );
  }
}

/// 内存优化的图片组件
class MemoryOptimizedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  
  const MemoryOptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);
  
  @override
  State<MemoryOptimizedImage> createState() => _MemoryOptimizedImageState();
}

class _MemoryOptimizedImageState extends State<MemoryOptimizedImage> 
    with MemoryAwareStateMixin, MemoryAwareImageCacheMixin {
  
  Uint8List? _cachedImageData;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  void _loadImage() {
    _cachedImageData = getCachedImageData(widget.imageUrl);
    if (_cachedImageData == null && !_isLoading) {
      _isLoading = true;
      // 这里应该实现实际的网络加载逻辑
      // 为了示例，我们只是标记为加载中
      if (mounted) {
        setState(() {});
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_cachedImageData != null) {
      return Image.memory(
        _cachedImageData!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => 
            widget.errorWidget ?? const Icon(Icons.error),
      );
    }
    
    if (_isLoading) {
      return widget.placeholder ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          );
    }
    
    return widget.errorWidget ?? 
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        );
  }
}