import 'package:flutter/material.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/pagination/pagination_controller.dart';
import 'package:treasure/components/optimized_masonry_grid.dart';
import 'package:treasure/core/image/image_cache_manager.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/storage/storage_service.dart';
import 'package:treasure/core/performance/performance_manager.dart';
import 'package:treasure/core/network/cache_interceptor.dart';

class HomePage extends StatefulWidget {
  final List searchToyList;
  final Function search;
  final Function clearSearch;
  final Function(int)? onDataChanged; // 新增：数据变化回调

  const HomePage({
    Key? key,
    required this.searchToyList,
    required this.search,
    required this.clearSearch,
    this.onDataChanged, // 可选的数据变化回调
  }) : super(key: key);

  @override
  HomePageState createState() => HomePageState();
}

// 全局Key和实例管理
final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

// 静态方法用于外部调用主页刷新
class HomePageHelper {
  static Future<void> refreshHomePage() async {
    debugPrint('🔄 HomePageHelper: 尝试调用主页刷新...');

    // 方法1：使用GlobalKey
    if (homePageKey.currentState != null) {
      debugPrint('✅ HomePageHelper: 通过GlobalKey找到HomePage实例');
      await homePageKey.currentState!.refreshData();
      return;
    }

    debugPrint('⚠️ HomePageHelper: 无法找到HomePage实例，刷新失败');
  }

  // 通知HomePage数据已就绪，无需重新加载
  static void notifyDataReady() {
    debugPrint('📢 HomePageHelper: 通知HomePage数据已就绪...');

    if (homePageKey.currentState != null) {
      debugPrint('✅ HomePageHelper: 通过GlobalKey找到HomePage实例');
      homePageKey.currentState!._notifyDataReady();
      return;
    }

    debugPrint('⚠️ HomePageHelper: 无法找到HomePage实例');
  }
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _controller = ScrollController();
  late PaginationController<ToyModel> _paginationController;
  bool showBtn = false;
  bool uploading = false;
  final ImageCacheManager _imageCacheManager = ImageCacheManager();
  //动画
  late AnimationController _searchResultsController;
  late Animation<double> _searchResultsAnimation;
  late AnimationController _contentController;
  //late Animation<double> _contentAnimation;

  // 防止重复加载的标记
  bool _isInitialLoading = false;
  bool _hasExternalRefresh = false;

