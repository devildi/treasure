import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/storage/storage_manager.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/tools.dart';
import 'package:treasure/toy_model.dart';

class BackupSummary {
  final File file;
  final int itemCount;
  final int imageCount;
  final bool hasUserInfo;
  final String userName;
  final bool hasAvatar;
  final int totalSizeBytes;

  const BackupSummary({
    required this.file,
    required this.itemCount,
    required this.imageCount,
    required this.hasUserInfo,
    required this.userName,
    required this.hasAvatar,
    required this.totalSizeBytes,
  });
}

class ImportSummary {
  final int totalSizeBytes;
  final int itemCount;
  final int imageCount;
  final bool hasUserInfo;
  final String userName;
  final bool hasAvatar;

  const ImportSummary({
    required this.totalSizeBytes,
    required this.itemCount,
    required this.imageCount,
    required this.hasUserInfo,
    required this.userName,
    required this.hasAvatar,
  });
}

abstract class SyncServerState {
  const SyncServerState();
}

class SyncServerIdle extends SyncServerState {
  const SyncServerIdle();
}

class SyncServerReady extends SyncServerState {
  final String serverIp;
  final int port;
  const SyncServerReady(this.serverIp, this.port);

  String get fullAddress => port == 8080 ? serverIp : '$serverIp:$port';
}

class SyncServerTransferring extends SyncServerState {
  final String clientIp;
  const SyncServerTransferring(this.clientIp);
}

class SyncServerSuccess extends SyncServerState {
  final String clientIp;
  const SyncServerSuccess(this.clientIp);
}

class SyncServerError extends SyncServerState {
  final String? clientIp;
  final String message;
  const SyncServerError(this.clientIp, this.message);
}

class SyncManager {
  SimpleWebServer? _server;
  void Function(SyncServerState)? onServerStateChanged;

  Directory? _cachedBackupDir;

  Future<Directory> _getBackupDir() async {
    if (_cachedBackupDir != null) return _cachedBackupDir!;
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'sync_backup'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedBackupDir = dir;
    return dir;
  }

  /// 打包导出全量数据（包含所有宝贝、所有用户数据及全部对应图片）
  Future<BackupSummary> exportData({required OwnerModel user}) async {
    final backupDir = await _getBackupDir();
    final zipFile = File(p.join(backupDir.path, 'backup.zip'));
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    final archive = Archive();
    final imageMap = <String, File>{};

    // 1. 打包用户数据
    final userJson = user.toJson();
    bool hasAvatar = false;
    if (user.avatar.isNotEmpty &&
        !user.avatar.startsWith('http') &&
        !user.avatar.startsWith('assets/')) {
      final avatarFile = File(user.avatar);
      if (await avatarFile.exists()) {
        final relPath = 'images/avatars/${p.basename(user.avatar)}';
        imageMap[relPath] = avatarFile;
        userJson['synced_avatar_file'] = relPath;
        hasAvatar = true;
      }
    }

    // 2. 打包所有宝贝数据与图片
    final toys = await OfflineDataManager().getOfflineToys();
    final toysList = <Map<String, dynamic>>[];
    int imageCount = hasAvatar ? 1 : 0;

    for (final toy in toys) {
      final toyMap = toy.toJson();
      File? imageFile;

      // 检索可能的图片文件来源
      if (toy.localUrl.isNotEmpty && File(toy.localUrl).existsSync()) {
        imageFile = File(toy.localUrl);
      } else if (toy.toyPicUrl.isNotEmpty &&
          (toy.toyPicUrl.startsWith('/') || File(toy.toyPicUrl).existsSync())) {
        final f = File(toy.toyPicUrl);
        if (f.existsSync()) imageFile = f;
      }

      if (imageFile == null && toy.toyPicUrl.isNotEmpty) {
        final resId = CommonUtils.removeBaseUrl(toy.toyPicUrl);
        if (await CommonUtils.isFileExist(resId)) {
          imageFile = await CommonUtils.getLocalFileForResource(resId);
        }
      }

      if (imageFile != null && await imageFile.exists()) {
        final ext = p.extension(imageFile.path).isNotEmpty
            ? p.extension(imageFile.path)
            : '.jpeg';
        final relPath = 'images/items/toy_${toy.id}$ext';
        imageMap[relPath] = imageFile;
        toyMap['synced_image_file'] = relPath;
        imageCount++;
      }

      toysList.add(toyMap);
    }

    // 3. 构建 data.json 并加入压缩包
    final backupData = {
      'version': 1,
      'appName': 'treasure',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'user': userJson,
      'toys': toysList,
    };

    final jsonString = jsonEncode(backupData);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    // 4. 将所有图片加入压缩包
    for (final entry in imageMap.entries) {
      final bytes = await entry.value.readAsBytes();
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }

    // 5. 压缩并写入磁盘
    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    if (encoded == null) {
      throw Exception('打包数据失败');
    }
    await zipFile.writeAsBytes(encoded);

    final summary = BackupSummary(
      file: zipFile,
      itemCount: toys.length,
      imageCount: imageCount,
      hasUserInfo: user.name.isNotEmpty || user.uid.isNotEmpty,
      userName: user.name.isNotEmpty ? user.name : '本地用户',
      hasAvatar: hasAvatar,
      totalSizeBytes: await zipFile.length(),
    );

    return summary;
  }

