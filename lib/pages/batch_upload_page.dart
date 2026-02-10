import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/dao.dart';
import 'package:qiniu_flutter_sdk/qiniu_flutter_sdk.dart';

enum UploadStatus { pending, uploading, saving, success, failed }

class BatchUploadItemState {
  UploadStatus status = UploadStatus.pending;
  double progress = 0.0;
  String? error;
}

class BatchUploadPage extends StatefulWidget {
  final List<File> images;
  final String toyName;
  final num price;
  final String description;
  final String label;
  final String uid;

  const BatchUploadPage({
    Key? key,
    required this.images,
    required this.toyName,
    required this.price,
    required this.description,
    required this.label,
    required this.uid,
  }) : super(key: key);

  @override
  State<BatchUploadPage> createState() => _BatchUploadPageState();
}

class _BatchUploadPageState extends State<BatchUploadPage> {
  final Map<int, BatchUploadItemState> _itemStates = {};
  bool _isUploading = false;
  final storage = Storage();
  late PutController putController;

  @override
  void initState() {
    super.initState();
    // 初始化所有图片的状态
    for (int i = 0; i < widget.images.length; i++) {
      _itemStates[i] = BatchUploadItemState();
    }
  }

  // 七牛云上传逻辑 (从 edit.dart 复用并适配)
  Future<ReturnBody?> startUploadToQiniu(String token, File file, int index) async {
    try {
      if (!await file.exists()) return null;

      putController = PutController();
      putController.addProgressListener((double percent) {
        if (mounted) {
          setState(() {
            _itemStates[index]?.progress = percent;
          });
        }
      });

      final putOptions = PutOptions(controller: putController);
      final response = await storage.putFile(file, token, options: putOptions);

      if (response.rawData.isEmpty) return null;
      ReturnBody body = ReturnBody.fromJson(response.rawData);

      // 本地宽高修正
      try {
        var bytes = await file.readAsBytes();
        var codec = await ui.instantiateImageCodec(bytes);
        var frameInfo = await codec.getNextFrame();
        body = ReturnBody(
            key: body.key,
            width: frameInfo.image.width.toDouble(),
            height: frameInfo.image.height.toDouble()
        );
      } catch (e) {
        debugPrint('宽高计算失败: $e');
      }
      
      return body;
    } catch (e) {
      debugPrint('上传失败: $e');
      return null;
    }
  }

  void _startUpload() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 检查网络
      final hasNetwork = await InternetAddress.lookup('baidu.com')
          .then((result) => result.isNotEmpty && result[0].rawAddress.isNotEmpty)
          .catchError((_) => false);
      
      if (!hasNetwork) {
        if (mounted) CommonUtils.showSnackBar(context, '请检查网络连接！');
        setState(() => _isUploading = false);
        return;
      }

      // 获取当前用户信息 (假设从全局或通过某种方式获取，这里为了简单直接取 token)
      // 注意：这里需要 OwnerModel 的 uid，但 edit.dart 传进来时没带 user 对象。
      // 为保持 edit.dart 逻辑一致，我们可能需要 user id。
      // 暂时假设 DAO 内部处理或上层确保登录。
      // !重要：createToy 接口需要 owner uid。edit.dart 是通过 widget.user.uid 传的。
      // BatchUploadPage 目前没有 user uid。
      // 这是一个发现的问题，我需要先完成骨架，待会修复 uid 传递。
      // 先假设 token 获取成功。
      
      String token = await TreasureDao.getToken('upload');

      // 串行队列逻辑
      int successCount = 0;
      
      for (int i = 0; i < widget.images.length; i++) {
        // 如果页面关闭了，停止上传
        if (!mounted) break;

        // 更新状态为上传中
        setState(() {
          _itemStates[i]?.status = UploadStatus.uploading;
        });

        // 1. 上传七牛
        final result = await startUploadToQiniu(token, widget.images[i], i);
        
        if (result == null) {
          setState(() {
            _itemStates[i]?.status = UploadStatus.failed;
            _itemStates[i]?.error = '图片上传失败';
          });
          continue;
        }

        // 更新状态为保存中
        setState(() {
          _itemStates[i]?.status = UploadStatus.saving;
        });

        // 准备默认值
        final String finalName = widget.toyName.isEmpty ? '默认上传' : widget.toyName;
        final num finalPrice = widget.price == 0 ? 1 : widget.price;
        final String finalLabel = widget.label.isEmpty ? '盲盒' : widget.label;

        // 2. 提交后台
        try {
          // 注意：这里缺少 uid。为了修复这个问题，我需要在下一步请求从 edit.dart 传 uid 进来。
          // 暂时使用空字符串或尝试从全局获取（如果有）。
          // 既然 edit.dart 有 widget.user.uid，BatchUploadPage 应该也有。
          // 代码修改时我会加上这个参数。
          
          await TreasureDao.poMicro({
             'toyName': finalName,
             'description': widget.description,
             'toyPicUrl': result.key,
             'picWidth': result.width,
             'picHeight': result.height,
             'labels': finalLabel,
             'owner': widget.uid,
             'price': finalPrice,
          });

          successCount++;
          setState(() {
            _itemStates[i]?.status = UploadStatus.success;
          });
        } catch (e) {
          setState(() {
            _itemStates[i]?.status = UploadStatus.failed;
            _itemStates[i]?.error = '保存失败';
          });
        }
      }

      if (mounted) {
        if (successCount == widget.images.length) {
          CommonUtils.showSnackBar(context, '全部发布成功！');
          Navigator.pop(context);
        } else {
           CommonUtils.showSnackBar(context, '发布完成，成功 $successCount 张，失败 ${widget.images.length - successCount} 张');
        }
      }

    } catch (e) {
      if (mounted) CommonUtils.showSnackBar(context, '发生错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildStatusWidget(BatchUploadItemState state) {
    switch (state.status) {
      case UploadStatus.pending:
        return const Text('等待中', style: TextStyle(color: Colors.grey));
      case UploadStatus.uploading:
        return Text('上传中 ${(state.progress * 100).toInt()}%', style: const TextStyle(color: Colors.blue));
      case UploadStatus.saving:
        return const Text('保存中...', style: TextStyle(color: Colors.orange));
      case UploadStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green);
      case UploadStatus.failed:
        return Text(state.error ?? '失败', style: const TextStyle(color: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('批量上传'),
        centerTitle: true,
        leading: GestureDetector(
          child: const Icon(Icons.arrow_back_ios),
          onTap: () {
            Navigator.maybePop(context);
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _isUploading ? null : _startUpload,
            child: Text(
              '发布',
              style: TextStyle(
                color: _isUploading ? Colors.grey : Colors.black,
              ),
            ),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          final file = widget.images[index];
          final state = _itemStates[index] ?? BatchUploadItemState();
          
          return Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // 图片展示
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: Image.file(
                    file,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                // 进度与状态区域
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Text(
                              '图片 ${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            _buildStatusWidget(state),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (state.status == UploadStatus.uploading)
                          LinearProgressIndicator(
                            value: state.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
