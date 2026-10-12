import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:treasure/tools.dart';
import 'package:intl/intl.dart';
// import 'package:dio/dio.dart';
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';
// import 'package:share_plus/share_plus.dart';
import '../dao.dart';
import '../toy_model.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'package:treasure/core/state/state_manager.dart';
// import 'package:treasure/core/storage/storage_service.dart';

class ToyDetailCard extends StatefulWidget {
  final dynamic toy;
  final double dialogWidth;
  final Function getMore;
  final List? toyList; // 添加原始列表引用
  final int? toyIndex; // 添加当前toy在列表中的索引
  const ToyDetailCard({
    Key? key,
    required this.toy,
    required this.dialogWidth,
    required this.getMore,
    this.toyList,
    this.toyIndex,
  }) : super(key: key);

  static String formatPurchaseDate(String? createAt) {
    if (createAt == null || createAt.isEmpty) {
      return '';
    }
    try {
      final date = DateTime.parse(createAt);
      return DateFormat('yy-MM-dd').format(date);
    } catch (_) {
      return createAt;
    }
  }

  static int calculateHoldingDays(String? createAt) {
    if (createAt == null || createAt.isEmpty) {
      return 1;
    }
    try {
      final date = DateTime.parse(createAt);
      final now = DateTime.now();
      final start = DateTime(date.year, date.month, date.day);
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(start).inDays;
      return diff >= 0 ? diff + 1 : 1;
    } catch (_) {
      return 1;
    }
  }

  @override
  State<ToyDetailCard> createState() => _ToyDetailCardState();
}

class _ToyDetailCardState extends State<ToyDetailCard> {
  // 【单机模式】已移除闲鱼二手价与保存按钮
  // bool isSharing = false;
  late dynamic currentToy; // 本地状态变量存储toy数据

