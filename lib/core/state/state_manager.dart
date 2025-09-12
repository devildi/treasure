import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/state/ui_state.dart';
import 'package:treasure/core/state/state_persistence.dart';
import 'package:treasure/toy_model.dart';

/// 状态管理器工厂
class StateManagerFactory {
  static UserState? _userState;
  static UIState? _uiState;

  /// 创建用户状态管理器
  static UserState createUserState({
    UserStateData? initialState,
    StatePersistence? persistence,
  }) {
    _userState?.dispose();
    _userState = UserState(
      initialState: initialState,
      persistence: persistence,
    );
    return _userState!;
  }

  /// 创建UI状态管理器
  static UIState createUIState({UIStateData? initialState}) {
    _uiState?.dispose();
    _uiState = UIState(initialState: initialState);
    return _uiState!;
  }

  /// 获取用户状态管理器实例
  static UserState? get userState => _userState;

  /// 获取UI状态管理器实例
  static UIState? get uiState => _uiState;

  /// 销毁所有状态管理器
  static void dispose() {
    _userState?.dispose();
    _uiState?.dispose();
    _userState = null;
    _uiState = null;
  }
}

/// 状态Provider配置
class StateProviders extends StatelessWidget {
  final Widget child;
  final UserStateData? initialUserState;
  final UIStateData? initialUIState;
  final StatePersistence? persistence;

  const StateProviders({
    Key? key,
    required this.child,
    this.initialUserState,
    this.initialUIState,
    this.persistence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserState>(
          create: (_) => StateManagerFactory.createUserState(
            initialState: initialUserState,
            persistence: persistence,
          ),
          lazy: false,
        ),
        ChangeNotifierProvider<UIState>(
          create: (_) => StateManagerFactory.createUIState(
            initialState: initialUIState,
          ),
          lazy: false,
        ),
      ],
      child: child,
    );
  }
}

/// 状态管理工具类，提供便捷的上下文访问方法
class StateManager {
  StateManager._();

  /// 获取用户状态（不监听变化）
  static UserState userState(BuildContext context, {bool listen = false}) {
    return Provider.of<UserState>(context, listen: listen);
  }

  /// 获取UI状态（不监听变化）
  static UIState uiState(BuildContext context, {bool listen = false}) {
    return Provider.of<UIState>(context, listen: listen);
  }

  /// 监听用户状态变化
  static UserState watchUserState(BuildContext context) {
    return context.watch<UserState>();
  }

  /// 监听UI状态变化
  static UIState watchUIState(BuildContext context) {
    return context.watch<UIState>();
  }

  /// 读取用户状态（一次性读取）
  static UserState readUserState(BuildContext context) {
    return context.read<UserState>();
  }

  /// 读取UI状态（一次性读取）
  static UIState readUIState(BuildContext context) {
    return context.read<UIState>();
  }

  /// 批量状态更新（减少重建）
  static void batchUpdate(BuildContext context, VoidCallback updates) {
    updates();
  }

  /// 检查用户是否已登录
  static bool isLoggedIn(BuildContext context) {
    return userState(context).isLoggedIn;
  }

  /// 获取当前用户
  static OwnerModel getCurrentUser(BuildContext context) {
    return userState(context).currentUser;
  }

  /// 获取当前页面索引
  static int getCurrentPage(BuildContext context) {
    return uiState(context).currentPage;
  }

  /// 检查网络状态
  static bool isNetworkAvailable(BuildContext context) {
    return uiState(context).isNetworkAvailable;
  }

  /// 获取状态摘要信息（用于调试）
  static Map<String, dynamic> getStateSummary(BuildContext context) {
    final userSt = userState(context);
    final uiSt = uiState(context);

    return {
      'user': {
        'isLoggedIn': userSt.isLoggedIn,
        'userId': userSt.currentUser.uid,
        'hasError': userSt.hasError,
        'error': userSt.error,
        'isLoading': userSt.isLoading,
      },
      'ui': {
        'currentPage': uiSt.currentPage,
        'previousPage': uiSt.previousPage,
        'networkAvailable': uiSt.isNetworkAvailable,
        'offlineMode': uiSt.isOfflineMode,
        'hasError': uiSt.hasError,
        'error': uiSt.error,
        'loadingComponents': uiSt.loadingComponents,
      },
    };
  }
}

/// 状态选择器，用于精确控制组件重建
class StateSelector<T> extends StatelessWidget {
  final T Function(UserState userState, UIState uiState) selector;
  final Widget Function(BuildContext context, T data, Widget? child) builder;
  final Widget? child;

  const StateSelector({
    Key? key,
    required this.selector,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserState, UIState>(
      builder: (context, userState, uiState, child) {
        final data = selector(userState, uiState);
        return builder(context, data, child);
      },
      child: child,
    );
  }
}

/// 用户状态选择器
class UserStateSelector<T> extends StatelessWidget {
  final T Function(UserState userState) selector;
  final Widget Function(BuildContext context, T data, Widget? child) builder;
  final Widget? child;

  const UserStateSelector({
    Key? key,
    required this.selector,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<UserState, T>(
      selector: (context, userState) => selector(userState),
      builder: builder,
      child: child,
    );
  }
}

/// UI状态选择器
class UIStateSelector<T> extends StatelessWidget {
  final T Function(UIState uiState) selector;
  final Widget Function(BuildContext context, T data, Widget? child) builder;
  final Widget? child;

  const UIStateSelector({
    Key? key,
    required this.selector,
    required this.builder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<UIState, T>(
      selector: (context, uiState) => selector(uiState),
      builder: builder,
      child: child,
    );
  }
}

/// 状态调试工具
class StateDebugger {
  static bool _isEnabled = false;

  /// 启用状态调试
  static void enable() {
    _isEnabled = true;
  }

  /// 禁用状态调试
  static void disable() {
    _isEnabled = false;
  }

  /// 打印状态信息
  static void logState(BuildContext context, String message) {
    if (!_isEnabled) return;

    final summary = StateManager.getStateSummary(context);
    debugPrint('🔍 StateDebug [$message]: $summary');
  }

  /// 检查状态一致性
  static bool validateStateConsistency(BuildContext context) {
    if (!_isEnabled) return true;

    try {
      final userSt = StateManager.userState(context);
      final uiSt = StateManager.uiState(context);

      // 检查用户状态一致性
      if (userSt.isLoggedIn && userSt.currentUser.uid.isEmpty) {
        debugPrint('⚠️ State Inconsistency: User is logged in but has no UID');
        return false;
      }

      // 检查UI状态一致性
      if (uiSt.isOfflineMode && uiSt.isNetworkAvailable) {
        debugPrint('⚠️ State Inconsistency: Offline mode enabled but network is available');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ State Validation Error: $e');
      return false;
    }
  }
}