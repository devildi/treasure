import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:treasure/tools.dart';

/// 统一的图片缓存管理器
class ImageCacheManager {
  static final ImageCacheManager _instance = ImageCacheManager._internal();
  factory ImageCacheManager() => _instance;
  ImageCacheManager._internal();

  // 内存缓存，存储已加载的本地路径
  final Map<String, String?> _localPathCache = {};
  
  // 正在下载的图片，避免重复下载
  final Map<String, Future<String?>> _downloadingImages = {};
  
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: 10000, // 10 seconds
    receiveTimeout: 15000, // 15 seconds
    headers: {
      'User-Agent': 'TreasureApp/1.0',
    },
  ));

  /// 获取图片的本地路径，如果不存在则下载
  Future<String?> getImagePath(String imageUrl, String toyName) async {
    if (imageUrl.isEmpty) return null;
    
    final resourceId = CommonUtils.removeBaseUrl(imageUrl);
    
    // 检查内存缓存
    if (_localPathCache.containsKey(resourceId)) {
      return _localPathCache[resourceId];
    }
    
    try {
      // 检查本地文件是否存在
      final localPath = await CommonUtils.getLocalURLForResource(resourceId);
      final isExists = await CommonUtils.isFileExist(resourceId);
      
      if (isExists) {
        debugPrint('🖼️ [$toyName] 使用本地图片缓存');
        _localPathCache[resourceId] = localPath;
        return localPath;
      }
      
      // 检查是否正在下载
      if (_downloadingImages.containsKey(resourceId)) {
        debugPrint('🔄 [$toyName] 等待图片下载完成');
        return await _downloadingImages[resourceId];
      }
      
      // 开始下载
      debugPrint('⬇️ [$toyName] 开始下载图片');
      final downloadFuture = _downloadImage(imageUrl, localPath, toyName);
      _downloadingImages[resourceId] = downloadFuture;
      
      final result = await downloadFuture;
      _downloadingImages.remove(resourceId);
      _localPathCache[resourceId] = result;
      
      return result;
    } catch (e) {
      debugPrint('❌ [$toyName] 图片处理失败: $e');
      _localPathCache[resourceId] = null;
      return null;
    }
  }

  /// 下载图片到本地
  Future<String?> _downloadImage(String url, String path, String toyName) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.data == null) {
        throw Exception('响应数据为空');
      }
      
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(response.data!);
      
      debugPrint('✅ [$toyName] 图片下载完成: ${file.lengthSync()} bytes');
      return file.path;
    } catch (e) {
      debugPrint('❌ [$toyName] 图片下载失败: $e');
      return null;
    }
  }

  /// 预加载图片列表（用于性能优化）
  Future<void> preloadImages(List<Map<String, String>> images) async {
    final List<Future<String?>> futures = [];
    
    for (final image in images) {
      final url = image['url'];
      final name = image['name'];
      if (url != null && name != null) {
        futures.add(getImagePath(url, name));
      }
    }
    
    // 批量等待，但不阻塞UI
    Future.wait(futures).catchError((e) {
      debugPrint('批量预加载失败: $e');
      return <String?>[];
    });
  }

  /// 清理内存缓存
  void clearMemoryCache() {
    _localPathCache.clear();
    debugPrint('🧹 图片内存缓存已清理');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _localPathCache.length,
      'downloading_count': _downloadingImages.length,
    };
  }

  /// 检查图片是否已缓存
  bool isImageCached(String imageUrl) {
    final resourceId = CommonUtils.removeBaseUrl(imageUrl);
    return _localPathCache.containsKey(resourceId) && 
           _localPathCache[resourceId] != null;
  }
}