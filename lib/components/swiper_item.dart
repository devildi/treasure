import 'package:flutter/material.dart';
import 'package:treasure/tools.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../dao.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/storage/storage_service.dart';

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

  @override
  State<ToyDetailCard> createState() => _ToyDetailCardState();
}

class _ToyDetailCardState extends State<ToyDetailCard> {
  bool isSharing = false;
  late dynamic currentToy; // 本地状态变量存储toy数据

  @override
  void initState() {
    super.initState();
    // 初始化时强制使用列表中最新的toy数据，确保显示最新信息
    if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
      // 强制使用列表中的最新数据
      currentToy = widget.toyList![widget.toyIndex!];
      debugPrint('🔄 弹出层初始化: 强制使用列表中的最新数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
    } else {
      // 如果没有列表引用或索引无效，则使用传入的toy数据
      currentToy = widget.toy;
      debugPrint('🔄 弹出层初始化: 回退使用传入的toy数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
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
      debugPrint('🔄 弹出层页面切换: 更新为第${widget.toyIndex}项数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
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
        debugPrint('🔄 弹出层数据同步: 从列表中获取最新数据 - ${currentToy.toyName} (sellPrice: ${currentToy.sellPrice})');
      }
    }
  }

  // 强制清除所有可能的缓存
  Future<void> _clearAllCaches() async {
    try {
      debugPrint('🧹 开始清除所有缓存...');

      // 1. 清除StorageService的缓存
      await StorageService.clearAllCaches();
      debugPrint('✅ StorageService缓存已清除');

      // 2. 清除Dio的可能缓存（如果有的话）
      // 这个方法会重新初始化网络客户端，清除任何内存中的缓存
      TreasureDao.clearNetworkCache();
      debugPrint('✅ 网络缓存已清除');

      debugPrint('🧹 所有缓存清除完成');
    } catch (e) {
      debugPrint('⚠️ 清除缓存时出现错误: $e');
    }
  }

  List<String> getTitle(str){
    switch (str) {
      case 'sellPrice':
        return ['设置二手价格', '请输入价格'];
      case 'toyName':
        return ['设置宝贝名字', '请输入宝贝名字'];
      case 'price':
        return ['设置购买价格', '请输入价格'];
      case 'description':
        return ['设置宝贝的详情', '请输入宝贝描述'];
      default:
        return [''];
    }
  }
  void setPrice(context, currentToy, setState, tag)async{
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
                final price = (tag == 'toyName' || tag == 'description') ? controller.text : int.tryParse(controller.text);
                Navigator.pop(context, price);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    bool wasUpdated = false;

    if(tag == 'sellPrice'){
      if (newPrice != null && newPrice != 0) {
        debugPrint('💰 准备更新二手价格: $newPrice (当前: ${currentToy.sellPrice})');
        debugPrint('💰 currentToy对象ID: ${currentToy.hashCode}');

        // 直接修改属性
        currentToy.sellPrice = newPrice;

        // 同时更新原始列表中对应的数据，确保下次打开弹出层时数据一致
        if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].sellPrice = newPrice;
          debugPrint('💰 同时更新列表中索引${widget.toyIndex}的数据: sellPrice=$newPrice');
        }

        // 强制setState重建整个Widget树
        if (mounted) {
          setState(() {
            // 什么都不做，只是触发重建
          });
        }
        wasUpdated = true;

        debugPrint('💰 二手价格已更新: ${currentToy.sellPrice}');
        debugPrint('💰 更新后currentToy对象ID: ${currentToy.hashCode}');

        // 立即强制重新构建UI
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              debugPrint('💰 PostFrame回调 - 强制UI重建显示新价格');
            });
          }
        });
      }
    } else if(tag == 'toyName'){
      if (newPrice != null && newPrice.isNotEmpty) {
        currentToy.toyName = newPrice;

        // 同时更新原始列表中对应的数据，确保下次打开弹出层时数据一致
        if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
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
    } else if(tag == 'price'){
      if (newPrice != null && newPrice != 0) {
        currentToy.price = newPrice;

        // 同时更新原始列表中对应的数据
        if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].price = newPrice;
          debugPrint('💲 同时更新列表中索引${widget.toyIndex}的数据: price=$newPrice');
        }

        if (mounted) {
          setState(() {
            // 触发重建
          });
        }
        wasUpdated = true;
        debugPrint('💲 购买价格更新: ${currentToy.price}');
      }
    } else if(tag == 'description'){
      if (newPrice != null) {
        currentToy.description = newPrice;

        // 同时更新原始列表中对应的数据，确保下次打开弹出层时数据一致
        if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
          widget.toyList![widget.toyIndex!].description = newPrice;
          debugPrint('📄 同时更新列表中索引${widget.toyIndex}的数据: description=$newPrice');
        }

        if (mounted) {
          setState(() {
            // 触发重建
          });
        }
        wasUpdated = true;
        debugPrint('📄 描述更新: ${currentToy.description}');
      }
    }

    // 如果数据被更新，记录更新信息（列表不可直接修改，依赖保存后的刷新机制）
    if (wasUpdated) {
      debugPrint('✅ 字段更新完成: ${currentToy.toyName} - $tag=${tag == "sellPrice" ? currentToy.sellPrice : tag == "price" ? currentToy.price : tag == "toyName" ? currentToy.toyName : currentToy.description}');
      debugPrint('📝 注意: 列表数据将在保存后通过刷新机制同步');
    }
  }

  // 智能查找本地图片，支持多种路径
  Future<File?> _findLocalImage(String localUrl, String imageUrl) async {
    try {
      // 1. 直接使用提供的本地路径
      if (localUrl.isNotEmpty) {
        final directFile = File(localUrl);
        if (await directFile.exists()) {
          debugPrint("✅ 找到直接本地图片: $localUrl");
          return directFile;
        }
      }

      // 2. 尝试从网络URL提取文件名，在应用目录中查找
      if (imageUrl.isNotEmpty) {
        final uri = Uri.tryParse(imageUrl);
        if (uri != null) {
          final fileName = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : 'image_${imageUrl.hashCode}.jpg';

          // 检查应用文档目录
          final appDir = await getApplicationDocumentsDirectory();
          final appFile = File('${appDir.path}/$fileName');
          if (await appFile.exists()) {
            debugPrint("✅ 找到应用目录图片: ${appFile.path}");
            return appFile;
          }

          // 检查应用支持目录
          final supportDir = await getApplicationSupportDirectory();
          final supportFile = File('${supportDir.path}/$fileName');
          if (await supportFile.exists()) {
            debugPrint("✅ 找到支持目录图片: ${supportFile.path}");
            return supportFile;
          }

          // 检查临时目录（可能之前下载过）
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          if (await tempFile.exists()) {
            debugPrint("✅ 找到临时目录图片: ${tempFile.path}");
            return tempFile;
          }
        }
      }

      // 3. 如果localUrl看起来像相对路径，尝试拼接到应用目录
      if (localUrl.isNotEmpty && !localUrl.startsWith('/')) {
        final appDir = await getApplicationDocumentsDirectory();
        final relativeFile = File('${appDir.path}/$localUrl');
        if (await relativeFile.exists()) {
          debugPrint("✅ 找到相对路径图片: ${relativeFile.path}");
          return relativeFile;
        }
      }

      debugPrint("❌ 未找到任何本地图片");
      return null;
    } catch (e) {
      debugPrint("❌ 查找本地图片时出错: $e");
      return null;
    }
  }

  Future<void> toXianyu(
    String imageUrl,
    String localUrl,
    Function(bool) setLoading,
  ) async {
    final dio = Dio();
    File? file;
    bool isTemporaryFile = false; // 标记是否为临时下载的文件

    try {
      setLoading(true);

      // 优先使用本地图片，支持多种路径检查
      file = await _findLocalImage(localUrl, imageUrl);

      if (file == null || !await file.exists()) {
        debugPrint("🌐 本地图片不可用，从网络下载: $imageUrl");
        final response = await dio.get<List<int>>(
          imageUrl,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: 30000,
            sendTimeout: 10000,
          ),
        );

        final tempDir = await getTemporaryDirectory();
        file = File('${tempDir.path}/xianyu_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(response.data!);
        isTemporaryFile = true; // 标记为临时文件
        debugPrint("📥 网络图片已下载到临时文件: ${file.path}");
      } else {
        debugPrint("📱 使用本地图片: ${file.path}");
      }

      // 分享图片
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '看看这个东西值多少钱',
        subject: '闲鱼估价分享',
      );
      debugPrint("✅ 图片分享成功");

    } catch (e) {
      debugPrint("❌ 分享失败: $e");
      // 可以在这里添加用户友好的错误提示
    } finally {
      setLoading(false);

      // 只删除临时下载的文件，保留本地存储的图片
      if (isTemporaryFile && file != null && await file.exists()) {
        try {
          await file.delete();
          debugPrint('🗑️ 临时下载图片已删除: ${file.path}');
        } catch (e) {
          debugPrint('⚠️ 删除临时图片失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 暂时禁用自动刷新，避免覆盖用户的修改
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _refreshFromList();
    // });

    // 使用本地状态变量而不是widget.toy
    final aspectRatio = currentToy.picWidth / currentToy.picHeight;
 
    return IntrinsicHeight(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: CommonUtils.randomColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:Stack(
                    children: [
                      // 图片展示
                      Positioned.fill(
                        child: ImageWithFallback(
                          toy: currentToy,
                          width: MediaQuery.of(context).size.width / 2,
                        ),
                      ),
                      // 右上角开关
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Switch(
                          value: currentToy.isSelled,
                          onChanged: (bool newValue) async{
                            if(currentToy.sellPrice == 0){
                              setPrice(context, currentToy, setState, 'sellPrice');
                            }
                            currentToy.isSelled = newValue;

                            // 同时更新原始列表中对应的数据
                            if (widget.toyList != null && widget.toyIndex != null && widget.toyIndex! < widget.toyList!.length) {
                              widget.toyList![widget.toyIndex!].isSelled = newValue;
                              debugPrint('🔄 同时更新列表中索引${widget.toyIndex}的数据: isSelled=$newValue');
                            }

                            if (mounted) {
                              setState(() {
                                // 触发重建
                              });
                            }
                          },
                          activeColor: Colors.black, // 开启时滑块颜色
                          inactiveThumbColor: Colors.grey, // 关闭时滑块颜色
                          activeTrackColor: Colors.black26, // 开启时轨道颜色（可选）
                          inactiveTrackColor: Colors.grey[300], // 关闭时轨道颜色（可选）
                        ),
                      ),
                    ],
                  )
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setPrice(context, currentToy, setState, 'toyName'),
                    child: Text(
                      '${currentToy.toyName}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  ) ,
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${currentToy.labels}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              (currentToy.description != null && currentToy.description.isNotEmpty)
              ? GestureDetector(
                  onTap: () => setPrice(context, currentToy, setState, 'description'),
                  child: Text(
                    '${currentToy.description}',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  )
                )
              : GestureDetector(
                  onTap: () => setPrice(context, currentToy, setState, 'description'),
                  child: Text(
                    '点击添加宝贝的描述',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  )
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setPrice(context, currentToy, setState, 'price'),
                    child: Text(
                      '购买价：¥${currentToy.price}',
                      style: TextStyle(fontSize: 18, color: Colors.red[400], fontWeight: FontWeight.bold),
                    )
                  ),
                  currentToy.sellPrice > 0
                  ? GestureDetector(
                      onTap: () => setPrice(context, currentToy, setState, 'sellPrice'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '二手价：¥${currentToy.sellPrice}',
                            style: TextStyle(fontSize: 18, color: Colors.green[400], fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: () => setPrice(context, currentToy, setState, 'sellPrice'),
                      child: const Text('设置卖出价格'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '购买日期：${DateFormat('yy-MM-dd').format(DateTime.parse(currentToy.createAt))}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isSharing
                      ? null
                      : () async {
                          if (mounted) {
                            setState(() => isSharing = true);
                          }
                          await toXianyu(
                            currentToy.toyPicUrl,
                            currentToy.localUrl,
                            (loading) {
                              if (mounted) {
                                setState(() => isSharing = loading);
                              }
                            },
                          );
                        },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isSharing)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).textTheme.labelLarge?.color,
                                ),
                              ),
                            ),
                          const Text('闲鱼二手价'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        // 获取当前登录用户
                        final currentUser = StateManager.readUserState(context).currentUser;
                        debugPrint('💾 保存玩具: 设置owner为当前用户 ${currentUser.uid}');

                        // 设置owner为当前登录用户
                        currentToy.owner = currentUser;

                        final response = await TreasureDao.modifyToy(currentToy.toJson());
                        if (!context.mounted) return;

                        if (response != null) {
                          debugPrint('✅ 保存成功，开始数据同步...');

                          // 1. 立即更新弹出层显示的currentToy数据
                          if (mounted) {
                            setState(() {
                              debugPrint('📝 保存后立即刷新弹出层显示数据');
                              debugPrint('🔄 弹出层currentToy: ${currentToy.toyName} - sellPrice: ${currentToy.sellPrice}');
                            });
                          }

                          // 2. 显示成功提示
                          if (!context.mounted) return;
                          CommonUtils.showSnackBar(context, '保存成功');

                          // 3. 立即触发回调，然后异步刷新数据
                          // 立即刷新当前显示，不依赖外部列表或回调
                          if (mounted) {
                            setState(() {
                              debugPrint('🔄 立即刷新弹出层显示的currentToy数据');
                              // currentToy已经在上面被更新了，这里只是触发重建
                            });
                          }

                          // 保存成功后，强制清除缓存并刷新数据和统计信息
                          Future.delayed(const Duration(milliseconds: 200), () async {
                            try {
                              debugPrint('🔄 保存成功，开始强制清除缓存并刷新数据...');

                              // 强制清除可能的缓存
                              await _clearAllCaches();

                              await widget.getMore(0);
                              debugPrint('✅ 数据刷新完成');
                            } catch (e) {
                              debugPrint('⚠️ 数据刷新失败: $e');
                            }

                            // 延时关闭弹出层，让用户看到更新后的数据
                            Future.delayed(const Duration(milliseconds: 400), () {
                              if (context.mounted) {
                                debugPrint('🔄 保存成功，关闭弹出层');
                                Navigator.of(context).pop(); // 关闭弹出层
                              }
                            });
                          });

                          debugPrint('✅ 保存完成 - 弹出层将自动关闭，数据已同步');
                        } else {
                          if (!context.mounted) return;
                          CommonUtils.show(context, '保存失败');
                        }
                      },
                      child: const Text('保存'),
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
