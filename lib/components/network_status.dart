import 'package:flutter/material.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/components/interactive_feedback.dart';
import 'dart:io';
import 'dart:async';

class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UIStateSelector<bool>(
      selector: (uiState) => uiState.isNetworkAvailable,
      builder: (context, isNetworkAvailable, child) {
        if (isNetworkAvailable) {
          return const SizedBox.shrink();
        }
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.red.shade100,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: Colors.red.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '网络连接已断开，正在使用离线数据',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                RippleButton(
                  onPressed: () async {
                    await _checkNetworkStatus(context);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkNetworkStatus(BuildContext context) async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (context.mounted) {
          StateManager.uiState(context).setNetworkStatus(true);
          InteractiveFeedback.showSuccess(context, '网络连接已恢复！');
        }
      }
    } on SocketException catch (_) {
      if (context.mounted) {
        StateManager.uiState(context).setNetworkStatus(false);
        InteractiveFeedback.showError(context, '网络仍然无法连接');
      }
    }
  }
}

class ConnectionStatusIndicator extends StatelessWidget {
  final Color? onlineColor;
  final Color? offlineColor;
  final double size;

  const ConnectionStatusIndicator({
    Key? key,
    this.onlineColor,
    this.offlineColor,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return UIStateSelector<bool>(
      selector: (uiState) => uiState.isNetworkAvailable,
      builder: (context, isNetworkAvailable, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isNetworkAvailable 
                ? (onlineColor ?? Colors.green) 
                : (offlineColor ?? Colors.red),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isNetworkAvailable 
                    ? (onlineColor ?? Colors.green) 
                    : (offlineColor ?? Colors.red)).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showOfflineMessage;

  const NetworkAwareWidget({
    Key? key,
    required this.child,
    this.offlineWidget,
    this.showOfflineMessage = true,
  }) : super(key: key);

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  @override
  Widget build(BuildContext context) {
    return UIStateSelector<bool>(
      selector: (uiState) => uiState.isNetworkAvailable,
      builder: (context, isNetworkAvailable, child) {
        if (!isNetworkAvailable && widget.offlineWidget != null) {
          return widget.offlineWidget!;
        }
        
        return Stack(
          children: [
            widget.child,
            if (!isNetworkAvailable && widget.showOfflineMessage)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NetworkStatusBanner(),
              ),
          ],
        );
      },
    );
  }
}

class OfflineDataWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final Widget? icon;

  const OfflineDataWidget({
    Key? key,
    this.message = '暂无网络连接，显示本地数据',
    this.onRetry,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon ?? 
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            LoadingButton(
              text: '重新连接',
              onPressed: onRetry,
              backgroundColor: Colors.blue,
              height: 44,
            ),
          ],
        ],
      ),
    );
  }
}

class NetworkDiagnostic {
  static Future<NetworkStatus> checkNetworkStatus() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return NetworkStatus.connected;
      }
      return NetworkStatus.disconnected;
    } on SocketException catch (_) {
      return NetworkStatus.disconnected;
    } catch (e) {
      return NetworkStatus.unknown;
    }
  }

  static Future<int> checkNetworkLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      await InternetAddress.lookup('google.com');
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  static Future<Map<String, dynamic>> getNetworkInfo() async {
    final status = await checkNetworkStatus();
    final latency = status == NetworkStatus.connected 
        ? await checkNetworkLatency() 
        : -1;
    
    return {
      'status': status,
      'latency': latency,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

enum NetworkStatus {
  connected,
  disconnected,
  unknown,
}

class NetworkStatusProvider extends StatefulWidget {
  final Widget child;
  final Duration checkInterval;

  const NetworkStatusProvider({
    Key? key,
    required this.child,
    this.checkInterval = const Duration(seconds: 30),
  }) : super(key: key);

  @override
  State<NetworkStatusProvider> createState() => _NetworkStatusProviderState();
}

class _NetworkStatusProviderState extends State<NetworkStatusProvider> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startNetworkMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startNetworkMonitoring() {
    _timer = Timer.periodic(widget.checkInterval, (timer) async {
      if (mounted) {
        final status = await NetworkDiagnostic.checkNetworkStatus();
        if (mounted) {
          StateManager.readUIState(context).setNetworkStatus(
            status == NetworkStatus.connected,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

