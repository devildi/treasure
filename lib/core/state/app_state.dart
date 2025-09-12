import 'package:flutter/foundation.dart';

/// 应用状态基类，提供通用的状态管理功能
abstract class AppState<T> extends ChangeNotifier {
  T _state;
  bool _isLoading = false;
  String? _error;
  bool _isDisposed = false;

  AppState(this._state);

  /// 当前状态
  T get state => _state;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 错误信息
  String? get error => _error;

  /// 是否有错误
  bool get hasError => _error != null;

  /// 是否已销毁
  bool get isDisposed => _isDisposed;

  /// 更新状态
  @protected
  void updateState(T newState, {bool shouldNotify = true}) {
    if (_isDisposed) return;
    
    if (_state != newState) {
      _state = newState;
      _error = null; // 清除之前的错误
      
      if (shouldNotify) {
        notifyListeners();
      }
    }
  }

  /// 设置加载状态
  @protected
  void setLoading(bool loading, {bool shouldNotify = true}) {
    if (_isDisposed) return;
    
    if (_isLoading != loading) {
      _isLoading = loading;
      
      if (shouldNotify) {
        notifyListeners();
      }
    }
  }

  /// 设置错误状态
  @protected
  void setError(String? error, {bool shouldNotify = true}) {
    if (_isDisposed) return;
    
    if (_error != error) {
      _error = error;
      _isLoading = false; // 出错时停止加载状态
      
      if (shouldNotify) {
        notifyListeners();
      }
    }
  }

  /// 清除错误
  void clearError() {
    setError(null);
  }

  /// 批量更新状态（减少重建次数）
  @protected
  void batchUpdate(VoidCallback updates) {
    if (_isDisposed) return;
    
    updates();
    notifyListeners();
  }

  /// 异步操作包装器，自动处理加载和错误状态
  @protected
  Future<R?> asyncOperation<R>(
    Future<R> Function() operation, {
    bool setLoadingState = true,
    String? errorPrefix,
  }) async {
    if (_isDisposed) return null;
    
    try {
      if (setLoadingState) setLoading(true);
      
      final result = await operation();
      
      if (setLoadingState) setLoading(false);
      clearError();
      
      return result;
    } catch (e, stackTrace) {
      final errorMessage = errorPrefix != null 
          ? '$errorPrefix: ${e.toString()}'
          : e.toString();
      
      setError(errorMessage);
      
      // 开发模式下打印详细错误信息
      if (kDebugMode) {
        debugPrint('🔴 AsyncOperation Error: $errorMessage');
        debugPrint('📍 StackTrace: $stackTrace');
      }
      
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

/// 状态管理mixin，为状态类提供额外功能
mixin StateManagementMixin<T> on AppState<T> {
  /// 状态历史记录（用于撤销功能）
  final List<T> _history = [];
  static const int _maxHistorySize = 10;

  /// 添加到历史记录
  void addToHistory(T state) {
    _history.add(state);
    if (_history.length > _maxHistorySize) {
      _history.removeAt(0);
    }
  }

  /// 撤销到上一个状态
  bool undo() {
    if (_history.isNotEmpty) {
      final previousState = _history.removeLast();
      updateState(previousState);
      return true;
    }
    return false;
  }

  /// 清除历史记录
  void clearHistory() {
    _history.clear();
  }

  /// 是否可以撤销
  bool get canUndo => _history.isNotEmpty;
}