import 'package:flutter/material.dart';

class PageTransitions {
  static const Duration _defaultDuration = Duration(milliseconds: 300);

  // 淡入淡出动画
  static Route<T> fadeTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  // 滑动进入动画
  static Route<T> slideTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    SlideDirection direction = SlideDirection.fromRight,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;
        switch (direction) {
          case SlideDirection.fromLeft:
            begin = const Offset(-1.0, 0.0);
            break;
          case SlideDirection.fromRight:
            begin = const Offset(1.0, 0.0);
            break;
          case SlideDirection.fromTop:
            begin = const Offset(0.0, -1.0);
            break;
          case SlideDirection.fromBottom:
            begin = const Offset(0.0, 1.0);
            break;
        }

        final offsetAnimation = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // 缩放动画
  static Route<T> scaleTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
        );
      },
    );
  }

  // 旋转动画
  static Route<T> rotationTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return RotationTransition(
          turns: CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // 组合动画：滑动 + 缩放
  static Route<T> slideScaleTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    SlideDirection direction = SlideDirection.fromRight,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;
        switch (direction) {
          case SlideDirection.fromLeft:
            begin = const Offset(-1.0, 0.0);
            break;
          case SlideDirection.fromRight:
            begin = const Offset(1.0, 0.0);
            break;
          case SlideDirection.fromTop:
            begin = const Offset(0.0, -1.0);
            break;
          case SlideDirection.fromBottom:
            begin = const Offset(0.0, 1.0);
            break;
        }

        final slideAnimation = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        final scaleAnimation = Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));

        return SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  // 自定义Material风格的页面切换
  static Route<T> materialTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        // 主页面进入动画
        final offsetAnimation = animation.drive(tween);

        // 次级页面退出动画（当前页面向左滑动）
        final secondaryOffsetAnimation = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: curve,
        ));

        return Stack(
          children: [
            SlideTransition(
              position: secondaryOffsetAnimation,
              child: Container(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
            SlideTransition(
              position: offsetAnimation,
              child: Material(
                elevation: 4,
                shadowColor: Colors.black26,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  // 底部弹出动画
  static Route<T> bottomSheetTransition<T extends Object?>(
    Widget child, {
    Duration duration = _defaultDuration,
    RouteSettings? settings,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      opaque: false,
      barrierDismissible: isDismissible,
      barrierColor: Colors.black54,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        final offsetAnimation = animation.drive(tween);

        return GestureDetector(
          onTap: isDismissible ? () => Navigator.of(context).pop() : null,
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {}, // 防止点击child区域时关闭
              child: SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum SlideDirection {
  fromLeft,
  fromRight,
  fromTop,
  fromBottom,
}

// 导航帮助类
class AppNavigator {
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget destination, {
    PageTransitionType type = PageTransitionType.slideScale,
    SlideDirection direction = SlideDirection.fromRight,
    Duration? duration,
  }) {
    Route<T> route;
    
    switch (type) {
      case PageTransitionType.fade:
        route = PageTransitions.fadeTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.slide:
        route = PageTransitions.slideTransition<T>(
          destination,
          direction: direction,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.scale:
        route = PageTransitions.scaleTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.rotation:
        route = PageTransitions.rotationTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 500),
        );
        break;
      case PageTransitionType.slideScale:
        route = PageTransitions.slideScaleTransition<T>(
          destination,
          direction: direction,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.material:
        route = PageTransitions.materialTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
    }
    
    return Navigator.of(context).push<T>(route);
  }

  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget destination, {
    PageTransitionType type = PageTransitionType.slideScale,
    SlideDirection direction = SlideDirection.fromRight,
    Duration? duration,
  }) {
    Route<T> route;
    
    switch (type) {
      case PageTransitionType.fade:
        route = PageTransitions.fadeTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.slide:
        route = PageTransitions.slideTransition<T>(
          destination,
          direction: direction,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.scale:
        route = PageTransitions.scaleTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.rotation:
        route = PageTransitions.rotationTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 500),
        );
        break;
      case PageTransitionType.slideScale:
        route = PageTransitions.slideScaleTransition<T>(
          destination,
          direction: direction,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
      case PageTransitionType.material:
        route = PageTransitions.materialTransition<T>(
          destination,
          duration: duration ?? const Duration(milliseconds: 300),
        );
        break;
    }
    
    return Navigator.of(context).pushReplacement<T, TO>(route);
  }

  static Future<T?> showBottomSheet<T extends Object?>(
    BuildContext context,
    Widget child, {
    Duration? duration,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return Navigator.of(context).push<T>(
      PageTransitions.bottomSheetTransition<T>(
        child,
        duration: duration ?? const Duration(milliseconds: 300),
        isDismissible: isDismissible,
        enableDrag: enableDrag,
      ),
    );
  }
}

enum PageTransitionType {
  fade,
  slide,
  scale,
  rotation,
  slideScale,
  material,
}