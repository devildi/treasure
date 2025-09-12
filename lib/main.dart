import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/pages/user.dart';
import 'package:treasure/pages/login.dart';
import 'package:treasure/pages/edit.dart';
import 'package:treasure/toy_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'tools.dart';
import 'dao.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/state/ui_state.dart';
import 'package:treasure/core/storage/storage_service.dart';
import 'package:treasure/core/performance/performance_manager.dart';
import 'package:treasure/core/performance/memory_optimizer.dart';
import 'package:treasure/components/skeleton_loading.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'package:treasure/core/navigation/page_transitions.dart';
import 'package:treasure/components/network_status.dart';

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
  
  // 加载用户数据
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String userDataString = prefs.getString('auth') ?? '';
  OwnerModel userDataConvert;
  
  if (userDataString.isNotEmpty) {
    try {
      dynamic obj = json.decode(userDataString);
      userDataConvert = OwnerModel.fromJson(obj);
    } catch (e) {
      debugPrint('解析用户数据失败: $e');
      userDataConvert = OwnerModel();
    }
  } else {
    userDataConvert = OwnerModel();
  }

  // 创建初始用户状态
  final initialUserState = UserStateData(
    user: userDataConvert,
    isLoggedIn: userDataConvert.uid.isNotEmpty,
    lastLoginTime: userDataConvert.uid.isNotEmpty ? DateTime.now() : null,
  );

  // 创建初始UI状态
  const initialUIState = UIStateData(
    currentPageIndex: 0,
    isNetworkAvailable: true,
    isOfflineMode: false,
  );

  runApp(
    StateProviders(
      initialUserState: initialUserState,
      initialUIState: initialUIState,
      child: const NetworkStatusProvider(
        checkInterval: Duration(seconds: 30),
        child: MyApp(),
      ),
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
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  List toyList = [];
  List searchToyList = [];
  int toyCount = 0;
  double totalValue = 0.0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StateManager.readUIState(context).setComponentLoading('main_data', true);
      initData(1);
    });
  }

  void initData(page) async {
    try {
      final currentUser = StateManager.readUserState(context).currentUser;
      List<Future> tasks = [];
      tasks.add(TreasureDao.getAllToies(page, currentUser.uid));
      tasks.add(TreasureDao.getTotalPriceAndCount(currentUser.uid));
      List body = await Future.wait(tasks);
      setState(() {
        toyList = body[0].toyList;
        toyCount = body[1].count;
        totalValue = body[1].totalPrice.toDouble();
      });
      if (!mounted) return;
      StateManager.readUIState(context).setComponentLoading('main_data', false);
    } catch (e) {
      if (!mounted) return;
      StateManager.readUIState(context).setNetworkStatus(false);
      StateManager.readUIState(context).setComponentLoading('main_data', false);
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！', backgroundColor: Colors.red);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void jump(user) async {
    await AppNavigator.push(
      context,
      EditMicro(
        user: user,
        initData: initData,
      ),
      type: PageTransitionType.slideScale,
      direction: SlideDirection.fromBottom,
    );
    // 刷新数据
    initData(1);
  }

  void search(String keyword) async {
    final currentUser = StateManager.readUserState(context).currentUser;
    AllToysModel toies = await TreasureDao.searchToies(keyword, currentUser.uid);
    if (toies.toyList.isEmpty) {
      if (!mounted) return;
      CommonUtils.show(context, '没有找到相关宝藏');
      StateManager.readUIState(context).setComponentLoading('search', false);
      return;
    }
    setState(() {
      searchToyList = toies.toyList;
      StateManager.readUIState(context).setComponentLoading('search', false);
    });
  }

  void clearSearch() {
    setState(() {
      searchToyList = [];
    });
  }

  Future<void> _addMoreData(index) async {
    try {
      final currentUser = StateManager.readUserState(context).currentUser;
      AllToysModel toies = await TreasureDao.getAllToies(index, currentUser.uid);
      setState(() {
        toyList = toies.toyList;
        StateManager.readUIState(context).setNetworkStatus(true);
      });
    } catch (err) {
      if (!mounted) return;
      CommonUtils.showSnackBar(context, '网络异常，请稍后再试！', backgroundColor: Colors.red);
      StateManager.readUIState(context).setNetworkStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UserStateSelector<bool>(
      selector: (userState) => userState.isLoggedIn,
      builder: (context, isLoggedIn, child) {
        if (!isLoggedIn) {
          return const Login();
        }
        
        return UIStateSelector<bool>(
          selector: (uiState) => uiState.isComponentLoading('main_data'),
          builder: (context, isLoading, child) {
            if (isLoading) {
              return _buildLoadingSkeleton();
            }
            
            final currentUser = StateManager.readUserState(context).currentUser;
            
            return NetworkAwareWidget(
              child: Scaffold(
                body: Column(
                  children: [
                    const NetworkStatusBanner(),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        children: [
                          HomePage(
                            searchToyList: searchToyList,
                            search: search,
                            clearSearch: clearSearch,
                          ),
                          ProfilePage(
                            user: currentUser,
                            totalValue: totalValue,
                            toyCount: toyCount,
                            toies: toyList,
                            getMore: _addMoreData,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                floatingActionButton: Transform.translate(
                  offset: const Offset(0, 10),
                  child: AnimatedButton(
                    onPressed: () {
                      InteractiveFeedback.hapticFeedback(type: HapticFeedbackType.medium);
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
                ),
                floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                bottomNavigationBar: SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                    ),
                    height: 72, // 增加高度来容纳内容
                    child: Row(
                      children: [
                        Expanded(child: _buildNavItem(0, Icons.home, '首页')),
                        Expanded(child: Container()),
                        Expanded(child: _buildNavItem(1, Icons.person, '我的')),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          HomePageSkeleton(),
          ProfilePageSkeleton(),
        ],
      ),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 10),
        child: FloatingActionButton(
          onPressed: null,
          backgroundColor: Colors.grey[300],
          elevation: 0,
          child: Icon(Icons.add, size: 40, color: Colors.grey[500]),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1.0,
              ),
            ),
          ),
          height: 72,
          child: Row(
            children: [
              Expanded(child: _buildNavItem(0, Icons.home, '首页')),
              Expanded(child: Container()),
              Expanded(child: _buildNavItem(1, Icons.person, '我的')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return RippleButton(
      onPressed: () {
        if (!isSelected) {
          InteractiveFeedback.hapticFeedback();
          setState(() {
            _currentIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          });
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.grey[600],
                size: isSelected ? 24 : 22,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}