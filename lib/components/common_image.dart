import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:treasure/tools.dart';
import 'dart:io';
import 'package:dio/dio.dart';

class ImageWithFallback extends StatefulWidget {
  final dynamic toy;
  final double width;

  const ImageWithFallback({
    Key? key,
    required this.toy,
    required this.width,
  }) : super(key: key);

  @override
  State<ImageWithFallback> createState() => ImageWithFallbackState();
}

class ImageWithFallbackState extends State<ImageWithFallback> {
  String localFileURL = '';

  @override
  void initState() {
    super.initState();
    _checkFile(widget.toy);
  }

  Future<void> _checkFile(toy) async {
    String resourceId = CommonUtils.removeBaseUrl(toy.toyPicUrl);
    bool isExists = await CommonUtils.isFileExist(resourceId);
    String localFileURL111 = '';
    if (!isExists) {
      _downloadImage(toy.toyPicUrl, await CommonUtils.getLocalURLForResource(resourceId));
      debugPrint('${toy.toyName}的图片不存在，开始下载...');
    } else{
      localFileURL111 = await CommonUtils.getLocalURLForResource(resourceId);
      debugPrint('${toy.toyName}使用本地图片');
    }
    if (mounted) {
      setState(() {
        localFileURL = localFileURL111;
      });
    }
  }

  Future<void> _downloadImage(String url, String path) async {
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(response.data!);
      if (mounted) {
        setState(() {
          localFileURL = file.path;
        });
      }
    } catch (e) {
      debugPrint('图片下载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = widget.width * widget.toy.picHeight / widget.toy.picWidth;
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      width: widget.width,
      height: height,
      child: localFileURL != ''
      ? Image.file(
          File(localFileURL),
          fit: BoxFit.cover,
        )
      : CachedNetworkImage(
          imageUrl: widget.toy.toyPicUrl,
          fit: BoxFit.cover,
        ),
    );
  }
}