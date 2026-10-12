import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/toy_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'package:treasure/pages/login.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/pages/lan_sync_page.dart';
import 'package:treasure/core/navigation/page_transitions.dart';

class ProfilePage extends StatefulWidget {
  final OwnerModel user;
  final List toies;
  final int toyCount;
  final double totalValue;
  final Function getMore;
  final VoidCallback? onBack;
  final Function(int)? onDataChanged;
  const ProfilePage({
    required this.user,
    required this.toies,
    required this.toyCount,
    required this.totalValue,
    required this.getMore,
    this.onBack,
    this.onDataChanged,
    Key? key,
  }) : super(key: key);
  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  final ScrollController _controller = ScrollController();
  int _currentPage = 1; // 已有首页数据，从第2页开始加载
  bool _isLoading = false;
  late OwnerModel _currentUser;

  bool get _isLoggedIn => _currentUser.uid.isNotEmpty;

  String get _userTitle {
    if (widget.toyCount < 25) {
      return '初级玩家';
    } else if (widget.toyCount < 75) {
      return '生活在奔小康的路上';
    } else {
      return '头号玩家';
    }
  }

  void _scrollListener() {
    if (!_isLoggedIn) return;
    if (_controller.position.pixels >=
            _controller.position.maxScrollExtent - 50 &&
        !_isLoading &&
        _controller.position.outOfRange == false) {
      debugPrint('触发加载更多: 当前页=$_currentPage, 当前数量=${widget.toies.length}');
      _addMoreData(_currentPage);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _controller.addListener(_scrollListener);
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _currentUser = widget.user;
    }
    // 当widget更新时（数据变化），检查是否需要更新状态
    if (oldWidget.toies.length != widget.toies.length) {
      debugPrint('数据已更新: ${oldWidget.toies.length} -> ${widget.toies.length}');
      // 保存当前滚动位置
      final currentScrollOffset =
          _controller.hasClients ? _controller.offset : 0.0;

      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });

        // 恢复滚动位置
        if (_controller.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_controller.hasClients && currentScrollOffset > 0) {
              _controller.animateTo(
                currentScrollOffset,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
    }
  }

  Future<void> _addMoreData(int currentPage) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    StateManager.uiState(context)
        .setComponentLoading('profile_load_more', true);
    debugPrint('开始加载第 ${currentPage + 1} 页数据...');