  /// 启动局域网 HTTP 服务
  Future<String> startServer({int startPort = 8080}) async {
    await stopServer();

    final backupDir = await _getBackupDir();
    final zipFile = File(p.join(backupDir.path, 'backup.zip'));
    if (!await zipFile.exists()) {
      throw Exception('备份包文件不存在，请先打包数据');
    }

    var port = startPort;
    final maxPort = startPort + 10;
    Object? lastErr;

    while (port <= maxPort) {
      try {
        final server = SimpleWebServer(
          port: port,
          backupZip: zipFile,
          onStateChange: (state) {
            onServerStateChanged?.call(state);
          },
        );
        await server.start();
        _server = server;

        final ip = await getDeviceIpAddress();
        onServerStateChanged?.call(SyncServerReady(ip, port));
        return port == 8080 ? ip : '$ip:$port';
      } catch (e) {
        lastErr = e;
        port++;
      }
    }

    final errorMsg = '未能找到可用端口（$startPort-$maxPort）: $lastErr';
    onServerStateChanged?.call(SyncServerError(null, errorMsg));
    throw Exception(errorMsg);
  }

  /// 停止局域网 HTTP 服务
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.stop();
      _server = null;
    }
    onServerStateChanged?.call(const SyncServerIdle());
  }

  /// 删除本地临时备份
  Future<void> deleteBackup() async {
    try {
      final dir = await _getBackupDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _cachedBackupDir = null;
    } catch (e) {
      debugPrint('删除临时备份异常: $e');
    }
  }

  /// 从发送端导入全量数据
  Future<ImportSummary> importData(
    String serverIp, {
    UserState? userState,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    final cleanIp = serverIp.trim();
    final finalIp = cleanIp.contains(':') ? cleanIp : '$cleanIp:8080';
    final zipUrl = Uri.parse('http://$finalIp/backup.zip');

    HttpClientResponse response;
    try {
      final request = await client.getUrl(zipUrl);
      response = await request.close();
    } catch (e) {
      throw Exception('无法连接到发送端 ($finalIp)，请确保在同一局域网并检查 IP 地址');
    }

    if (response.statusCode != HttpStatus.ok) {
      throw Exception('连接失败，HTTP 状态码: ${response.statusCode}');
    }

    final tempDir = await getTemporaryDirectory();
    final tempZip = File(p.join(tempDir.path, 'sync_import_temp.zip'));
    final extractDir = Directory(p.join(tempDir.path, 'sync_import_extracted'));

    try {
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create(recursive: true);

      // 下载 zip
      final fileSink = tempZip.openWrite();
      await response.pipe(fileSink);

      final totalSizeBytes = await tempZip.length();

      // 解压 zip
      final zipBytes = await tempZip.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      for (final file in archive) {
        if (file.isFile) {
          final outFile = File(p.join(extractDir.path, file.name));
          await outFile.parent.create(recursive: true);
          final data = file.content as List<int>;
          await outFile.writeAsBytes(data);
        }
      }

      // 读取 data.json
      final jsonFile = File(p.join(extractDir.path, 'data.json'));
      if (!await jsonFile.exists()) {
        throw Exception('未找到 data.json 备份数据文件');
      }

      final jsonContent = await jsonFile.readAsString();
      final backupData = jsonDecode(jsonContent) as Map<String, dynamic>;

      final appDir = await getApplicationDocumentsDirectory();

      // 1. 导入用户信息与头像图片
      final userData = backupData['user'] as Map<String, dynamic>?;
      bool hasAvatar = false;
      String userName = '本地用户';

      if (userData != null) {
        final syncedAvatar = userData['synced_avatar_file'] as String?;
        if (syncedAvatar != null) {
          final extractedAvatar = File(p.join(extractDir.path, syncedAvatar));
          if (await extractedAvatar.exists()) {
            final avatarDir =
                Directory(p.join(appDir.path, 'treasure_avatars'));
            if (!await avatarDir.exists()) {
              await avatarDir.create(recursive: true);
            }
            final targetAvatar = File(
              p.join(avatarDir.path, p.basename(extractedAvatar.path)),
            );
            await extractedAvatar.copy(targetAvatar.path);
            userData['avatar'] = targetAvatar.path;
            hasAvatar = true;
          }
        }

        final restoredUser = OwnerModel.fromJson(userData);
        userName = restoredUser.name;

        // 持久化保存用户
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth', jsonEncode(restoredUser.toJson()));
          if (userState != null) {
            if (userState.isLoggedIn) {
              await userState.updateUser(restoredUser);
            } else if (restoredUser.uid.isNotEmpty) {
              await userState.login(restoredUser);
            }
          }
        } catch (e) {
          debugPrint('保存同步用户数据失败: $e');
        }
      }

      // 2. 导入所有宝贝与对应图片
      final rawToys = backupData['toys'] as List? ?? [];
      final restoredToys = <ToyModel>[];
      int imageCount = hasAvatar ? 1 : 0;

      final imagesDir = Directory(p.join(appDir.path, 'treasure_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      for (final raw in rawToys) {
        if (raw is Map) {
          final itemMap = Map<String, dynamic>.from(raw);
          final syncedImage = itemMap['synced_image_file'] as String?;
          if (syncedImage != null) {
            final extractedImg = File(p.join(extractDir.path, syncedImage));
            if (await extractedImg.exists()) {
              final targetImg = File(
                p.join(imagesDir.path, p.basename(extractedImg.path)),
              );
              await extractedImg.copy(targetImg.path);
              itemMap['localUrl'] = targetImg.path;

              final picUrl = (itemMap['toyPicUrl'] ?? '').toString();
              if (picUrl.isEmpty ||
                  picUrl.startsWith('/') ||
                  picUrl.startsWith('file://')) {
                itemMap['toyPicUrl'] = targetImg.path;
              }
              imageCount++;
            }
          }
          restoredToys.add(ToyModel.fromJson(itemMap));
        }
      }

      // 覆盖写入本地存储
      await OfflineDataManager().clearOfflineData();
      await OfflineDataManager().saveToysForOffline(restoredToys);
      await TreasureDao.reloadFromStorage();

      // 通知发送端：同步成功
      try {
        final confirmUrl =
            Uri.parse('http://$finalIp/sync_complete?status=success');
        final confirmReq = await client.getUrl(confirmUrl);
        final confirmRes = await confirmReq.close();
        await confirmRes.drain();
      } catch (e) {
        debugPrint('发送同步确认失败: $e');
      }

      return ImportSummary(
        totalSizeBytes: totalSizeBytes,
        itemCount: restoredToys.length,
        imageCount: imageCount,
        hasUserInfo: userData != null,
        userName: userName,
        hasAvatar: hasAvatar,
      );
    } catch (e) {
      // 通知发送端：同步失败
      try {
        final encodedErr = Uri.encodeComponent(e.toString());
        final failUrl = Uri.parse(
          'http://$finalIp/sync_complete?status=fail&error=$encodedErr',
        );
        final failReq = await client.getUrl(failUrl);
        final failRes = await failReq.close();
        await failRes.drain();
      } catch (_) {}
      rethrow;
    } finally {
      // 清理临时文件
      try {
        if (await tempZip.exists()) await tempZip.delete();
        if (await extractDir.exists()) await extractDir.delete(recursive: true);
      } catch (_) {}
      client.close();
    }
  }

  /// 获取设备在局域网中的 IPv4 地址
  static Future<String> getDeviceIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // 优先匹配 wlan / en / wifi 接口
      interfaces.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aIsWifi = aName.contains('wlan') ||
            aName.contains('en') ||
            aName.contains('wi');
        final bIsWifi = bName.contains('wlan') ||
            bName.contains('en') ||
            bName.contains('wi');
        if (aIsWifi && !bIsWifi) return -1;
        if (!aIsWifi && bIsWifi) return 1;
        return 0;
      });

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            if (ip.isNotEmpty && ip != '127.0.0.1') {
              return ip;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('获取局域网IP失败: $e');
    }
    return '127.0.0.1';
  }
}

