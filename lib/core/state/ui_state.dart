import 'package:treasure/core/state/app_state.dart';

/// UI状态数据模型
class UIStateData {
  final int currentPageIndex;
  final int previousPageIndex;
  final bool isNetworkAvailable;
  final bool isOfflineMode;
  final Map<String, bool> loadingStates;
  final List<String> navigationHistory;

  const UIStateData({
    this.currentPageIndex = 0,
    this.previousPageIndex = 0,
    this.isNetworkAvailable = true,
    this.isOfflineMode = false,
    this.loadingStates = const {},
    this.navigationHistory = const [],
  });

  UIStateData copyWith({
    int? currentPageIndex,
    int? previousPageIndex,
    bool? isNetworkAvailable,
    bool? isOfflineMode,
    Map<String, bool>? loadingStates,
    List<String>? navigationHistory,
  }) {
    return UIStateData(
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      previousPageIndex: previousPageIndex ?? this.previousPageIndex,
      isNetworkAvailable: isNetworkAvailable ?? this.isNetworkAvailable,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      loadingStates: loadingStates ?? this.loadingStates,
      navigationHistory: navigationHistory ?? this.navigationHistory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UIStateData &&
        other.currentPageIndex == currentPageIndex &&
        other.previousPageIndex == previousPageIndex &&
        other.isNetworkAvailable == isNetworkAvailable &&
        other.isOfflineMode == isOfflineMode;
  }

  @override
  int get hashCode {
    return currentPageIndex.hashCode ^
           previousPageIndex.hashCode ^
           isNetworkAvailable.hashCode ^
           isOfflineMode.hashCode;
  }

  @override
  String toString() {
    return 'UIStateData(page: $currentPageIndex, network: $isNetworkAvailable)';
  }
}

/// UI状态管理器
class UIState extends AppState<UIStateData> {
  static const int maxNavigationHistorySize = 20;

  UIState({UIStateData? initialState}) : super(initialState ?? const UIStateData());

  /// 当前页面索引
  int get currentPage => state.currentPageIndex;

  /// 上一个页面索引
  int get previousPage => state.previousPageIndex;

  /// 网络是否可用
  bool get isNetworkAvailable => state.isNetworkAvailable;

  /// 是否处于离线模式
  bool get isOfflineMode => state.isOfflineMode;

  /// 导航历史
  List<String> get navigationHistory => List.unmodifiable(state.navigationHistory);

  /// 切换页面
  void setCurrentPage(int pageIndex) {
    if (state.currentPageIndex != pageIndex) {
      updateState(state.copyWith(
        previousPageIndex: state.currentPageIndex,
        currentPageIndex: pageIndex,
      ));
    }
  }

  /// 返回上一页
  void goToPreviousPage() {
    if (state.previousPageIndex != state.currentPageIndex) {
      setCurrentPage(state.previousPageIndex);
    }
  }

  /// 设置网络状态
  void setNetworkStatus(bool isAvailable) {
    if (state.isNetworkAvailable != isAvailable) {
      final newState = state.copyWith(
        isNetworkAvailable: isAvailable,
        // 网络不可用时自动进入离线模式
        isOfflineMode: !isAvailable ? true : state.isOfflineMode,
      );
      updateState(newState);
    }
  }

  /// 切换离线模式
  void toggleOfflineMode() {
    updateState(state.copyWith(
      isOfflineMode: !state.isOfflineMode,
    ));
  }

  /// 设置特定组件的加载状态
  void setComponentLoading(String componentId, bool isLoading) {
    final newLoadingStates = Map<String, bool>.from(state.loadingStates);
    
    if (isLoading) {
      newLoadingStates[componentId] = true;
    } else {
      newLoadingStates.remove(componentId);
    }
    
    updateState(state.copyWith(loadingStates: newLoadingStates));
  }

  /// 检查特定组件是否正在加载
  bool isComponentLoading(String componentId) {
    return state.loadingStates[componentId] ?? false;
  }

  /// 是否有任何组件正在加载
  bool get hasAnyComponentLoading => state.loadingStates.isNotEmpty;

  /// 获取正在加载的组件列表
  List<String> get loadingComponents => state.loadingStates.keys.toList();

  /// 清除所有组件加载状态
  void clearAllLoadingStates() {
    if (state.loadingStates.isNotEmpty) {
      updateState(state.copyWith(loadingStates: const {}));
    }
  }

  /// 添加导航记录
  void addToNavigationHistory(String routeName) {
    final newHistory = List<String>.from(state.navigationHistory);
    newHistory.add(routeName);
    
    // 限制历史记录大小
    if (newHistory.length > maxNavigationHistorySize) {
      newHistory.removeAt(0);
    }
    
    updateState(state.copyWith(navigationHistory: newHistory));
  }

  /// 清除导航历史
  void clearNavigationHistory() {
    if (state.navigationHistory.isNotEmpty) {
      updateState(state.copyWith(navigationHistory: const []));
    }
  }

  /// 批量执行UI更新（减少重建）
  void batchUIUpdate(void Function(UIStateBatchUpdater updater) updates) {
    final updater = UIStateBatchUpdater._(state);
    updates(updater);
    
    if (updater._hasChanges) {
      updateState(updater._newState);
    }
  }

  /// 重置UI状态到初始状态
  void reset() {
    updateState(const UIStateData());
  }

  /// 获取当前状态摘要（用于调试）
  Map<String, dynamic> getStateSummary() {
    return {
      'currentPage': currentPage,
      'previousPage': previousPage,
      'networkAvailable': isNetworkAvailable,
      'offlineMode': isOfflineMode,
      'loadingComponents': loadingComponents,
      'navigationHistorySize': navigationHistory.length,
      'hasError': hasError,
      'error': error,
    };
  }
}

/// UI状态批量更新器
class UIStateBatchUpdater {
  UIStateData _newState;
  bool _hasChanges = false;

  UIStateBatchUpdater._(UIStateData currentState) : _newState = currentState;

  /// 设置页面索引
  void setPage(int pageIndex) {
    if (_newState.currentPageIndex != pageIndex) {
      _newState = _newState.copyWith(
        previousPageIndex: _newState.currentPageIndex,
        currentPageIndex: pageIndex,
      );
      _hasChanges = true;
    }
  }

  /// 设置网络状态
  void setNetwork(bool isAvailable) {
    if (_newState.isNetworkAvailable != isAvailable) {
      _newState = _newState.copyWith(
        isNetworkAvailable: isAvailable,
        isOfflineMode: !isAvailable ? true : _newState.isOfflineMode,
      );
      _hasChanges = true;
    }
  }

  /// 设置组件加载状态
  void setComponentLoading(String componentId, bool isLoading) {
    final newLoadingStates = Map<String, bool>.from(_newState.loadingStates);
    
    if (isLoading) {
      newLoadingStates[componentId] = true;
    } else {
      newLoadingStates.remove(componentId);
    }
    
    _newState = _newState.copyWith(loadingStates: newLoadingStates);
    _hasChanges = true;
  }

  /// 添加导航记录
  void addNavigationHistory(String routeName) {
    final newHistory = List<String>.from(_newState.navigationHistory);
    newHistory.add(routeName);
    
    if (newHistory.length > UIState.maxNavigationHistorySize) {
      newHistory.removeAt(0);
    }
    
    _newState = _newState.copyWith(navigationHistory: newHistory);
    _hasChanges = true;
  }
}