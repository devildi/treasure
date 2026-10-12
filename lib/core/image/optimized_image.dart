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
    return widget.placeholder ??
        Container(
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
    return widget.errorWidget ??
        Container(
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
    if (widget.imageUrl.isEmpty) {
      return _buildError();
    }
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
      memCacheWidth: widget.width > 0 ? widget.width.toInt() * 2 : 1, // 2x分辨率缓存
      memCacheHeight: widget.height != null
          ? (widget.height! > 0 ? widget.height!.toInt() : 1)
          : (widget.width > 0
              ? (widget.width * widget.aspectRatio).toInt() * 2
              : 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final safeWidth = widget.width < 0 ? 0.0 : widget.width;
    final containerHeight = widget.height ?? (safeWidth * widget.aspectRatio);

    return Container(
      width: safeWidth,
      height: containerHeight < 0 ? 0.0 : containerHeight,
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
    final safeWidth = width < 0 ? 0.0 : width;

    if (toy == null) {
      return placeholder ??
          Container(
            width: safeWidth,
            height: safeWidth,
            color: Colors.grey[200],
          );
    }

    double picWidth = 0.0;
    double picHeight = 0.0;
    String imageUrl = '';
    String itemName = 'Unknown';

    if (toy is Map) {
      picWidth =
          (toy['picWidth'] is num) ? (toy['picWidth'] as num).toDouble() : 0.0;
      picHeight = (toy['picHeight'] is num)
          ? (toy['picHeight'] as num).toDouble()
          : 0.0;
      imageUrl = toy['toyPicUrl']?.toString() ?? '';
      itemName = toy['toyName']?.toString() ?? 'Unknown';
    } else {
      try {
        picWidth =
            (toy.picWidth is num) ? (toy.picWidth as num).toDouble() : 0.0;
      } catch (_) {}
      try {
        picHeight =
            (toy.picHeight is num) ? (toy.picHeight as num).toDouble() : 0.0;
      } catch (_) {}
      try {
        imageUrl = toy.toyPicUrl?.toString() ?? '';
      } catch (_) {}
      try {
        itemName = toy.toyName?.toString() ?? 'Unknown';
      } catch (_) {}
    }

    final aspectRatio =
        picWidth > 0 && picHeight > 0 ? picHeight / picWidth : 1.0;

    return OptimizedImage(
      imageUrl: imageUrl,
      itemName: itemName,
      width: safeWidth,
      aspectRatio: aspectRatio,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
