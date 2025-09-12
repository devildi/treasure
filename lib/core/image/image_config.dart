/// 图片优化配置
class ImageConfig {
  // 图片缓存配置
  static const int maxMemoryCacheSize = 100; // MB
  static const int maxDiskCacheSize = 500;   // MB
  static const Duration defaultCacheTime = Duration(days: 7);
  
  // 图片加载配置
  static const Duration networkTimeout = Duration(seconds: 15);
  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const int retryCount = 3;
  static const Duration retryDelay = Duration(seconds: 1);
  
  // 图片尺寸优化配置
  static const int thumbnailSize = 300;     // 缩略图尺寸
  static const int previewSize = 800;       // 预览图尺寸  
  static const int highQualitySize = 1200;  // 高质量图尺寸
  
  // 预加载配置
  static const int preloadBatchSize = 5;    // 每批预加载图片数量
  static const Duration preloadDelay = Duration(milliseconds: 500);
  
  // 内存管理配置
  static const int memoryPressureThreshold = 80; // 内存压力阈值(MB)
  static const Duration cleanupInterval = Duration(minutes: 30);
  
  /// 根据屏幕密度获取推荐的图片尺寸
  static int getRecommendedImageSize(double devicePixelRatio, double displaySize) {
    final recommendedSize = (displaySize * devicePixelRatio * 1.2).toInt();
    
    if (recommendedSize <= thumbnailSize) return thumbnailSize;
    if (recommendedSize <= previewSize) return previewSize;
    return highQualitySize;
  }
  
  /// 获取图片质量配置
  static int getImageQuality(String imageType) {
    switch (imageType.toLowerCase()) {
      case 'thumbnail':
        return 70;
      case 'preview':
        return 85;
      case 'high_quality':
        return 95;
      default:
        return 80;
    }
  }
}