    try {
      await widget.getMore(currentPage + 1);
      if (!mounted) return;

      debugPrint('数据加载完成，当前数量: ${widget.toies.length}');

      setState(() {
        _isLoading = false;
        _currentPage = currentPage + 1;
      });

      StateManager.uiState(context)
          .setComponentLoading('profile_load_more', false);
    } catch (e) {
      debugPrint('加载更多数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        StateManager.uiState(context)
            .setComponentLoading('profile_load_more', false);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() async {
    InteractiveFeedback.hapticFeedback();
    final result = await AppNavigator.push<bool>(
      context,
      const Login(),
      type: PageTransitionType.slideScale,
      direction: SlideDirection.fromRight,
    );
    if (result == true ||
        (mounted && StateManager.readUserState(context).isLoggedIn)) {
      widget.onDataChanged?.call(1);
      await HomePageHelper.refreshHomePage();
    }
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth');
    if (!mounted) return;

    // 使用新的状态管理系统进行登出
    final userState = StateManager.userState(context);
    await userState.logout();

    setState(() {
      _currentUser = OwnerModel();
    });

    widget.onDataChanged?.call(1);
    await HomePageHelper.refreshHomePage();
    widget.onBack?.call();
  }

  ImageProvider _getAvatarProvider(String avatar) {
    if (avatar.isEmpty) {
      return const AssetImage('assets/wechat.png');
    }
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return NetworkImage(avatar);
    }
    if (avatar.startsWith('assets/')) {
      return AssetImage(avatar);
    }
    try {
      final file = File(avatar);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (e) {
      debugPrint('Avatar file load error: $e');
    }
    return const AssetImage('assets/wechat.png');
  }

  Future<String> _saveAvatarLocally(File sourceFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory(p.join(appDir.path, 'treasure_avatars'));
      if (!await avatarDir.exists()) {
        await avatarDir.create(recursive: true);
      }
      final extension = sourceFile.path.contains('.')
          ? sourceFile.path.substring(sourceFile.path.lastIndexOf('.'))
          : '.jpg';
      final targetPath = p.join(
        avatarDir.path,
        'avatar_${DateTime.now().millisecondsSinceEpoch}$extension',
      );
      final savedFile = await sourceFile.copy(targetPath);
      return savedFile.path;
    } catch (e) {
      debugPrint('保存头像本地文件失败: $e');
      return sourceFile.path;
    }
  }

  Future<void> _updateUserInfo(OwnerModel updatedUser) async {
    setState(() {
      _currentUser = updatedUser;
    });

    try {
      final userState = StateManager.readUserState(context);
      await userState.updateUser(updatedUser);
    } catch (e) {
      debugPrint('更新UserState失败: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth', json.encode(updatedUser.toJson()));
    } catch (e) {
      debugPrint('保存SharedPreferences失败: $e');
    }

    widget.onDataChanged?.call(1);
  }

  Future<void> _openLanSyncPage() async {
    InteractiveFeedback.hapticFeedback();
    final synced = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LanSyncPage(
          currentUser: _currentUser,
        ),
      ),
    );
    if (synced == true) {
      await _reloadAfterSync();
    }
  }

  Future<void> _reloadAfterSync() async {
    try {
      final userState = StateManager.readUserState(context);
      final refreshedUser = userState.currentUser;
      setState(() {
        _currentUser = refreshedUser;
      });
      await widget.getMore(0);
      widget.onDataChanged?.call(1);
      if (mounted) {
        CommonUtils.showSnackBar(context, '数据已同步刷新完成');
      }
    } catch (e) {
      debugPrint('刷新同步数据失败: $e');
    }
  }

  Future<String?> _pickAvatarPathFromOptions() async {
    final option = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '选择头像来源',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('从相册选择'),
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('拍照'),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('输入图片链接'),
                  onTap: () => Navigator.pop(sheetContext, 'url'),
                ),
                if (_currentUser.avatar.isNotEmpty)
                  ListTile(
                    leading:
                        const Icon(Icons.refresh_rounded, color: Colors.orange),
                    title: const Text('恢复默认头像',
                        style: TextStyle(color: Colors.orange)),
                    onTap: () => Navigator.pop(sheetContext, 'reset'),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (option == null) return null;

    if (option == 'reset') {
      return '';
    } else if (option == 'url') {
      return await _promptAvatarUrl();
    } else if (option == 'gallery' || option == 'camera') {
      final source =
          option == 'gallery' ? ImageSource.gallery : ImageSource.camera;
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (picked != null) {
          try {
            return await _saveAvatarLocally(File(picked.path));
          } catch (e) {
            return picked.path;
          }
        }
      } catch (e) {
        debugPrint('选择头像失败: $e');
        if (mounted) {
          CommonUtils.showSnackBar(context, '获取图片失败，请重试');
        }
      }
    }
    return null;
  }

  Future<String?> _promptAvatarUrl() async {
    final TextEditingController urlController = TextEditingController(
      text: _currentUser.avatar.startsWith('http') ? _currentUser.avatar : '',
    );
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('输入头像图片链接',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'https://example.com/avatar.jpg',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isEmpty) {
                  CommonUtils.showSnackBar(context, '请输入有效的图片链接');
                  return;
                }
                Navigator.pop(dialogContext, url);
              },
              child: const Text('确定', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChangeAvatarOptions() async {
    InteractiveFeedback.hapticFeedback();
    final newAvatar = await _pickAvatarPathFromOptions();
    if (newAvatar != null) {
      final updatedUser = _currentUser.copyWith(avatar: newAvatar);
      await _updateUserInfo(updatedUser);
      if (mounted) {
        CommonUtils.showSnackBar(
          context,
          newAvatar.isEmpty ? '已恢复默认头像' : '头像修改成功！',
        );
      }
    }
  }

  void _showEditNameDialog() {
    InteractiveFeedback.hapticFeedback();
    final TextEditingController nameController =
        TextEditingController(text: _currentUser.name);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('修改用户名字',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            key: const Key('edit_name_input'),
            controller: nameController,
            maxLength: 20,
            decoration: const InputDecoration(
              hintText: '请输入新的用户名字',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              key: const Key('save_name_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  CommonUtils.showSnackBar(context, '用户名字不能为空');
                  return;
                }
                Navigator.pop(dialogContext);
                final updatedUser = _currentUser.copyWith(name: newName);
                await _updateUserInfo(updatedUser);
                if (mounted) {
                  CommonUtils.showSnackBar(context, '用户名字修改成功！');
                }
              },
              child: const Text('确定', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showToyDetail(dynamic toyOrIndex) {
    int index = 0;
    List list = widget.toies;
    if (toyOrIndex is int) {
      index = toyOrIndex;
    } else {
      final foundIndex = widget.toies.indexOf(toyOrIndex);
      if (foundIndex >= 0) {
        index = foundIndex;
      } else if (toyOrIndex != null) {
        list = [toyOrIndex];
        index = 0;
      }
    }

    CommonUtils.showDetail(
      context,
      index,
      list,
      (page) async {
        widget.onDataChanged?.call(1);
        await HomePageHelper.refreshHomePage();
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 头部信息区
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: _isLoggedIn ? null : _goToLogin,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 头像
                        GestureDetector(
                          key: const Key('profile_avatar_tap'),
                          onTap: _isLoggedIn ? _showChangeAvatarOptions : null,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _getAvatarProvider(
                                    _isLoggedIn ? _currentUser.avatar : ''),
                                onBackgroundImageError:
                                    (exception, stackTrace) {
                                  debugPrint('Avatar load error: $exception');
                                },
                              ),
                              if (_isLoggedIn)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: GestureDetector(
                                      key: const Key('profile_name_tap'),
                                      onTap: _isLoggedIn
                                          ? _showEditNameDialog
                                          : null,
                                      child: Text(
                                        _isLoggedIn
                                            ? _currentUser.name
                                            : '点击登录',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (_isLoggedIn) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      key: const Key('profile_edit_name_btn'),
                                      onTap: _showEditNameDialog,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.edit,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              // 简介
                              Text(
                                _isLoggedIn ? _userTitle : '登录后管理您的宝贝收藏',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_isLoggedIn)
                          const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () {
                      InteractiveFeedback.hapticFeedback();
                      widget.onBack?.call();
                    },
                  ),
                ),
                // 右上角：登录或同步数据按钮
                Positioned(
                  top: 40,
                  right: 16,
                  child: _isLoggedIn
                      ? TextButton.icon(
                          key: const Key('profile_sync_btn'),
                          icon: const Icon(Icons.sync_rounded,
                              size: 14, color: Colors.black87),
                          label: const Text(
                            '同步数据',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onPressed: _openLanSyncPage,
                        )
                      : TextButton.icon(
                          icon: const Icon(Icons.login,
                              size: 20, color: Colors.black87),
                          label: const Text('登录',
                              style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold)),
                          onPressed: _goToLogin,
                        ),
                ),
              ],
            ),
            // 数据卡片区
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 宝贝总数卡片
                  _buildStatCard(
                    icon: Icons.toys_sharp,
                    title: "宝贝总数",
                    value: widget.toyCount.toString(),
                    unit: "件",
                    color: Colors.grey[800]!,
                    onTap: _isLoggedIn ? null : _goToLogin,
                  ),
                  const SizedBox(width: 16),
                  // 总价值卡片
                  _buildStatCard(
                    icon: Icons.attach_money,
                    title: "总价值",
                    value: widget.totalValue.toStringAsFixed(2),
                    unit: "元",
                    color: Colors.grey[800]!,
                    onTap: _isLoggedIn ? null : _goToLogin,
                  ),
                ],
              ),
            ),

            // 分割线
            Divider(height: 1, color: Colors.grey[200]),

            // 玩具列表标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(
                    "我的收藏",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            _isLoggedIn
                ? (widget.toies.isEmpty
                    ? Container(
                        height: 200,
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '暂无收藏物品',
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey[500]),
                          ),
                        ),
                      )
                    : Container(
                        height: 300,
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          controller: _controller,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemSize =
                                      (constraints.maxWidth - 24) / 4;
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: widget.toies
                                        .asMap()
                                        .entries
                                        .map((entry) => SizedBox(
                                              width: itemSize,
                                              height: itemSize,
                                              child: GestureDetector(
                                                onTap: () =>
                                                    _showToyDetail(entry.key),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    color: Colors.grey[200],
                                                    child: ImageWithFallback(
                                                      toy: entry.value,
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width /
                                                              2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  );
                                },
                              ),
                              if (_isLoading)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.grey[600]!),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '加载更多...',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ))
                : Container(
                    height: 240,
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_circle_outlined,
                              size: 54, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            '登录后查看个人收藏',
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                            ),
                            onPressed: _goToLogin,
                            child: const Text('立即登录',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  children: [
                    TextSpan(
                      text: " $unit",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
