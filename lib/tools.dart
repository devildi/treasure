import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:treasure/components/swiper_item.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CommonUtils {
  static Color randomColor() {
    List colors = [
      Colors.red[100],
      Colors.green[100],
      Colors.yellow[100],
      Colors.orange[100]
    ];
    Random random = Random();
    return colors[random.nextInt(4)]!;
  }

  static void showSnackBar(BuildContext context, String message,
      {Color? backgroundColor}) {
    if (backgroundColor == Colors.green) {
      InteractiveFeedback.showSuccess(context, message);
    } else if (backgroundColor == Colors.red) {
      InteractiveFeedback.showError(context, message);
    } else if (backgroundColor == Colors.orange) {
      InteractiveFeedback.showWarning(context, message);
    } else {
      InteractiveFeedback.showInfo(context, message);
    }
  }

  static void show(BuildContext context, String message, {Duration? duration}) {
    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) {
        // 计算键盘是否弹出
        final keyboardHeight = mediaQuery.viewInsets.bottom;
        final isKeyboardVisible = keyboardHeight > 0;
        return Positioned(
          bottom: isKeyboardVisible
              ? keyboardHeight + 18 // 键盘上方20像素
              : 100, // 默认位置
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      },
    );

    // 插入到Overlay
    overlay.insert(overlayEntry);

    // 延时移除
    Future.delayed(duration ?? const Duration(seconds: 2)).then((value) {
      overlayEntry.remove();
    });
  }

  static void showDetail(BuildContext context, int startIndex, toies, fn) {
    final double dialogWidth = MediaQuery.of(context).size.width - 40;

    showDialog(
      context: context,
      builder: (context) => _ToyDetailDialog(
        startIndex: startIndex,
        toies: toies,
        fn: fn,
        dialogWidth: dialogWidth,
      ),
    );
  }

  static Future<void> deleteLocalFilesAsync(List<String> localURLs,
      {bool hasVideo = false}) async {
    if (hasVideo) {
      String pic = localURLs[0];
      String video = localURLs[1];
      try {
        if (await isFileExist(pic)) {
          final file = await getLocalFileForResource(pic);
          await file.delete();
          debugPrint('已删除本地文件: $pic');
        } else {
          debugPrint('本地文件不存在: $pic');
        }
      } catch (e) {
        debugPrint('删除本地文件时发生错误: $e');
      }
      try {
        if (await isFileExist(video, isImg: false)) {
          final file = await getLocalFileForResource(pic, isImg: false);
          await file.delete();
          debugPrint('已删除本地文件: $video');
        } else {
          debugPrint('本地文件不存在: $video');
        }
      } catch (e) {
        debugPrint('删除本地文件时发生错误: $e');
      }
    } else {
      for (String localURL in localURLs) {
        try {
          if (await isFileExist(localURL)) {
            final file = await getLocalFileForResource(localURL);
            await file.delete();
            debugPrint('已删除本地文件: $localURL');
          } else {
            debugPrint('本地文件不存在: $localURL');
          }
        } catch (e) {
          debugPrint('删除本地文件时发生错误: $e');
        }
      }
    }
  }

  static Future<String> getLocalURLForResource(String resourceId,
      {bool isImg = true}) async {
    // 获取应用的本地缓存目录
    final dir = await getApplicationDocumentsDirectory();
    String filename = '';
    // 使用资源 ID 作为文件名
    if (isImg) {
      filename = '$resourceId.jpeg';
    } else {
      filename = '$resourceId.mp4';
    }

    return p.join(dir.path, filename); // 拼接文件路径
  }

  static Future<File> getLocalFileForResource(String resourceId,
      {bool isImg = true}) async {
    // 获取应用的本地缓存目录
    String filename = '';
    final dir = await getApplicationDocumentsDirectory();
    // 使用资源 ID 作为文件名
    if (isImg) {
      filename = '$resourceId.jpeg';
    } else {
      filename = '$resourceId.mp4';
    }
    // 你可以根据需要修改文件扩展名
    return File(p.join(dir.path, filename)); // 拼接文件路径
  }

  static Future<bool> isFileExist(String resourceId,
      {bool isImg = true}) async {
    final file = await getLocalFileForResource(resourceId, isImg: isImg);
    return await file.exists(); // 判断文件是否存在
  }

  static String removeBaseUrl(String url) {
    const baseUrl = 'http://nextsticker.xyz/';
    if (url.startsWith(baseUrl)) {
      return url.substring(baseUrl.length); // 去掉前缀部分
    }
    return url; // 如果没有这个前缀，返回原始 URL
  }
}

