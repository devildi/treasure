import 'package:flutter/material.dart';
import 'package:treasure/core/storage/storage_service.dart';

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({Key? key}) : super(key: key);

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  StorageStats? _stats;
  OfflineDataStatus? _offlineStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() => _loading = true);
    
    try {
      final stats = await StorageService.instance.getStorageStats();
      final offlineStatus = await StorageService.instance.getOfflineStatus();
      
      setState(() {
        _stats = stats;
        _offlineStatus = offlineStatus;
        _loading = false;
      });
    } catch (e) {
      debugPrint('加载存储信息失败: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _clearCache({bool allCache = false}) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(allCache ? '清空所有缓存' : '清理缓存'),
        content: Text(allCache 
          ? '这将清空所有缓存数据，包括图片缓存、API缓存等。确定继续吗？'
          : '这将清理过期和不常用的缓存数据。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                if (allCache) {
                  await StorageService.instance.clearCache(allCache: true);
                } else {
                  await StorageService.instance.cleanupStorage();
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('缓存清理完成')),
                );
                
                await _loadStorageInfo();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('清理失败: $e')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearOfflineData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空离线数据'),
        content: const Text('这将删除所有离线保存的玩具数据。在网络连接时可以重新同步。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await StorageService.instance.clearCache(allCache: true);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('离线数据已清空')),
                );
                
                await _loadStorageInfo();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('清空失败: $e')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadStorageInfo,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStorageOverview(),
                const SizedBox(height: 16),
                _buildOfflineDataSection(),
                const SizedBox(height: 16),
                _buildCacheManagement(),
                const SizedBox(height: 16),
                _buildStorageSettings(),
              ],
            ),
          ),
    );
  }

  Widget _buildStorageOverview() {
    if (_stats == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '存储概览',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 存储使用量进度条
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('存储使用量: ${_stats!.formattedTotalSize} / ${_stats!.formattedMaxSize}'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _stats!.usage.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _stats!.isCriticalSpace 
                      ? Colors.red
                      : _stats!.isLowSpace 
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stats!.usageText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _stats!.isCriticalSpace ? Colors.red : Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 详细信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('缓存数据', _stats!.formattedCacheSize),
                _buildStatItem('应用数据', _stats!.formattedDataSize),
                _buildStatItem('离线项目', '${_stats!.offlineItems} 个'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineDataSection() {
    if (_offlineStatus == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '离线数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.offline_pin,
                color: _offlineStatus!.isStale ? Colors.orange : Colors.green,
              ),
              title: Text('${_offlineStatus!.totalItems} 个离线项目'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_offlineStatus!.statusText),
                  if (_offlineStatus!.lastSyncTime != null)
                    Text(
                      '最后同步: ${_formatDateTime(_offlineStatus!.lastSyncTime!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'clear':
                      _clearOfflineData();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('清空离线数据'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheManagement() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '缓存管理',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cleaning_services),
              title: const Text('智能清理'),
              subtitle: const Text('清理过期和不常用的缓存数据'),
              trailing: ElevatedButton(
                onPressed: () => _clearCache(allCache: false),
                child: const Text('清理'),
              ),
            ),
            
            const Divider(),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清空所有缓存'),
              subtitle: const Text('清空所有缓存数据，释放更多空间'),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _clearCache(allCache: true),
                child: const Text('清空'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '存储设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动缓存图片'),
              subtitle: const Text('在WiFi环境下自动缓存图片'),
              value: StorageService.instance.getSetting('auto_cache_images', defaultValue: true) ?? true,
              onChanged: (value) {
                StorageService.instance.saveSetting('auto_cache_images', value);
                setState(() {});
              },
            ),
            
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动清理过期缓存'),
              subtitle: const Text('应用启动时自动清理过期的缓存数据'),
              value: StorageService.instance.getSetting('auto_cleanup_cache', defaultValue: true) ?? true,
              onChanged: (value) {
                StorageService.instance.saveSetting('auto_cleanup_cache', value);
                setState(() {});
              },
            ),
            
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('离线模式'),
              subtitle: const Text('网络不可用时使用离线数据'),
              value: StorageService.instance.getSetting('offline_mode_enabled', defaultValue: true) ?? true,
              onChanged: (value) {
                StorageService.instance.saveSetting('offline_mode_enabled', value);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }
}