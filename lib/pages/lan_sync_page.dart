import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/sync/sync_manager.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/toy_model.dart';

enum SyncMode {
  none,
  sender,
  receiver,
}

class LanSyncPage extends StatefulWidget {
  final OwnerModel currentUser;

  const LanSyncPage({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<LanSyncPage> createState() => _LanSyncPageState();
}

class _LanSyncPageState extends State<LanSyncPage> {
  final SyncManager _syncManager = SyncManager();
  final TextEditingController _ipController = TextEditingController();

  SyncMode _mode = SyncMode.none;
  String _serverIp = '';
  BackupSummary? _backupSummary;
  SyncServerState _serverState = const SyncServerIdle();

  bool _isSyncing = false;
  bool _isSuccess = false;
  String _syncStatus = '';
  ImportSummary? _importSummary;

  @override
  void initState() {
    super.initState();
    _syncManager.onServerStateChanged = (state) {
      if (mounted) {
        setState(() {
          _serverState = state;
        });
      }
    };
  }

  @override
  void dispose() {
    _syncManager.onServerStateChanged = null;
    _syncManager.stopServer();
    _syncManager.deleteBackup();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _switchToSender() async {
    setState(() {
      _mode = SyncMode.sender;
      _backupSummary = null;
      _serverIp = '';
      _serverState = const SyncServerIdle();
    });

    try {
      final summary = await _syncManager.exportData(user: widget.currentUser);
      if (!mounted) return;
      setState(() {
        _backupSummary = summary;
      });

      final ip = await _syncManager.startServer();
      if (!mounted) return;
      setState(() {
        _serverIp = ip;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverState = SyncServerError(null, '服务启动失败: $e');
      });
    }
  }

  Future<void> _switchToReceiver() async {
    setState(() {
      _mode = SyncMode.receiver;
      _serverIp = '';
      _backupSummary = null;
      _serverState = const SyncServerIdle();
      _isSyncing = false;
      _isSuccess = false;
      _syncStatus = '';
      _importSummary = null;
    });
    await _syncManager.stopServer();
    await _syncManager.deleteBackup();
  }

  Future<void> _startImport() async {
    final targetIp = _ipController.text.trim();
    if (targetIp.isEmpty) {
      CommonUtils.showSnackBar(context, '请输入发送方 IP 地址');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSyncing = true;
      _isSuccess = false;
      _syncStatus = '正在连接到 $targetIp...';
      _importSummary = null;
    });

    try {
      final userState = StateManager.readUserState(context);
      final summary = await _syncManager.importData(
        targetIp,
        userState: userState,
      );

      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _isSuccess = true;
        _importSummary = summary;
        final sizeKb = (summary.totalSizeBytes / 1024).toStringAsFixed(1);
        _syncStatus =
            '数据同步成功！\n数据大小: $sizeKb KB\n宝贝记录: ${summary.itemCount} 条\n包含图片: ${summary.imageCount} 张\n用户数据: ${summary.userName}';
      });
      CommonUtils.showSnackBar(context, '数据同步成功！');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _isSuccess = false;
        _syncStatus = '同步失败: $e';
      });
    }
  }

  void _handleBack() {
    if (_mode != SyncMode.none) {
      setState(() {
        _mode = SyncMode.none;
        _backupSummary = null;
        _serverIp = '';
        _serverState = const SyncServerIdle();
      });
      _syncManager.stopServer();
      _syncManager.deleteBackup();
    } else {
      Navigator.pop(context, _isSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _mode == SyncMode.none,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            '局域网数据同步',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _handleBack,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mode == SyncMode.none) _buildNoneMode(),
              if (_mode == SyncMode.sender) _buildSenderMode(),
              if (_mode == SyncMode.receiver) _buildReceiverMode(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoneMode() {
    return Column(
      children: [
        // 说明卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '请确保两台设备连接在同一个 Wi-Fi 或热点局域网下，即可快速无损地同步所有宝贝与用户数据（包含所有图片）。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // 发送方按钮
        ElevatedButton(
          key: const Key('btn_sync_sender'),
          onPressed: _switchToSender,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_rounded, size: 22),
              SizedBox(width: 8),
              Text(
                '我是发送方 (分享数据)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 接收方按钮
        ElevatedButton(
          key: const Key('btn_sync_receiver'),
          onPressed: _switchToReceiver,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            elevation: 1,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_rounded, size: 22),
              SizedBox(width: 8),
              Text(
                '我是接收方 (接收数据)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSenderMode() {
    return Column(
      children: [
        // 数据明细卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '打包数据明细',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_backupSummary == null) ...[
                const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在打包宝贝与图片数据...',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildSummaryRow(
                  icon: Icons.toys_outlined,
                  title: '宝贝记录',
                  value: '${_backupSummary!.itemCount} 条',
                ),
                const SizedBox(height: 10),
                _buildSummaryRow(
                  icon: Icons.image_outlined,
                  title: '包含图片',
                  value: '${_backupSummary!.imageCount} 张',
                ),
                const SizedBox(height: 10),
                _buildSummaryRow(
                  icon: Icons.person_outline,
                  title: '用户信息',
                  value: _backupSummary!.userName +
                      (_backupSummary!.hasAvatar ? ' (含头像)' : ''),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  icon: Icons.folder_zip_outlined,
                  title: '备份包大小',
                  value:
                      '${(_backupSummary!.totalSizeBytes / 1024).toStringAsFixed(1)} KB',
                  isBold: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // IP展示卡片
        if (_serverIp.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Text(
                  '请在接收方设备输入此 IP：',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _serverIp));
                    CommonUtils.showSnackBar(context, 'IP 地址已复制到剪贴板');
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _serverIp,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded,
                          size: 20, color: Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '（点击即可复制）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        // 发送状态卡片
        _buildServerStateCard(),
      ],
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String title,
    required String value,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerStateCard() {
    Widget content;
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey[200]!;

    if (_serverState is SyncServerReady) {
      content = const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '局域网服务运行中，等待接收方连接...',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      );
    } else if (_serverState is SyncServerTransferring) {
      final clientIp = (_serverState as SyncServerTransferring).clientIp;
      bgColor = Colors.blue.withOpacity(0.08);
      borderColor = Colors.blue.withOpacity(0.3);
      content = Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '正在向设备 ($clientIp) 传输数据...',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      );
    } else if (_serverState is SyncServerSuccess) {
      final clientIp = (_serverState as SyncServerSuccess).clientIp;
      bgColor = Colors.green.withOpacity(0.1);
      borderColor = Colors.green.withOpacity(0.3);
      content = Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '同步成功！设备 ($clientIp) 已成功接收并导入数据。',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      );
    } else if (_serverState is SyncServerError) {
      final msg = (_serverState as SyncServerError).message;
      bgColor = Colors.red.withOpacity(0.08);
      borderColor = Colors.red.withOpacity(0.3);
      content = Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '同步异常: $msg',
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
          ),
        ],
      );
    } else {
      content = const Text(
        '服务未启动',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: content,
    );
  }

  Widget _buildReceiverMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 输入框卡片
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '输入发送端 IP 地址',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('input_sync_ip'),
                controller: _ipController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: '例如 192.168.1.5 或 192.168.1.5:8080',
                  prefixIcon: const Icon(Icons.wifi_rounded, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ipController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _ipController.clear();
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data != null && data.text != null) {
                            setState(() {
                              _ipController.text = data.text!.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('btn_connect_sync'),
                  onPressed: _isSyncing || _ipController.text.trim().isEmpty
                      ? null
                      : _startImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSyncing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('正在同步数据...', style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : const Text(
                          '连接并同步数据',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_syncStatus.isNotEmpty) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isSuccess
                ? () {
                    Navigator.pop(context, true);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? Colors.green.withOpacity(0.12)
                    : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSuccess
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _isSuccess ? Colors.green : Colors.red,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _syncStatus,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _isSuccess
                                ? Colors.green[900]
                                : Colors.red[900],
                            fontWeight: _isSuccess
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (_importSummary != null) ...[
                          const Divider(height: 20),
                          _buildSummaryRow(
                            icon: Icons.toys_outlined,
                            title: '宝贝记录',
                            value: '${_importSummary!.itemCount} 条',
                          ),
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            icon: Icons.image_outlined,
                            title: '包含图片',
                            value: '${_importSummary!.imageCount} 张',
                          ),
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            icon: Icons.person_outline,
                            title: '用户数据',
                            value: _importSummary!.userName +
                                (_importSummary!.hasAvatar ? ' (含头像)' : ''),
                          ),
                        ],
                        if (_isSuccess) ...[
                          const SizedBox(height: 10),
                          Text(
                            '点击此处返回首页 ➔',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
