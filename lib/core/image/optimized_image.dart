import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_cache_manager.dart';

/// 优化的图片组件，支持本地缓存、占位符、错误处理等
class OptimizedImage extends StatefulWidget {
  final String imageUrl;
  final String itemName;
  final double width;
  final double? height;
  final double aspectRatio;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableMemoryCache;
  final Duration fadeInDuration;

  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    required this.itemName,
    required this.width,
    this.height,
    this.aspectRatio = 1.0,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableMemoryCache = true,
    this.fadeInDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<OptimizedImage>
    with AutomaticKeepAliveClientMixin {
  
  String? _localImagePath;
  bool _isLoading = true;
  bool _hasError = false;
  final ImageCacheManager _cacheManager = ImageCacheManager();

  @override
  bool get wantKeepAlive => widget.enableMemoryCache;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _localImagePath = null;
    });

    try {
      final localPath = await _cacheManager.getImagePath(
        widget.imageUrl, 
        widget.itemName,
      );

      if (!mounted) return;

      setState(() {
        _localImagePath = localPath;
        _isLoading = false;
        _hasError = localPath == null;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      debugPrint('加载图片失败 [${widget.itemName}]: $e');
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ?? Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildError() {
    return widget.errorWidget ?? Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Colors.grey[600],
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            '图片加载失败',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalImage(String path) {
    return Image.file(
      File(path),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: widget.fadeInDuration,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('⚠️ 本地图片加载失败 [${widget.itemName}]，尝试网络加载: $error');
        // 本地加载失败时，降级尝试网络加载
        return _buildNetworkImage();
      },
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      fadeInDuration: widget.fadeInDuration,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) {
        debugPrint('网络图片加载错误 [${widget.itemName}]: $error');
        return _buildError();
      },
      memCacheWidth: widget.width.toInt() * 2, // 2x分辨率缓存
      memCacheHeight: widget.height?.toInt() ?? 
                     (widget.width * widget.aspectRatio).toInt() * 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final containerHeight = widget.height ?? (widget.width * widget.aspectRatio);
    
    return Container(
      width: widget.width,
      height: containerHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isLoading 
        ? _buildPlaceholder()
        : _hasError 
          ? _buildNetworkImage() // 降级到网络图片
          : _localImagePath != null
            ? _buildLocalImage(_localImagePath!)
            : _buildNetworkImage(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// 专门用于玩具图片的组件，自动计算高度
class OptimizedToyImage extends StatelessWidget {
  final dynamic toy;
  final double width;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedToyImage({
    Key? key,
    required this.toy,
    required this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final aspectRatio = toy.picWidth > 0 ? toy.picHeight / toy.picWidth : 1.0;
    
    return OptimizedImage(
      imageUrl: toy.toyPicUrl ?? '',
      itemName: toy.toyName ?? 'Unknown',
      width: width,
      aspectRatio: aspectRatio,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}