class _ToyDetailDialog extends StatefulWidget {
  final int startIndex;
  final dynamic toies;
  final Function fn;
  final double dialogWidth;

  const _ToyDetailDialog({
    Key? key,
    required this.startIndex,
    required this.toies,
    required this.fn,
    required this.dialogWidth,
  }) : super(key: key);

  @override
  State<_ToyDetailDialog> createState() => _ToyDetailDialogState();
}

class _ToyDetailDialogState extends State<_ToyDetailDialog> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.startIndex;
  }

  double _measureText(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return 0;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return textPainter.height;
  }

  double _calculateHeight(dynamic toy) {
    final double contentWidth = widget.dialogWidth - 32.0;

    double aspect = 1.0;
    if (toy != null &&
        toy.picWidth != null &&
        toy.picHeight != null &&
        toy.picHeight > 0) {
      aspect = toy.picWidth / toy.picHeight;
    }
    double imageHeight = contentWidth / aspect;

    final double maxScreenHeight = MediaQuery.of(context).size.height * 0.85;
    final double maxImageHeight = MediaQuery.of(context).size.height * 0.45;
    if (imageHeight > maxImageHeight) {
      imageHeight = maxImageHeight;
    }

    final name = (toy?.toyName ?? '').toString();
    final nameHeight = _measureText(
      name.isNotEmpty ? name : '宝贝',
      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      contentWidth,
    );

    final desc = (toy?.description ?? '').toString();
    final descText = desc.isNotEmpty ? desc : '点击添加宝贝的描述';
    final descHeight = _measureText(
      descText,
      const TextStyle(fontSize: 14),
      contentWidth,
    );

    final priceHeight = _measureText(
      '入手价：¥${toy?.price ?? 0}',
      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      contentWidth,
    );

    final dateText =
        '入手日期：${ToyDetailCard.formatPurchaseDate(toy?.createAt)}  已入手${ToyDetailCard.calculateHoldingDays(toy?.createAt)}天';
    final dateHeight = _measureText(
      dateText,
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      contentWidth,
    );

    // 顶部内边距(16) + 图片高度 + 间距(10) + 名称高度 + 间距(6) + 描述高度 + 间距(6) + 价格高度 + 间距(6) + 日期高度 + 底部内边距(16)
    final totalHeight = 16.0 +
        imageHeight +
        10.0 +
        nameHeight +
        6.0 +
        descHeight +
        6.0 +
        priceHeight +
        6.0 +
        dateHeight +
        16.0;

    return totalHeight.clamp(180.0, maxScreenHeight);
  }

  @override
  Widget build(BuildContext context) {
    final currentToy =
        (_currentIndex >= 0 && _currentIndex < widget.toies.length)
            ? widget.toies[_currentIndex]
            : null;
    final cardHeight = _calculateHeight(currentToy);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: widget.dialogWidth,
        height: cardHeight,
        child: Swiper(
          itemCount: widget.toies.length,
          loop: false,
          index: widget.startIndex,
          onIndexChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return ToyDetailCard(
              key: ValueKey('toy_detail_${widget.toies[index].id}'),
              toy: widget.toies[index],
              dialogWidth: widget.dialogWidth,
              getMore: widget.fn,
              toyList: widget.toies,
              toyIndex: index,
            );
          },
          layout: SwiperLayout.DEFAULT,
        ),
      ),
    );
  }
}
