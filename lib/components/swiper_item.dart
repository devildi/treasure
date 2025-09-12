import 'package:flutter/material.dart';
import 'package:treasure/tools.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../dao.dart';
import 'package:treasure/components/common_image.dart';

class ToyDetailCard extends StatefulWidget {
  final dynamic toy;
  final double dialogWidth;
  final Function getMore;

  const ToyDetailCard({
    Key? key,
    required this.toy,
    required this.dialogWidth,
    required this.getMore,
  }) : super(key: key);

  @override
  State<ToyDetailCard> createState() => _ToyDetailCardState();
}

class _ToyDetailCardState extends State<ToyDetailCard> {
  bool isSharing = false;
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
                final price = tag == 'toyName' ? controller.text : int.tryParse(controller.text);
                Navigator.pop(context, price);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if(tag == 'sellPrice'){
      if (newPrice != null && newPrice != 0) {
        setState(() {
          currentToy.sellPrice = newPrice;
        });
      }
    } else if(tag == 'toyName'){
      if (newPrice != null && newPrice.isNotEmpty) {
        setState(() {
          currentToy.toyName = newPrice;
        });
      }
    } else if(tag == 'price'){
      if (newPrice != null && newPrice != 0) {
        setState(() {
          currentToy.price = newPrice;
        });
      }
    } else if(tag == 'description'){
      if (newPrice != null && newPrice != 0) {
        setState(() {
          currentToy.description = newPrice;
        });
      }
    }
  }

  Future<void> toXianyu(
    String imageUrl,
    String localUrl,
    Function(bool) setLoading,
  ) async {
    final dio = Dio();
    File? file;

    try {
      setLoading(true);
      // 使用本地图片
      file = File(localUrl);
      if (!await file.exists()) {
        debugPrint("本地图片不存在: $localUrl");
        final response = await dio.get<List<int>>(
          imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );

        final tempDir = await getTemporaryDirectory();
        file = File('${tempDir.path}/xianyu_share.jpg');
        await file.writeAsBytes(response.data!);
      }
      // 分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '看看这个东西值多少钱',
      );
    } catch (e) {
      debugPrint("跳转失败: $e");
    } finally {
      setLoading(false);

      // 删除临时文件（如果是下载的临时图片）
      if (file != null && await file.exists()) {
        try {
          await file.delete();
          debugPrint('临时图片已删除');
        } catch (e) {
          debugPrint('删除失败: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentToy = widget.toy;
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
                            setState(() {
                              currentToy.isSelled = newValue;
                            });
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
              currentToy.description != ''
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
                      child: Text(
                        '二手价：¥${currentToy.sellPrice}',
                        style: TextStyle(fontSize: 18, color: Colors.green[400], fontWeight: FontWeight.bold),
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
                          setState(() => isSharing = true);
                          await toXianyu(
                            currentToy.toyPicUrl,
                            currentToy.localUrl,
                            (loading) => setState(() => isSharing = loading),
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
                        final response = await TreasureDao.modifyToy(currentToy.toJson());
                        if (!context.mounted) return;
                        // 简化为固定页面0，由于这是保存操作，不需要特定页面
                        await widget.getMore(0);
                        if (response != null) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          CommonUtils.showSnackBar(context, '保存成功');
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
