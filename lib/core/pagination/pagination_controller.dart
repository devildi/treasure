import 'package:flutter/material.dart';

enum PaginationStatus {
  initial,
  loading,
  success,
  failure,
  loadingMore,
  reachedEnd,
}

class PaginationController<T> extends ChangeNotifier {
  List<T> _items = [];
  int _currentPage = 1;
  PaginationStatus _status = PaginationStatus.initial;
  String? _errorMessage;
  bool _hasReachedEnd = false;
  
  // Configuration
  final int pageSize;
  final Future<List<T>> Function(int page) loadData;
  final Duration debounceDelay;
  
  // Internal
  bool _isDisposed = false;
  
  PaginationController({
    required this.loadData,
    this.pageSize = 20,
    this.debounceDelay = const Duration(milliseconds: 300),
  });

  // Getters
  List<T> get items => List.unmodifiable(_items);
  PaginationStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasReachedEnd => _hasReachedEnd;
  bool get isLoading => _status == PaginationStatus.loading;
  bool get isLoadingMore => _status == PaginationStatus.loadingMore;
  bool get hasError => _status == PaginationStatus.failure;
  bool get isEmpty => _items.isEmpty && _status != PaginationStatus.loading;
  int get currentPage => _currentPage;
  int get totalItems => _items.length;

  // Load initial data
  Future<void> loadInitialData() async {
    if (_isDisposed) return;
    
    _setStatus(PaginationStatus.loading);
    _currentPage = 1;
    _hasReachedEnd = false;
    _errorMessage = null;
    
    try {
      final newItems = await loadData(_currentPage);
      
      if (_isDisposed) return;
      
      _items = newItems;
      
      if (newItems.isEmpty) {
        // No items at all - empty dataset
        _hasReachedEnd = true;
        _setStatus(PaginationStatus.success);
      } else {
        // 对于累积型分页，第一页总是认为可能有更多数据
        // 除非返回的数据明显少于页面大小
        _hasReachedEnd = newItems.length < pageSize;
        
        if (_hasReachedEnd) {
          _setStatus(PaginationStatus.reachedEnd);
        } else {
          _setStatus(PaginationStatus.success);
        }
        _currentPage++; 
      }
    } catch (error) {
      if (_isDisposed) return;
      
      _errorMessage = error.toString();
      _setStatus(PaginationStatus.failure);
    }
  }

  // Load more data
  Future<void> loadMore() async {
    // 多重检查，确保不会无限加载
    if (_isDisposed || _hasReachedEnd || isLoading || isLoadingMore) {
      debugPrint('🛑 LoadMore blocked: disposed=$_isDisposed, hasReachedEnd=$_hasReachedEnd, isLoading=$isLoading, isLoadingMore=$isLoadingMore');
      return;
    }
    
    debugPrint('🔄 LoadMore started: page=$_currentPage, currentItems=${_items.length}');
    
    _setStatus(PaginationStatus.loadingMore);
    _errorMessage = null;
    
    try {
      final newItems = await loadData(_currentPage);
      
      if (_isDisposed) return;
      
      debugPrint('📥 Received ${newItems.length} new items (pageSize: $pageSize)');
      
      if (newItems.isNotEmpty) {
        // 关键修复：服务器返回的是累积数据，不是增量数据
        final previousCount = _items.length;
        _items = newItems; // 替换而不是追加
        _currentPage++;
        
        // 检查是否到达终点：
        // 1. 如果新数据量 <= 之前的数据量，说明没有更多数据了
        // 2. 只有当增量为0或负数时才确定结束，增量小于pageSize仍可能有更多数据
        final newCount = newItems.length;
        final incrementalCount = newCount - previousCount;
        
        _hasReachedEnd = incrementalCount <= 0;
        
        debugPrint('🎯 Updated state: previousCount=$previousCount, newCount=$newCount, incrementalCount=$incrementalCount, hasReachedEnd=$_hasReachedEnd');
        
        if (_hasReachedEnd) {
          debugPrint('🏁 End of data reached');
          _setStatus(PaginationStatus.reachedEnd);
        } else {
          _setStatus(PaginationStatus.success);
        }
      } else {
        // No items returned means we've definitely reached the end
        debugPrint('🏁 No items returned - end reached');
        _hasReachedEnd = true;
        _setStatus(PaginationStatus.reachedEnd);
      }
    } catch (error) {
      if (_isDisposed) return;
      
      debugPrint('❌ LoadMore error: $error');
      _errorMessage = error.toString();
      _setStatus(PaginationStatus.failure);
    }
  }

  // Refresh data
  Future<void> refresh() async {
    return loadInitialData();
  }

  // Clear all data
  void clear() {
    if (_isDisposed) return;
    
    _items.clear();
    _currentPage = 1;
    _hasReachedEnd = false;
    _errorMessage = null;
    _setStatus(PaginationStatus.initial);
  }

  // Add item to beginning of list
  void prependItem(T item) {
    if (_isDisposed) return;
    
    _items.insert(0, item);
    notifyListeners();
  }

  // Add item to end of list
  void appendItem(T item) {
    if (_isDisposed) return;
    
    _items.add(item);
    notifyListeners();
  }

  // Remove item from list
  void removeItem(T item) {
    if (_isDisposed) return;
    
    _items.remove(item);
    notifyListeners();
  }

  // Update item in list
  void updateItem(T oldItem, T newItem) {
    if (_isDisposed) return;
    
    final index = _items.indexOf(oldItem);
    if (index != -1) {
      _items[index] = newItem;
      notifyListeners();
    }
  }

  // Replace all items
  void replaceItems(List<T> newItems) {
    if (_isDisposed) return;
    
    _items = newItems;
    notifyListeners();
  }

  void _setStatus(PaginationStatus newStatus) {
    if (_isDisposed || _status == newStatus) return;
    
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

// Widget for handling pagination automatically
class PaginatedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final Widget? loadingMoreWidget;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double loadMoreThreshold;

  const PaginatedListView({
    Key? key,
    required this.controller,
    required this.itemBuilder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.loadingMoreWidget,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
    this.loadMoreThreshold = 200.0,
  }) : super(key: key);

  @override
  PaginatedListViewState<T> createState() => PaginatedListViewState<T>();
}

class PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - widget.loadMoreThreshold) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(controller.errorMessage ?? 'Unknown error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
        }
        
        if (controller.isEmpty) {
          return widget.emptyWidget ?? 
            const Center(child: Text('No items found'));
        }
        
        return RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView.builder(
            controller: _scrollController,
            padding: widget.padding,
            physics: widget.physics,
            shrinkWrap: widget.shrinkWrap,
            itemCount: controller.items.length + 
                (controller.isLoadingMore ? 1 : 0) +
                (controller.hasReachedEnd && controller.items.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < controller.items.length) {
                return widget.itemBuilder(context, controller.items[index], index);
              } else if (controller.isLoadingMore) {
                return widget.loadingMoreWidget ?? 
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
              } else if (controller.hasReachedEnd) {
                return Padding(
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
                          '已显示全部 ${controller.totalItems} 项',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}