  @override
  void initState() {
    super.initState();
    // 初始化时强制使用列表中最新的toy数据，确保显示最新信息
    if (widget.toyList != null &&
        widget.toyIndex != null &&
        widget.toyIndex! < widget.toyList!.length) {
      // 强制使用列表中的最新数据
      currentToy = widget.toyList![widget.toyIndex!];
      debugPrint(
          '🔄 弹出层初始化: 强制使用列表中的最新数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
    } else {
      // 如果没有列表引用或索引无效，则使用传入的toy数据
      currentToy = widget.toy;
      debugPrint(
          '🔄 弹出层初始化: 回退使用传入的toy数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
    }
  }

  @override
  void didUpdateWidget(ToyDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检查列表索引是否发生变化（用户可能滑动到了其他页面）
    if (oldWidget.toyIndex != widget.toyIndex &&
        widget.toyList != null &&
        widget.toyIndex != null) {
      if (mounted) {
        setState(() {
          // 使用列表中当前索引的最新数据
          currentToy = widget.toyList![widget.toyIndex!];
        });
      }
      debugPrint(
          '🔄 弹出层页面切换: 更新为第${widget.toyIndex}项数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
    }
    // 如果索引没变，但是列表中的数据可能已经被其他地方更新了
    else if (widget.toyList != null &&
        widget.toyIndex != null &&
        widget.toyIndex! < widget.toyList!.length) {
      final latestToy = widget.toyList![widget.toyIndex!];

      // 详细比较关键字段，确保数据同步
      bool needsUpdate = latestToy.sellPrice != currentToy.sellPrice ||
          latestToy.price != currentToy.price ||
          latestToy.toyName != currentToy.toyName ||
          latestToy.description != currentToy.description ||
          latestToy.isSelled != currentToy.isSelled;

      if (needsUpdate) {
        if (mounted) {
          setState(() {
            // 同步列表中的最新数据到当前显示
            currentToy = latestToy;
          });
        }
        debugPrint(
            '🔄 弹出层数据同步: 从列表中获取最新数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
      }
    }
  }

  // 强制清除所有可能的缓存
  // 【单机模式】已注释掉缓存与网络缓存清理
  /*
  Future<void> _clearAllCaches() async {
    ...
  }
  */

  List<String> getTitle(str) {
    switch (str) {
      // 【单机模式】已移除设置卖出价格
      // case 'sellPrice':
      //   return ['设置二手价格', '请输入价格'];
      case 'toyName':
        return ['设置宝贝名字', '请输入宝贝名字'];
      case 'price':
        return ['设置入手价格', '请输入价格'];
      case 'description':
        return ['设置宝贝的详情', '请输入宝贝描述'];
      case 'labels':
        return ['设置分类标签', '请输入标签名称'];
      default:
        return [''];
    }
  }

  void setPrice(context, currentToy, setState, tag) async {
    final controller = TextEditingController();
    final newPrice = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(getTitle(tag)[0]),
          content: TextField(
            controller: controller,
            //keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: getTitle(tag)[1]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final price = (tag == 'toyName' || tag == 'description')
                    ? controller.text
                    : int.tryParse(controller.text);
                Navigator.pop(context, price);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    bool wasUpdated = false;

    // 【单机模式】已移除设置卖出价格逻辑
    /*
    if (tag == 'sellPrice') {
      if (newPrice != null && newPrice != 0) {
        ...
      }
    } else
    */
    if (tag == 'toyName') {
      if (newPrice != null && newPrice.isNotEmpty) {
        currentToy.toyName = newPrice;

        // 同时更新原始列表中对应的数据，确保下次打开弹出层时数据一致
        if (widget.toyList != null &&
            widget.toyIndex != null &&
            widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].toyName = newPrice;
          debugPrint('📝 同时更新列表中索引${widget.toyIndex}的数据: toyName=$newPrice');
        }

        if (mounted) {
          setState(() {
            // 触发重建
          });
        }
        wasUpdated = true;
        debugPrint('📝 宝贝名称更新: ${currentToy.toyName}');
      }
    } else if (tag == 'price') {
      if (newPrice != null && newPrice != 0) {
        currentToy.price = newPrice;

        // 同时更新原始列表中对应的数据
        if (widget.toyList != null &&
            widget.toyIndex != null &&
            widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].price = newPrice;
          debugPrint('💲 同时更新列表中索引${widget.toyIndex}的数据: price=$newPrice');
        }

        if (mounted) {
          setState(() {
            // 触发重建
          });
        }
        wasUpdated = true;
        debugPrint('💲 入手价格更新: ${currentToy.price}');
      }
    } else if (tag == 'description') {
      if (newPrice != null) {
        currentToy.description = newPrice;

        // 同时更新原始列表中对应的数据，确保下次打开弹出层时数据一致
        if (widget.toyList != null &&
            widget.toyIndex != null &&
            widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].description = newPrice;
          debugPrint(
              '📄 同时更新列表中索引${widget.toyIndex}的数据: description=$newPrice');
        }

        if (mounted) {
          setState(() {
            // 触发重建
          });
        }
        wasUpdated = true;
        debugPrint('📄 描述更新: ${currentToy.description}');
      }
    } else if (tag == 'labels') {
      if (newPrice != null && newPrice.isNotEmpty) {
        currentToy.labels = newPrice;
        if (widget.toyList != null &&
            widget.toyIndex != null &&
            widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].labels = newPrice;
        }
        if (mounted) {
          setState(() {});
        }
        wasUpdated = true;
      }
    }

    // 如果数据被更新，记录更新信息并自动持久化
    if (wasUpdated) {
      debugPrint(
          '✅ 字段更新完成: ${currentToy.toyName} - $tag=${tag == "price" ? currentToy.price : tag == "toyName" ? currentToy.toyName : currentToy.description}');
      _autoSave();
    }
  }

  Future<void> _pickPurchaseDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    try {
      if (currentToy.createAt != null && currentToy.createAt.isNotEmpty) {
        initialDate = DateTime.parse(currentToy.createAt);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      currentToy.createAt = dateStr;

      // 同时更新原始列表中对应的数据
      if (widget.toyList != null &&
          widget.toyIndex != null &&
          widget.toyIndex! < widget.toyList!.length) {
        widget.toyList![widget.toyIndex!].createAt = dateStr;
      }

      if (mounted) {
        setState(() {});
      }
      _autoSave();
    }
  }

  // 【单机模式】自动保存玩具修改到本地
  Future<void> _autoSave() async {
    try {
      dynamic currentUser;
      try {
        currentUser = StateManager.readUserState(context).currentUser;
      } catch (_) {
        currentUser =
            currentToy.owner ?? OwnerModel(uid: 'local_user', name: '玩具收藏家');
      }
      currentToy.owner = currentUser;
      await TreasureDao.modifyToy(currentToy.toJson());
      debugPrint('💾 自动保存成功: ${currentToy.toyName}');
      await widget.getMore(0);
    } catch (e) {
      debugPrint('⚠️ 自动保存失败: $e');
    }
  }

  /*
  // 【单机模式】已移除闲鱼二手价分享
  Future<File?> _findLocalImage(String localUrl, String imageUrl) async { ... }
  Future<void> toXianyu(...) async { ... }
  */

  Future<void> _handleStatusChanged(bool newValue) async {
    InteractiveFeedback.hapticFeedback();
    currentToy.isSelled = newValue;

    // 同时更新原始列表中对应的数据
    if (widget.toyList != null &&
        widget.toyIndex != null &&
        widget.toyIndex! < widget.toyList!.length) {
      widget.toyList![widget.toyIndex!].isSelled = newValue;
      debugPrint('🔄 同时更新列表中索引${widget.toyIndex}的数据: isSelled=$newValue');
    }

    if (mounted) {
      setState(() {});
    }
    _autoSave();
  }

  @override
  Widget build(BuildContext context) {
    // 暂时禁用自动刷新，避免覆盖用户的修改
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _refreshFromList();
    // });

    final double aspectRatio =
        (currentToy.picWidth > 0 && currentToy.picHeight > 0)
            ? (currentToy.picWidth / currentToy.picHeight)
            : 1.0;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: CommonUtils.randomColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // 图片展示
                      Positioned.fill(
                        child: ImageWithFallback(
                          toy: currentToy,
                          width: MediaQuery.of(context).size.width / 2,
                        ),
                      ),
                      // 右上角状态切换胶囊组件（在库 / 已出损坏）
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          key: const Key('toy_status_badge'),
                          onTap: () =>
                              _handleStatusChanged(!currentToy.isSelled),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  right: 4,
                                  top: 3,
                                  bottom: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: currentToy.isSelled
                                      ? Colors.red.shade900.withOpacity(0.75)
                                      : Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: currentToy.isSelled
                                        ? Colors.redAccent.withOpacity(0.6)
                                        : Colors.white.withOpacity(0.25),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: currentToy.isSelled
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: currentToy.isSelled
                                                ? Colors.redAccent
                                                    .withOpacity(0.7)
                                                : Colors.greenAccent
                                                    .withOpacity(0.7),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      currentToy.isSelled ? '已出 / 损坏' : '在库收藏',
                                      style: TextStyle(
                                        color: currentToy.isSelled
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.95),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Transform.scale(
                                      scale: 0.72,
                                      child: Switch(
                                        value: currentToy.isSelled,
                                        onChanged: _handleStatusChanged,
                                        activeColor: Colors.white,
                                        activeTrackColor: Colors.redAccent,
                                        inactiveThumbColor: Colors.white,
                                        inactiveTrackColor: Colors.white30,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 宝贝名字与分类标签（蓝底白字）
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () =>
                          setPrice(context, currentToy, setState, 'toyName'),
                      child: Text(
                        '${currentToy.toyName}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (currentToy.labels != null &&
                    currentToy.labels.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setPrice(context, currentToy, setState, 'labels'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        currentToy.labels,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            (currentToy.description != null &&
                    currentToy.description.isNotEmpty)
                ? GestureDetector(
                    onTap: () =>
                        setPrice(context, currentToy, setState, 'description'),
                    child: Text(
                      '${currentToy.description}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ))
                : GestureDetector(
                    onTap: () =>
                        setPrice(context, currentToy, setState, 'description'),
                    child: Text(
                      '点击添加宝贝的描述',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    )),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setPrice(context, currentToy, setState, 'price'),
              child: Text(
                '入手价：¥${currentToy.price}',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.red[400],
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => _pickPurchaseDate(context),
                      child: Text(
                        '入手日期：${ToyDetailCard.formatPurchaseDate(currentToy.createAt)}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '已入手${ToyDetailCard.calculateHoldingDays(currentToy.createAt)}天',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
