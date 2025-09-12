import 'package:flutter/material.dart';
import '../core/image/optimized_image.dart';

/// 向后兼容的图片组件，内部使用优化的图片系统
class ImageWithFallback extends StatelessWidget {
  final dynamic toy;
  final double width;

  const ImageWithFallback({
    Key? key,
    required this.toy,
    required this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OptimizedToyImage(
      toy: toy,
      width: width,
      fit: BoxFit.cover,
    );
  }
}