class SimpleWebServer {
  final int port;
  final File backupZip;
  final void Function(SyncServerState) onStateChange;
  HttpServer? _server;

  SimpleWebServer({
    required this.port,
    required this.backupZip,
    required this.onStateChange,
  });

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen((HttpRequest request) async {
      try {
        final uri = request.uri;
        final clientIp =
            request.connectionInfo?.remoteAddress.address ?? '未知设备';

        if (uri.path == '/backup.zip') {
          if (await backupZip.exists()) {
            onStateChange(SyncServerTransferring(clientIp));
            request.response.headers.contentType =
                ContentType('application', 'zip');
            final length = await backupZip.length();
            request.response.headers.contentLength = length;
            await request.response.addStream(backupZip.openRead());
            await request.response.close();
          } else {
            onStateChange(SyncServerError(clientIp, '备份数据文件不存在'));
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Backup file not found');
            await request.response.close();
          }
        } else if (uri.path == '/sync_complete') {
          final status = uri.queryParameters['status'];
          final error = uri.queryParameters['error'];
          if (status == 'success') {
            onStateChange(SyncServerSuccess(clientIp));
          } else {
            final msg = error ?? '接收端处理失败';
            onStateChange(SyncServerError(clientIp, msg));
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.write('OK');
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.write('Treasure Sync Server Ready');
          await request.response.close();
        }
      } catch (e) {
        debugPrint('处理同步请求异常: $e');
      }
    });
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
