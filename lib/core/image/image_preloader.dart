import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  final Set<String> _preloadingUrls = <String>{};
  final Set<String> _preloadedUrls = <String>{};
  
  /// Preload images for better performance
  Future<void> preloadImages(
    BuildContext context,
    List<String> imageUrls, {
    int maxConcurrent = 3,
  }) async {
    final urlsToPreload = imageUrls
        .where((url) => 
            url.isNotEmpty && 
            !_preloadedUrls.contains(url) && 
            !_preloadingUrls.contains(url))
        .toList();

    if (urlsToPreload.isEmpty) return;

    // Add to preloading set
    _preloadingUrls.addAll(urlsToPreload);

    // Split into chunks for concurrent loading
    final chunks = _chunkList(urlsToPreload, maxConcurrent);
    
    for (final chunk in chunks) {
      await Future.wait(
        chunk.map((url) => _preloadSingleImage(context, url)),
        eagerError: false, // Continue even if some images fail
      );
    }
  }

  Future<void> _preloadSingleImage(BuildContext context, String url) async {
    if (!context.mounted) return;
    
    try {
      // Use cached_network_image's cache manager to preload
      await CachedNetworkImage.evictFromCache(url);
      
      if (!context.mounted) return;
      
      await precacheImage(
        CachedNetworkImageProvider(url),
        context,
      );
      
      _preloadedUrls.add(url);
      debugPrint('✅ Preloaded image: $url');
    } catch (e) {
      debugPrint('❌ Failed to preload image: $url - $e');
    } finally {
      _preloadingUrls.remove(url);
    }
  }

  /// Preload next page images based on current visible items
  Future<void> preloadNextPageImages(
    BuildContext context,
    List<String> currentPageUrls,
    Future<List<String>> Function() getNextPageUrls, {
    int maxConcurrent = 2,
  }) async {
    if (!context.mounted) return;
    
    try {
      final nextPageUrls = await getNextPageUrls();
      
      if (!context.mounted) return;
      
      await preloadImages(
        context, 
        nextPageUrls, 
        maxConcurrent: maxConcurrent,
      );
    } catch (e) {
      debugPrint('Failed to preload next page images: $e');
    }
  }

  /// Clear preload cache
  void clearPreloadCache() {
    _preloadingUrls.clear();
    _preloadedUrls.clear();
  }

  /// Check if image is preloaded
  bool isImagePreloaded(String url) {
    return _preloadedUrls.contains(url);
  }

  /// Get preload status
  PreloadStatus getPreloadStatus(String url) {
    if (_preloadedUrls.contains(url)) {
      return PreloadStatus.loaded;
    } else if (_preloadingUrls.contains(url)) {
      return PreloadStatus.loading;
    } else {
      return PreloadStatus.notStarted;
    }
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize),
      );
    }
    return chunks;
  }
}

enum PreloadStatus {
  notStarted,
  loading,
  loaded,
}

/// Widget that automatically preloads images when scrolling
class AutoPreloadingScrollView extends StatefulWidget {
  final ScrollController? controller;
  final Widget child;
  final List<String> imageUrls;
  final Future<List<String>> Function()? getNextPageUrls;
  final double preloadThreshold;
  final int maxConcurrentPreloads;

  const AutoPreloadingScrollView({
    Key? key,
    this.controller,
    required this.child,
    required this.imageUrls,
    this.getNextPageUrls,
    this.preloadThreshold = 500.0,
    this.maxConcurrentPreloads = 3,
  }) : super(key: key);

  @override
  AutoPreloadingScrollViewState createState() => AutoPreloadingScrollViewState();
}

class AutoPreloadingScrollViewState extends State<AutoPreloadingScrollView> {
  late ScrollController _controller;
  final ImagePreloader _preloader = ImagePreloader();
  bool _hasPreloadedNextPage = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
    _controller.addListener(_scrollListener);
    
    // Preload initial visible images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadInitialImages();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_scrollListener);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _scrollListener() {
    if (_controller.position.pixels >= 
        _controller.position.maxScrollExtent - widget.preloadThreshold &&
        !_hasPreloadedNextPage &&
        widget.getNextPageUrls != null) {
      _preloadNextPageImages();
    }
  }

  Future<void> _preloadInitialImages() async {
    if (widget.imageUrls.isNotEmpty && mounted) {
      await _preloader.preloadImages(
        context,
        widget.imageUrls.take(6).toList(), // Preload first 6 images
        maxConcurrent: widget.maxConcurrentPreloads,
      );
    }
  }

  Future<void> _preloadNextPageImages() async {
    if (widget.getNextPageUrls == null || _hasPreloadedNextPage) return;
    
    _hasPreloadedNextPage = true;
    
    try {
      final nextPageUrls = await widget.getNextPageUrls!();
      if (mounted) {
        await _preloader.preloadImages(
          context,
          nextPageUrls.take(6).toList(), // Preload first 6 images of next page
          maxConcurrent: 2, // Use fewer concurrent loads for next page
        );
      }
    } catch (e) {
      debugPrint('Failed to preload next page: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Optimized image widget with preloading support
class PreloadableImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const PreloadableImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? 
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported),
        );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit ?? BoxFit.cover,
      placeholder: (context, url) => 
        placeholder ?? 
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      errorWidget: (context, url, error) =>
        errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.red),
        ),
      // Enhanced caching
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      maxWidthDiskCache: width?.toInt(),
      maxHeightDiskCache: height?.toInt(),
    );
  }
}