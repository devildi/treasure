import 'package:flutter/foundation.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/state/app_state.dart';
import 'package:treasure/core/state/state_persistence.dart';

/// 用户状态数据模型
class UserStateData {
  final OwnerModel user;
  final bool isLoggedIn;
  final DateTime? lastLoginTime;
  final Map<String, dynamic> preferences;

  const UserStateData({
    required this.user,
    required this.isLoggedIn,
    this.lastLoginTime,
    this.preferences = const {},
  });

  UserStateData copyWith({
    OwnerModel? user,
    bool? isLoggedIn,
    DateTime? lastLoginTime,
    Map<String, dynamic>? preferences,
  }) {
    return UserStateData(
      user: user ?? this.user,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      lastLoginTime: lastLoginTime ?? this.lastLoginTime,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'isLoggedIn': isLoggedIn,
      'lastLoginTime': lastLoginTime?.toIso8601String(),
      'preferences': preferences,
    };
  }

  factory UserStateData.fromJson(Map<String, dynamic> json) {
    return UserStateData(
      user: OwnerModel.fromJson(json['user'] ?? {}),
      isLoggedIn: json['isLoggedIn'] ?? false,
      lastLoginTime: json['lastLoginTime'] != null 
          ? DateTime.parse(json['lastLoginTime'])
          : null,
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
    );
  }

  /// 创建空用户状态
  factory UserStateData.empty() {
    return UserStateData(
      user: OwnerModel(),
      isLoggedIn: false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStateData &&
        other.user == user &&
        other.isLoggedIn == isLoggedIn &&
        other.lastLoginTime == lastLoginTime;
  }

  @override
  int get hashCode {
    return user.hashCode ^ 
           isLoggedIn.hashCode ^ 
           lastLoginTime.hashCode;
  }

  @override
  String toString() {
    return 'UserStateData(user: ${user.uid}, isLoggedIn: $isLoggedIn)';
  }
}

/// 用户状态管理器
class UserState extends AppState<UserStateData> 
    with StateManagementMixin<UserStateData> {
  
  static const String _storageKey = 'user_state';
  final StatePersistence _persistence;

  UserState({
    UserStateData? initialState,
    StatePersistence? persistence,
  }) : _persistence = persistence ?? StatePersistence(),
       super(initialState ?? UserStateData.empty());

  /// 当前用户
  OwnerModel get currentUser => state.user;

  /// 是否已登录
  bool get isLoggedIn => state.isLoggedIn && state.user.uid.isNotEmpty;

  /// 用户偏好设置
  Map<String, dynamic> get preferences => state.preferences;

  /// 登录
  Future<bool> login(OwnerModel user) async {
    return await asyncOperation(() async {
      addToHistory(state);
      
      final newState = state.copyWith(
        user: user,
        isLoggedIn: true,
        lastLoginTime: DateTime.now(),
      );
      
      updateState(newState, shouldNotify: false);
      await _saveState();
      
      return true;
    }, errorPrefix: '用户登录失败') ?? false;
  }

  /// 登出
  Future<bool> logout() async {
    return await asyncOperation(() async {
      addToHistory(state);
      
      final newState = UserStateData.empty();
      updateState(newState, shouldNotify: false);
      await _clearState();
      
      return true;
    }, errorPrefix: '用户登出失败') ?? false;
  }

  /// 更新用户信息
  Future<bool> updateUser(OwnerModel updatedUser) async {
    if (!isLoggedIn) {
      setError('用户未登录');
      return false;
    }

    return await asyncOperation(() async {
      addToHistory(state);
      
      final newState = state.copyWith(user: updatedUser);
      updateState(newState, shouldNotify: false);
      await _saveState();
      
      return true;
    }, errorPrefix: '更新用户信息失败') ?? false;
  }

  /// 更新偏好设置
  Future<bool> updatePreference(String key, dynamic value) async {
    return await asyncOperation(() async {
      final newPreferences = Map<String, dynamic>.from(preferences);
      newPreferences[key] = value;
      
      final newState = state.copyWith(preferences: newPreferences);
      updateState(newState, shouldNotify: false);
      await _saveState();
      
      return true;
    }, setLoadingState: false) ?? false;
  }

  /// 批量更新偏好设置
  Future<bool> updatePreferences(Map<String, dynamic> newPreferences) async {
    return await asyncOperation(() async {
      final updatedPreferences = Map<String, dynamic>.from(preferences);
      updatedPreferences.addAll(newPreferences);
      
      final newState = state.copyWith(preferences: updatedPreferences);
      updateState(newState, shouldNotify: false);
      await _saveState();
      
      return true;
    }, setLoadingState: false) ?? false;
  }

  /// 获取偏好设置值
  T? getPreference<T>(String key, {T? defaultValue}) {
    return preferences[key] as T? ?? defaultValue;
  }

  /// 从本地存储加载状态
  Future<void> loadFromStorage() async {
    await asyncOperation(() async {
      final savedData = await _persistence.load(_storageKey);
      if (savedData != null) {
        final userState = UserStateData.fromJson(savedData);
        updateState(userState, shouldNotify: false);
      }
    }, errorPrefix: '加载用户状态失败', setLoadingState: false);
  }

  /// 保存状态到本地存储
  Future<void> _saveState() async {
    try {
      await _persistence.save(_storageKey, state.toJson());
    } catch (e) {
      debugPrint('保存用户状态失败: $e');
    }
  }

  /// 清除本地存储
  Future<void> _clearState() async {
    try {
      await _persistence.delete(_storageKey);
      clearHistory();
    } catch (e) {
      debugPrint('清除用户状态失败: $e');
    }
  }

  /// 检查登录状态是否有效
  bool isLoginValid() {
    if (!isLoggedIn) return false;
    
    final lastLogin = state.lastLoginTime;
    if (lastLogin == null) return false;
    
    // 检查登录是否过期（例如30天）
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    return lastLogin.isAfter(thirtyDaysAgo);
  }

  /// 刷新登录时间
  Future<void> refreshLoginTime() async {
    if (isLoggedIn) {
      final newState = state.copyWith(lastLoginTime: DateTime.now());
      updateState(newState);
      await _saveState();
    }
  }

  @override
  void dispose() {
    // 在销毁前保存状态
    _saveState().catchError((e) {
      debugPrint('销毁时保存状态失败: $e');
    });
    
    super.dispose();
  }
}