  @override
  void initState() {
    super.initState();

    // 添加生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // Initialize pagination controller
    _paginationController = PaginationController<ToyModel>(
      loadData: _loadToysData,
      pageSize: 20,
    );
    
    // Animation controller for search results
    _searchResultsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchResultsAnimation = CurvedAnimation(
      parent: _searchResultsController,
      curve: Curves.easeInOut,
    );
    
    // Animation controller for main content
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Start with content visible
    _contentController.forward();

    // 延迟加载初始数据，给外部刷新足够时间
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialDataWithDelay();
    });

    _controller.addListener(() {
      if (_controller.offset < 1000 && showBtn) {
        setState(() {
          showBtn = false;
        });
      } else if (_controller.offset >= 1000 && showBtn == false) {
        setState(() {
          showBtn = true;
        });
      }
      // Removed auto load more logic - now handled by OptimizedMasonryGrid
    });
  }

  // Load toys data for pagination
  Future<List<ToyModel>> _loadToysData(int page) async {
    return await PerformanceManager.instance.measureAsync(
      'load_toys_page_$page',
      () async {
        try {
          final uid = StateManager.readUserState(context).currentUser.uid;
      
      // 先尝试从缓存加载
      final cacheKey = 'toys_page_${page}_uid_$uid';
      final cachedData = await StorageService.instance.getCachedApiResponse(cacheKey);
      
      if (cachedData != null) {
        final toyList = (cachedData['toyList'] as List?)
            ?.map((json) => ToyModel.fromJson(json))
            .toList() ?? [];
        
        if (toyList.isNotEmpty) {
          // 异步预加载缓存的图片
          final imagesToPreload = toyList
              .map((toy) => {
                    'url': toy.toyPicUrl,
                    'name': toy.toyName,
                  })
              .toList();
          _imageCacheManager.preloadImages(imagesToPreload);
          
          return toyList;
        }
      }
      
      // 缓存未命中，从网络加载
      final response = await TreasureDao.getAllToies(page, uid);
      
      // 缓存API响应
      await StorageService.instance.cacheApiResponse(
        cacheKey,
        {
          'toyList': response.toyList.map((toy) => toy.toJson()).toList(),
          'page': page,
          'uid': uid,
        },
        expiry: const Duration(minutes: 30), // 30分钟缓存
      );
      
      // 同步到离线存储
      await StorageService.instance.syncToOffline(response.toyList);
      
      // 预加载图片以提升用户体验
      final imagesToPreload = response.toyList
          .map((toy) => {
                'url': toy.toyPicUrl,
                'name': toy.toyName,
              })
          .toList();
      
      // 异步预加载，不阻塞数据返回
      _imageCacheManager.preloadImages(imagesToPreload);
      
      return response.toyList;
    } catch (e) {
      // 网络错误时尝试使用离线数据
      debugPrint('❌ HomePage: 网络请求失败 (page: $page): $e');

      if (page == 1) { // 只在第一页时返回离线数据
        debugPrint('🔄 HomePage: 尝试使用离线数据...');
        final offlineData = await StorageService.instance.getOfflineData();
        if (offlineData.isNotEmpty) {
          debugPrint('✅ HomePage: 找到 ${offlineData.length} 条离线数据');
          // 显示离线数据提示
          if (mounted) {
            StateManager.uiState(context).setNetworkStatus(false);
          }
          return offlineData;
        } else {
          debugPrint('⚠️ HomePage: 没有可用的离线数据');
        }
      }

      debugPrint('❌ HomePage: 最终失败，重新抛出异常');
      throw Exception('网络连接失败，请检查网络设置: $e');
      }
      },
    );
  }

  // These methods are no longer needed with PaginationController

  // 刷新主页数据的方法
  Future<void> refreshData() async {
    debugPrint('🔄 HomePage: 开始刷新数据...');

    if (!mounted) {
      debugPrint('⚠️ HomePage: Widget已销毁，取消刷新');
      return;
    }

    // 设置外部刷新标记，防止初始加载冲突
    _hasExternalRefresh = true;

    try {
      final uid = StateManager.readUserState(context).currentUser.uid;
      debugPrint('👤 HomePage: 用户ID = $uid');

      // 1. 首先设置UI状态为加载中（仅在需要时）
      if (_paginationController.items.isEmpty) {
        debugPrint('🔄 HomePage: 设置加载状态...');
        if (mounted) {
          StateManager.readUIState(context).setComponentLoading('refresh_data', true);
        }
      }

      // 2. 清除相关的缓存数据（强制从服务器获取新数据）
      debugPrint('🗑️ HomePage: 清除缓存数据...');
      await CacheInterceptor.clearToysCache();

      // 3. 清除分页控制器的现有数据
      debugPrint('🧹 HomePage: 清除分页控制器数据...');
      _paginationController.clear();

      // 4. 减少延迟时间，优化用户体验
      await Future.delayed(const Duration(milliseconds: 200));

      // 5. 重新加载数据（从服务器获取最新数据）
      debugPrint('📡 HomePage: 开始重新加载数据...');
      await _paginationController.loadInitialData();

      if (mounted) {
        StateManager.readUIState(context).setComponentLoading('refresh_data', false);
        StateManager.readUIState(context).setNetworkStatus(true);
      }

      debugPrint('✅ HomePage: 数据刷新完成');
    } catch (e) {
      debugPrint('❌ HomePage: 刷新失败 - $e');

      if (mounted) {
        StateManager.readUIState(context).setComponentLoading('refresh_data', false);
        // 可以在这里显示错误提示
      }
    }
  }

  // 通知数据已就绪的方法
  void _notifyDataReady() {
    debugPrint('📢 HomePage: 收到数据就绪通知');
    _hasExternalRefresh = true;

    // 如果正在等待初始加载，触发一次加载
    if (_paginationController.items.isEmpty && !_isInitialLoading) {
      debugPrint('📢 HomePage: 数据为空，触发加载');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _paginationController.loadInitialData();
      });
    }
  }

  // 智能加载初始数据，避免与external refresh冲突
  Future<void> _loadInitialDataWithDelay() async {
    try {
      debugPrint('📱 HomePage: 开始智能初始加载...');

      if (_isInitialLoading) {
        debugPrint('📱 HomePage: 已在加载中，跳过');
        return;
      }

      _isInitialLoading = true;

      // 短暂延迟，让外部刷新有机会设置标记
      await Future.delayed(const Duration(milliseconds: 300));

      // 检查外部是否已刷新
      if (_hasExternalRefresh) {
        debugPrint('📱 HomePage: 检测到外部刷新，跳过初始加载');
        _isInitialLoading = false;
        return;
      }

      // 检查是否已有数据
      if (_paginationController.items.isNotEmpty) {
        debugPrint('📱 HomePage: 已有数据，跳过初始加载');
        _isInitialLoading = false;
        return;
      }

      debugPrint('📱 HomePage: 执行初始数据加载...');
      await _paginationController.loadInitialData();
      debugPrint('✅ HomePage: 初始数据加载完成');
    } catch (e) {
      debugPrint('❌ HomePage: 初始数据加载失败 - $e');
    } finally {
      _isInitialLoading = false;
    }
  }


  // 处理删除后的优化刷新（乐观更新策略）
  Future<void> _handleItemDeleted() async {
    debugPrint('🗑️ HomePage: 开始优化删除后刷新');

    if (!mounted) return;

    try {
      // 1. 使用优化的缓存清理，不阻塞UI
      CacheInterceptor.clearToysCache().catchError((e) {
        debugPrint('⚠️ HomePage: 缓存清理失败，但不影响UI: $e');
      });

      // 2. 直接刷新数据，无需等待缓存清理
      debugPrint('🔄 HomePage: 直接刷新数据...');

      // 延迟刷新避免多重loading状态
      await Future.delayed(const Duration(milliseconds: 300));
      _paginationController.refresh();

      // 3. 异步通知主页面数据变化
      if (widget.onDataChanged != null) {
        Future.microtask(() {
          if (mounted) {
            debugPrint('📢 HomePage: 通知主页面数据变化...');
            widget.onDataChanged!(1);
          }
        });
      }

      debugPrint('✅ HomePage: 优化删除后刷新完成');
    } catch (e) {
      debugPrint('❌ HomePage: 删除后刷新失败 - $e');
      // 如果静默刷新失败，则fallback到普通刷新
      _paginationController.refresh();
    }
  }


  // 实现 WidgetsBindingObserver 的生命周期方法
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 应用重新进入前台时，检查是否需要刷新数据
        debugPrint('📱 HomePage: 应用恢复前台，检查数据刷新需求');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 这里可以添加检查逻辑，比如检查上次刷新时间等
          debugPrint('🔄 HomePage: 应用恢复后准备刷新检查');
        });
        break;
      case AppLifecycleState.paused:
        debugPrint('📱 HomePage: 应用进入后台');
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 HomePage: 应用即将退出');
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 HomePage: 应用进入非活跃状态');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 HomePage: 应用被隐藏');
        break;
    }
  }

  @override
  void dispose() {
    // 移除生命周期监听器
    WidgetsBinding.instance.removeObserver(this);

    _searchController.dispose();
    _controller.dispose();
    _searchResultsController.dispose();
    _contentController.dispose();
    _paginationController.dispose();
    super.dispose();
  }


  void _search(String value) async {
    if (_searchController.text.trim().isEmpty) return;
    
    StateManager.uiState(context).setComponentLoading('search', true);
    
    try {
      final query = _searchController.text.trim();
      
      // 先尝试从缓存获取搜索结果
      final cachedResults = await StorageService.instance.getCachedSearchResults(query);
      if (cachedResults != null && cachedResults.isNotEmpty) {
        widget.search(cachedResults);
        _searchResultsController.forward();
        _contentController.reverse();
        if (mounted) {
          StateManager.uiState(context).setComponentLoading('search', false);
        }
        return;
      }
      
      // 执行网络搜索
      widget.search(query);
      
      // 动画显示搜索结果
      _searchResultsController.forward();
      _contentController.reverse();
      
    } catch (e) {
      // 搜索失败时尝试离线搜索
      try {
        final offlineResults = await StorageService.instance.searchOffline(_searchController.text.trim());
        if (offlineResults.isNotEmpty) {
          widget.search(offlineResults);
          _searchResultsController.forward();
          _contentController.reverse();
        }
      } catch (offlineError) {
        debugPrint('离线搜索失败: $offlineError');
      }
    } finally {
      if (mounted) {
        StateManager.uiState(context).setComponentLoading('search', false);
      }
    }
  }

  void clear() {
    _searchController.clear();
    widget.clearSearch();
    _searchResultsController.reverse().then((_) {
      if (mounted) {
        widget.clearSearch();
        _contentController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: TextField(
                onSubmitted: _search,
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索...',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16.0, 12.0, 12.0, 12.0),
                  suffixIcon: widget.searchToyList.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: clear
                  )
                  :IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _search(_searchController.text),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
            ),
          ),
          widget.searchToyList.isNotEmpty
          ?Center(
            //padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            //alignment: Alignment.centerLeft,
            child: Text(
              '找到 ${widget.searchToyList.length} 个相关结果',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          )
          :const SizedBox.shrink(),
          SizeTransition(
            sizeFactor: _searchResultsAnimation,
            child: FadeTransition(
              opacity: _searchResultsAnimation,
              child: widget.searchToyList.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rowCount = (widget.searchToyList.length / 2).ceil();
                      final itemHeight = (MediaQuery.of(context).size.width / 2); // childAspectRatio=1 时，高≈宽
                      final gridHeight = rowCount * itemHeight + (rowCount - 1) * 8;
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.6, // 限制最大高度
                        ),
                        child: GridView.builder(
                          shrinkWrap: gridHeight < MediaQuery.of(context).size.height * 0.6, 
                          padding: EdgeInsets.zero,
                          physics: gridHeight < MediaQuery.of(context).size.height * 0.6
                            ? const NeverScrollableScrollPhysics()
                            : const AlwaysScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: widget.searchToyList.length,
                          itemBuilder: (context, index) {
                            final toy = widget.searchToyList[index];
                            return GestureDetector(
                              onTap: () => CommonUtils.showDetail(context, index, widget.searchToyList, (page) async {
                                await _paginationController.refresh();
                                // 触发数据变化回调来更新总价值
                                if (widget.onDataChanged != null) {
                                  widget.onDataChanged!(1);
                                }
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[200],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: ImageWithFallback(
                                        toy: toy,
                                        width: MediaQuery.of(context).size.width / 2,
                                      ),    
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          toy.toyName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  )
                )
              : const SizedBox.shrink()
            )
          ),
          widget.searchToyList.isNotEmpty
          ?const Divider()
          :const SizedBox.shrink(),
          Expanded(
            child: OptimizedMasonryGrid<ToyModel>(
              controller: _paginationController,
              scrollController: _controller,
              crossAxisCount: 2,
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              padding: EdgeInsets.zero,
              itemBuilder: (context, toy, index) {
                return _Item(
                  key: ValueKey(toy.id),
                  index: index,
                  toy: toy,
                  onTap: () => CommonUtils.showDetail(
                    context, 
                    index, 
                    _paginationController.items, 
                    (page) async {
                      await _paginationController.refresh();
                      // 触发数据变化回调来更新总价值
                      if (widget.onDataChanged != null) {
                        widget.onDataChanged!(1);
                      }
                    },
                  ),
                  onDeleted: () => _handleItemDeleted(),
                );
              },
              loadingWidget: const Center(child: CircularProgressIndicator()),
              emptyWidget: const Center(
                child: Text('暂无数据', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
              loadingMoreWidget: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: showBtn
      ? FloatingActionButton(
        onPressed: (){
          _controller.animateTo(.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.ease
          );
        },
        backgroundColor: Colors.black,
        heroTag: 3,
        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 40),
      ): null
    );
  }
}

class _Item extends StatelessWidget {
  final int index;
  final ToyModel toy;
  final VoidCallback onTap;
  final VoidCallback? onDeleted;

  const _Item({
    Key? key,
    required this.index,
    required this.toy,
    required this.onTap,
    this.onDeleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除宝贝'),
              content:  const Text('请谨慎操作'),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    // 第一个按钮的操作
                    Navigator.of(context).pop();
                  },
                  child: const Text('不删了'),
                ),
                TextButton(
                  onPressed: () async{
                    try {
                      debugPrint('🗑️ 开始删除物品');
                      debugPrint('🗑️ toy.id: "${toy.id}"');
                      debugPrint('🗑️ toy.toyName: "${toy.toyName}"');
                      debugPrint('🗑️ toy对象完整信息: ${toy.toJson()}');

                      // 安全提取图片URL的key部分
                      String imageKey = '';
                      if (toy.toyPicUrl.isNotEmpty) {
                        if (toy.toyPicUrl.startsWith('http://nextsticker.xyz/')) {
                          imageKey = toy.toyPicUrl.substring('http://nextsticker.xyz/'.length);
                        } else if (toy.toyPicUrl.startsWith('https://nextsticker.cn/')) {
                          imageKey = toy.toyPicUrl.substring('https://nextsticker.cn/'.length);
                        } else {
                          // 如果URL格式不匹配，尝试提取文件名
                          final uri = Uri.tryParse(toy.toyPicUrl);
                          if (uri != null && uri.pathSegments.isNotEmpty) {
                            imageKey = uri.pathSegments.last;
                          }
                        }
                      }

                      debugPrint('🗑️ 提取的图片key: $imageKey');

                      // 调用删除API
                      ResultModel result = await TreasureDao.deleteToy(toy.id, imageKey);
                      debugPrint('🗑️ 删除API响应: ${result.deletedCount}');

                      if(result.deletedCount == 1){
                        // 尝试删除本地文件
                        try {
                          if (toy.toyPicUrl.isNotEmpty) {
                            await CommonUtils.deleteLocalFilesAsync([CommonUtils.removeBaseUrl(toy.toyPicUrl)]);
                            debugPrint('✅ 本地文件删除成功');
                          }
                        } catch (e) {
                          debugPrint('⚠️ 删除本地文件时出错: $e');
                          // 本地文件删除失败不影响整体删除流程
                        }

                        if (!context.mounted) return;

                        // 先关闭对话框
                        Navigator.of(context).pop();

                        // 显示成功提示（优先显示）
                        if (context.mounted) {
                          CommonUtils.showSnackBar(context, '删除成功', backgroundColor: Colors.green);
                        }

                        // 延迟调用删除回调，给用户看到成功提示的时间
                        Future.delayed(const Duration(milliseconds: 100), () {
                          debugPrint('🔄 调用删除回调刷新列表');
                          onDeleted?.call();
                        });

                        debugPrint('✅ 物品删除完成');
                      } else {
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        CommonUtils.show(context, '删除失败，请稍后再试');
                        debugPrint('❌ 删除失败: deletedCount=${result.deletedCount}');
                      }
                    } catch (e) {
                      debugPrint('❌ 删除过程中发生错误: $e');
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      CommonUtils.show(context, '删除失败: $e');
                    }
                  },
                  child: const Text('删除'),
                ),
              ],
            );
          },
        )
      },
      child: Card(
        child: PhysicalModel(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageWithFallback(
                    toy: toy,
                    width: MediaQuery.of(context).size.width / 2,
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(toy.toyName, style: const TextStyle(fontSize: 15)),
                        toy.isSelled
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SOLD',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        : Container()
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}