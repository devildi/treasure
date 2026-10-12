import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/pages/user.dart';
// import 'package:treasure/pages/login.dart';
import 'package:treasure/pages/edit.dart';
import 'package:treasure/toy_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tools.dart';
import 'dao.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/state/ui_state.dart';
import 'package:treasure/core/state/state_persistence.dart';
import 'package:treasure/core/storage/storage_service.dart';
import 'package:treasure/core/performance/performance_manager.dart';
import 'package:treasure/core/performance/memory_optimizer.dart';
// import 'package:treasure/components/skeleton_loading.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'package:treasure/core/navigation/page_transitions.dart';
// import 'package:treasure/components/network_status.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务
  await StorageService.instance.initialize();

  // 初始化性能监控
  PerformanceManager.instance.startMonitoring(
    onMemoryWarning: () {
      if (kDebugMode) {
        debugPrint('⚠️ 内存警告触发，开始清理缓存');
      }
      MemoryOptimizer.instance.clearAllCaches();
    },
    onMemoryCritical: () {
      if (kDebugMode) {
        debugPrint('🚨 内存严重不足，强制垃圾回收');
      }
      PerformanceManager.instance.triggerGarbageCollection();
    },
  );

  // 初始化内存优化器
  MemoryOptimizer.instance.initialize();

  // 【单机模式】优先读取本地持久化用户状态，若无则使用默认单机用户
  final persistence = StatePersistence();
  final savedUserState = await persistence.load('user_state');
  UserStateData initialUserState;

  if (savedUserState != null) {
    try {
      final loadedState = UserStateData.fromJson(savedUserState);
      initialUserState = loadedState.copyWith(
        isLoggedIn: true,
        user: loadedState.user.uid.isNotEmpty
            ? loadedState.user
            : loadedState.user.copyWith(uid: 'local_user'),
      );
    } catch (e) {
      debugPrint('解析用户状态失败: $e');
      initialUserState = UserStateData(
        user: OwnerModel(
          uid: 'local_user',
          name: '玩具收藏家',
          avatar: '',
        ),
        isLoggedIn: true,
        lastLoginTime: DateTime.now(),
      );
    }
  } else {
    // 兼容历史 SharedPreferences 'auth'
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('auth') ?? '';
    OwnerModel user = OwnerModel(
      uid: 'local_user',
      name: '玩具收藏家',
      avatar: '',
    );
    if (userDataString.isNotEmpty) {
      try {
        final obj = json.decode(userDataString);
        if (obj is Map<String, dynamic>) {
          user = OwnerModel.fromJson(obj);
          if (user.uid.isEmpty) {
            user = user.copyWith(uid: 'local_user');
          }
        }
      } catch (e) {
        debugPrint('解析auth失败: $e');
      }
    }
    initialUserState = UserStateData(
      user: user,
      isLoggedIn: true,
      lastLoginTime: DateTime.now(),
    );
  }

  // 创建初始UI状态（单机模式）
  const initialUIState = UIStateData(
    currentPageIndex: 0,
    isNetworkAvailable: true,
    isOfflineMode: true,
  );

  runApp(
    StateProviders(
      initialUserState: initialUserState,
      initialUIState: initialUIState,
      persistence: persistence,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '上新了宝贝',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  final PageController _pageController = PageController();
  List<ToyModel> toyList = [];
  List<ToyModel> searchToyList = [];
  int toyCount = 0;
  double totalValue = 0.0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 【单机模式】直接加载本地数据，不再设置骨架屏加载状态，避免启动闪烁
      initData(1);
    });
  }

  void initData(page) async {
    try {
      debugPrint('🔄 Main.initData: 开始刷新数据 (page: $page)...');
      final currentUser = StateManager.readUserState(context).currentUser;
      debugPrint('👤 Main.initData: 当前用户 uid=${currentUser.uid}');

      // 【单机模式】已注释掉网络接口缓存清除
      /*
      // 清除主页面相关缓存
      debugPrint('🗑️ Main.initData: 清除缓存...');
      await StorageService.instance
          .clearCachedApiResponse('toys_page_${page}_uid_${currentUser.uid}');
      if (currentUser.uid.isNotEmpty) {
        await StorageService.instance
            .clearCachedApiResponse('total_price_count_${currentUser.uid}');
      }
      */

      debugPrint('📡 Main.initData: 加载单机本地数据...');
      List<Future> tasks = [];
      tasks.add(TreasureDao.getAllToies(page, currentUser.uid));
      if (currentUser.uid.isNotEmpty) {
        tasks.add(TreasureDao.getTotalPriceAndCount(currentUser.uid));
      } else {
        tasks.add(Future.value(PriceCountModel(totalPrice: 0, count: 0)));
      }
      List body = await Future.wait(tasks);

      debugPrint('📝 Main.initData: 更新本地状态...');
      debugPrint('   - 获得玩具数量: ${body[0].toyList.length}');
      debugPrint('   - 总数量: ${body[1].count}');
      debugPrint('   - 总价值: ${body[1].totalPrice}');

      if (!mounted) return;
      setState(() {
        toyList = body[0].toyList;
        toyCount = body[1].count;
        totalValue = body[1].totalPrice.toDouble();
      });

      debugPrint('📊 Main.initData: "我的"页面数据已更新');
      debugPrint('   - toyList.length: ${toyList.length}');
      debugPrint('   - toyCount: $toyCount');
      debugPrint('   - totalValue: $totalValue');

      // 通知HomePage数据已准备就绪，无需重新加载
      debugPrint('🔄 Main.initData: 通知HomePage数据已就绪...');
      HomePageHelper.notifyDataReady();

      if (!mounted) return;
      // 【单机模式】已移除骨架屏 loading 状态变更
      // StateManager.readUIState(context).setComponentLoading('main_data', false);
      debugPrint('✅ Main.initData: 数据刷新完成');
    } catch (e) {
      debugPrint('❌ Main.initData: 数据刷新失败 - $e');
      if (!mounted) return;
      StateManager.readUIState(context).setNetworkStatus(false);
      // StateManager.readUIState(context).setComponentLoading('main_data', false);
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！',
          backgroundColor: Colors.red);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openHome() {
    InteractiveFeedback.hapticFeedback();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _openProfile() {
    InteractiveFeedback.hapticFeedback();
    FocusScope.of(context).unfocus();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void jump(user) async {
    // 【单机模式】单机免登录，直接进入添加/编辑页面
    /*
    final userState = StateManager.readUserState(context);
    if (!userState.isLoggedIn || user.uid.isEmpty) {
      InteractiveFeedback.hapticFeedback();
      final loggedIn = await AppNavigator.push<bool>(
        context,
        const Login(),
        type: PageTransitionType.slideScale,
        direction: SlideDirection.fromBottom,
      );
      if (loggedIn == true ||
          (mounted && StateManager.readUserState(context).isLoggedIn)) {
        initData(1);
        await HomePageHelper.refreshHomePage();
        if (mounted) {
          final updatedUser = StateManager.readUserState(context).currentUser;
          if (updatedUser.uid.isNotEmpty) {
            jump(updatedUser);
          }
        }
      }
      return;
    }
    */

    debugPrint('🚀 Main.jump: 打开编辑页面...');
    await AppNavigator.push(
      context,
      EditMicro(
        user: user,
        initData: initData,
      ),
      type: PageTransitionType.slideScale,
      direction: SlideDirection.fromBottom,
    );

    debugPrint('🔄 Main.jump: 编辑页面返回，强制刷新HomePage...');
    // 页面返回后，强制刷新HomePage确保显示最新数据
    await HomePageHelper.refreshHomePage();
    initData(1);

    if (mounted) {
      setState(() {
        // 触发UI刷新，确保任何状态变化都能正确显示
      });
    }
    debugPrint('✅ Main.jump: 刷新完成');
  }

  Future<List<ToyModel>> search(String keyword) async {
    final currentUser = StateManager.readUserState(context).currentUser;
    AllToysModel toies =
        await TreasureDao.searchToies(keyword, currentUser.uid);
    if (toies.toyList.isEmpty) {
      if (!mounted) return [];
      CommonUtils.show(context, '没有找到相关宝藏');
      StateManager.readUIState(context).setComponentLoading('search', false);
      return [];
    }
    setState(() {
      searchToyList = toies.toyList;
    });
    return searchToyList;
  }

  void clearSearch() {
    setState(() {
      searchToyList = [];
    });
  }

  Future<void> _addMoreData(index) async {
    try {
      final currentUser = StateManager.readUserState(context).currentUser;
      if (currentUser.uid.isEmpty) return;
      AllToysModel toies =
          await TreasureDao.getAllToies(index, currentUser.uid);
      if (!mounted) return;
      setState(() {
        if (index <= 1) {
          toyList = toies.toyList;
        } else {
          toyList = [...toyList, ...toies.toyList];
        }
        StateManager.readUIState(context).setNetworkStatus(true);
      });
    } catch (err) {
      if (!mounted) return;
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！',
          backgroundColor: Colors.red);
      StateManager.readUIState(context).setNetworkStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 【单机模式】直接展示主界面，不再显示骨架屏闪烁
    return UserStateSelector<OwnerModel>(
      selector: (userState) => userState.currentUser,
      builder: (context, currentUser, child) {
        // 【单机模式】注释掉 NetworkAwareWidget 和 NetworkStatusBanner，纯单机展示
        return Scaffold(
          body: PageView(
            physics: const NeverScrollableScrollPhysics(), // 禁用滑动切换
            controller: _pageController,
            children: [
              HomePage(
                key: homePageKey,
                searchToyList: searchToyList,
                search: search,
                clearSearch: clearSearch,
                onSearchResults: (results) {
                  setState(() {
                    searchToyList = results;
                  });
                },
                onDataChanged: initData, // 传递数据变化回调
                onOpenProfile: _openProfile,
              ),
              ProfilePage(
                user: currentUser,
                totalValue: totalValue,
                toyCount: toyCount,
                toies: currentUser.uid.isNotEmpty ? toyList : const [],
                getMore: _addMoreData,
                onBack: _openHome,
                onDataChanged: initData,
              ),
            ],
          ),
          floatingActionButton: AnimatedButton(
            onPressed: () {
              InteractiveFeedback.hapticFeedback(
                  type: HapticFeedbackType.medium);
              jump(currentUser);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 40, color: Colors.white),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  // 【单机模式】已注释未使用的骨架屏组件，避免启动闪烁
  /*
  Widget _buildLoadingSkeleton() {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: const [
          HomePageSkeleton(),
          ProfilePageSkeleton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        backgroundColor: Colors.grey[300],
        elevation: 0,
        child: Icon(Icons.add, size: 40, color: Colors.grey[500]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
  */
}
