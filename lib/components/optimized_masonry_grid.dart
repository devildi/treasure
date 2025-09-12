import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../core/pagination/pagination_controller.dart';

class OptimizedMasonryGrid<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final Widget? loadingMoreWidget;
  final double loadMoreThreshold;
  final ScrollController? scrollController;

  const OptimizedMasonryGrid({
    Key? key,
    required this.controller,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 8.0,
    this.crossAxisSpacing = 8.0,
    this.padding,
    this.physics,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.loadingMoreWidget,
    this.loadMoreThreshold = 200.0,
    this.scrollController,
  }) : super(key: key);

  @override
  OptimizedMasonryGridState<T> createState() => OptimizedMasonryGridState<T>();
}

class OptimizedMasonryGridState<T> extends State<OptimizedMasonryGrid<T>> 
    with AutomaticKeepAliveClientMixin {
  
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  bool _preserveScrollPosition = false;
  double _lastScrollOffset = 0.0;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_scrollListener);
    
    // Load initial data if needed
    if (widget.controller.status == PaginationStatus.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.loadInitialData();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _debounceTimer?.cancel();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollListener() {
    final currentOffset = _scrollController.offset;
    
    // 减少频繁触发：只有在滚动距离足够大时才检查
    if ((currentOffset - _lastScrollOffset).abs() < 10) return;
    _lastScrollOffset = currentOffset;
    
    // 使用防抖减少加载触发频率
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_shouldLoadMore()) {
        _loadMore();
      }
    });
  }

  bool _shouldLoadMore() {
    // 所有必须满足的条件
    return _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - widget.loadMoreThreshold &&
        !_isLoadingMore &&
        !widget.controller.hasReachedEnd &&
        !widget.controller.isLoading &&
        !widget.controller.isLoadingMore &&
        widget.controller.items.isNotEmpty; // 确保有数据才尝试加载更多
  }

  Future<void> _loadMore() async {
    // 最后一道防线：再次检查是否应该加载
    if (!_shouldLoadMore() || widget.controller.hasReachedEnd) {
      debugPrint('🛑 Load more cancelled: hasReachedEnd=${widget.controller.hasReachedEnd}');
      return;
    }
    
    debugPrint('⬇️ Loading more items... Current: ${widget.controller.items.length}');
    
    // 记住精确的滚动位置
    final currentScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    
    // 设置加载状态，但不立即触发重建
    _isLoadingMore = true;
    _preserveScrollPosition = true;
    
    try {
      // 直接调用控制器加载，避免额外的setState
      await widget.controller.loadMore();
      
      debugPrint('✅ Load more completed. Total items: ${widget.controller.items.length}, hasReachedEnd: ${widget.controller.hasReachedEnd}');
      
      // 使用更精确的滚动位置恢复
      if (mounted && _scrollController.hasClients && _preserveScrollPosition) {
        // 立即恢复位置，不等待下一帧
        _scrollController.jumpTo(currentScrollOffset);
        
        // 然后在下一帧进行微调（如果需要）
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && mounted) {
            final currentOffset = _scrollController.offset;
            // 只有当位置偏差较大时才调整
            if ((currentOffset - currentScrollOffset).abs() > 1.0) {
              _scrollController.animateTo(
                currentScrollOffset,
                duration: const Duration(milliseconds: 50),
                curve: Curves.easeOut,
              );
            }
          }
          _preserveScrollPosition = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load more failed: $e');
    } finally {
      if (mounted) {
        // 延迟setState以减少抖动
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final controller = widget.controller;
        
        if (controller.isLoading) {
          return widget.loadingWidget ?? 
            const Center(child: CircularProgressIndicator());
        }
        
        if (controller.hasError && controller.isEmpty) {
          return widget.errorWidget ?? 
            _buildErrorWidget();
        }
        
        if (controller.isEmpty) {
          return widget.emptyWidget ?? 
            const Center(
              child: Text(
                '暂无数据',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
        }
        
        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              // 当数据更新导致滚动时，立即稳定位置
              if (_preserveScrollPosition && notification.depth == 0) {
                return true; // 消费这个通知，防止冒泡
              }
              return false;
            },
            child: CustomScrollView(
              key: const PageStorageKey('optimized_masonry_grid'),
              controller: _scrollController,
              physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: widget.padding ?? EdgeInsets.zero,
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: widget.crossAxisCount,
                    mainAxisSpacing: widget.mainAxisSpacing,
                    crossAxisSpacing: widget.crossAxisSpacing,
                    childCount: controller.items.length,
                    itemBuilder: (context, index) {
                      final item = controller.items[index];
                      // 使用RepaintBoundary减少重绘，保持原始key
                      final childWidget = widget.itemBuilder(context, item, index);
                      return RepaintBoundary(
                        key: childWidget.key,
                        child: childWidget,
                      );
                    },
                  ),
                ),
              if (_isLoadingMore || controller.isLoadingMore)
                SliverToBoxAdapter(
                  child: widget.loadingMoreWidget ?? 
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ),
              if (controller.hasReachedEnd && controller.items.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已显示全部 ${controller.totalItems} 件宝贝',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Flexible(
              child: Text(
                widget.controller.errorMessage ?? '网络异常，请稍后再试',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('点击刷新', style: TextStyle(color: Colors.white)),
              onPressed: () => widget.controller.refresh(),
            ),
          ],
        ),
      ),
    );
  }
}

