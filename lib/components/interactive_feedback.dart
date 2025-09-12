import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InteractiveFeedback {
  static void hapticFeedback({HapticFeedbackType type = HapticFeedbackType.selection}) {
    switch (type) {
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  static void showSuccess(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      icon: Icons.check_circle,
      color: Colors.green,
      backgroundColor: Colors.green.shade50,
    );
    hapticFeedback(type: HapticFeedbackType.light);
  }

  static void showError(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      icon: Icons.error,
      color: Colors.red,
      backgroundColor: Colors.red.shade50,
    );
    hapticFeedback(type: HapticFeedbackType.medium);
  }

  static void showInfo(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      icon: Icons.info,
      color: Colors.blue,
      backgroundColor: Colors.blue.shade50,
    );
    hapticFeedback();
  }

  static void showWarning(BuildContext context, String message) {
    _showCustomSnackBar(
      context,
      message,
      icon: Icons.warning,
      color: Colors.orange,
      backgroundColor: Colors.orange.shade50,
    );
    hapticFeedback(type: HapticFeedbackType.medium);
  }

  static void _showCustomSnackBar(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color color,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedToast(
        message: message,
        icon: icon,
        color: color,
        backgroundColor: backgroundColor,
        onDismiss: () => overlayEntry.remove(),
      ),
    );
    
    overlay.insert(overlayEntry);
  }
}

enum HapticFeedbackType {
  selection,
  light,
  medium,
  heavy,
}

class AnimatedToast extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onDismiss;

  const AnimatedToast({
    Key? key,
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<AnimatedToast>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _slideController.forward();
    _fadeController.forward();
    
    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _fadeController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleValue;
  final Duration duration;
  final bool enableHaptic;

  const AnimatedButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.scaleValue = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptic = true,
  }) : super(key: key);

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        if (widget.enableHaptic) {
          InteractiveFeedback.hapticFeedback();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

class RippleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? rippleColor;
  final BorderRadius? borderRadius;
  final bool enableHaptic;

  const RippleButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.rippleColor,
    this.borderRadius,
    this.enableHaptic = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (enableHaptic) {
            InteractiveFeedback.hapticFeedback();
          }
          onPressed?.call();
        },
        splashColor: rippleColor ?? Theme.of(context).primaryColor.withOpacity(0.2),
        highlightColor: rippleColor?.withOpacity(0.1) ?? Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

class LoadingButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const LoadingButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.height = 48,
    this.width,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(LoadingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Theme.of(context).primaryColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor ?? Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      widget.text,
                      style: TextStyle(
                        color: widget.textColor ?? Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    );
            },
          ),
        ),
      ),
    );
  }
}

class SwipeToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const SwipeToRefresh({
    Key? key,
    required this.child,
    required this.onRefresh,
    this.color,
  }) : super(key: key);

  @override
  State<SwipeToRefresh> createState() => _SwipeToRefreshState();
}

class _SwipeToRefreshState extends State<SwipeToRefresh> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        InteractiveFeedback.hapticFeedback(type: HapticFeedbackType.light);
        await widget.onRefresh();
      },
      color: widget.color ?? Theme.of(context).primaryColor,
      backgroundColor: Colors.white,
      strokeWidth: 2,
      child: widget.child,
    );
  }
}