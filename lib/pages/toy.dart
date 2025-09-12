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
import 'package:treasure/core/performance/memory_optimizer.dart';

class HomePage extends StatefulWidget {
  final List searchToyList;
  final Function search;
  final Function clearSearch;
  
  const HomePage({
    Key? key, 
    required this.searchToyList,
    required this.search,
    required this.clearSearch,
  }) : super(key: key);
  
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    
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
      if (page == 0) { // 只在第一页时返回离线数据
        final offlineData = await StorageService.instance.getOfflineData();
        if (offlineData.isNotEmpty) {
          // 显示离线数据提示
          if (mounted) {
            StateManager.uiState(context).setComponentLoading('offline_mode', true);
          }
          return offlineData;
        }
        }
        throw Exception('Failed to load toys: $e');
      }
      },
    );
  }

  // These methods are no longer needed with PaginationController

  @override
  void dispose() {
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
                              onTap: () => CommonUtils.showDetail(context, index, widget.searchToyList, (page) => _paginationController.refresh()),
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
                    (page) => _paginationController.refresh(),
                  ),
                  onDeleted: () => _paginationController.refresh(),
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
                    // 第二个按钮的操作
                    ResultModel result = await TreasureDao.deleteToy(toy.id, toy.toyPicUrl.substring('http://nextsticker.xyz/'.length));
                    
                    if(result.deletedCount == 1){
                      try {
                        await CommonUtils.deleteLocalFilesAsync([CommonUtils.removeBaseUrl(toy.toyPicUrl)]);
                      } catch (e) {
                        debugPrint('删除文件时出错: $e');
                      }
                      if (!context.mounted) return;
                      onDeleted?.call();
                      if (!context.mounted) return;
                      CommonUtils.show(context, '删除成功');
                      Navigator.of(context).pop();
                    } else {
                      if (!context.mounted) return;
                      CommonUtils.show(context, '删除失败，请稍后再试');
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