import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/storage/storage_manager.dart';
import 'package:treasure/core/sync/sync_manager.dart';
import 'package:treasure/dao.dart';
import 'package:treasure/pages/lan_sync_page.dart';
import 'package:treasure/pages/user.dart';
import 'package:treasure/toy_model.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  final Directory appDocDir;

  MockPathProviderPlatform({
    required this.tempDir,
    required this.appDocDir,
  });

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => appDocDir.path;

  @override
  Future<String?> getApplicationSupportPath() async => appDocDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testTempDir;
  late Directory testAppDocDir;

  setUp(() async {
    testTempDir =
        await Directory.systemTemp.createTemp('treasure_sync_test_temp_');
    testAppDocDir =
        await Directory.systemTemp.createTemp('treasure_sync_test_doc_');

    PathProviderPlatform.instance = MockPathProviderPlatform(
      tempDir: testTempDir,
      appDocDir: testAppDocDir,
    );

    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
    await StorageManager.instance.initialize();
    await OfflineDataManager().clearOfflineData();
    await TreasureDao.reloadFromStorage();
  });

  tearDown(() async {
    try {
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
      }
      if (await testAppDocDir.exists()) {
        await testAppDocDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('SyncManager Unit Tests', () {
    test('exportData packages items, images, and user into backup.zip',
        () async {
      // 准备虚拟头像文件
      final avatarFile = File('${testAppDocDir.path}/test_avatar.jpg');
      await avatarFile.writeAsBytes(utf8.encode('fake_avatar_image_bytes'));

      // 准备虚拟玩具图片文件
      final toyImgFile = File('${testAppDocDir.path}/test_toy_img.jpg');
      await toyImgFile.writeAsBytes(utf8.encode('fake_toy_image_bytes'));

      final testUser = OwnerModel(
        uid: 'user_sender_1',
        name: '发送方玩家',
        avatar: avatarFile.path,
      );

      final testToy = ToyModel(
        id: 'toy_sync_1',
        toyName: '同步的高达',
        localUrl: toyImgFile.path,
        toyPicUrl: toyImgFile.path,
        price: 299,
        sellPrice: 0,
        isSelled: false,
        sellAt: '',
        owner: testUser,
        description: '同步测试用玩具',
        labels: '玩具',
        createAt: '2024-05-01',
      );

      await OfflineDataManager().saveToyForOffline(testToy);
      await TreasureDao.reloadFromStorage();

      final syncManager = SyncManager();
      final summary = await syncManager.exportData(user: testUser);

      expect(summary.itemCount, 1);
      expect(summary.imageCount, 2); // 1 avatar + 1 toy image
      expect(summary.hasUserInfo, true);
      expect(summary.userName, '发送方玩家');
      expect(summary.hasAvatar, true);
      expect(summary.totalSizeBytes, greaterThan(0));
      expect(await summary.file.exists(), true);

      await syncManager.deleteBackup();
    });

    test(
        'HTTP server starts, serves backup.zip, handles sync_complete, and stops',
        () async {
      final testUser = OwnerModel(
        uid: 'user_sender_2',
        name: '局域网主机',
        avatar: '',
      );
      final syncManager = SyncManager();
      await syncManager.exportData(user: testUser);

      SyncServerState lastState = const SyncServerIdle();
      syncManager.onServerStateChanged = (state) {
        lastState = state;
      };

      final host = await syncManager.startServer(startPort: 18080);
      expect(host.isNotEmpty, true);
      expect(lastState is SyncServerReady, true);

      final readyState = lastState as SyncServerReady;
      final port = readyState.port;

      // 测试 GET /
      final client = HttpClient();
      final pingReq = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
      final pingRes = await pingReq.close();
      expect(pingRes.statusCode, HttpStatus.ok);
      await pingRes.drain();

      // 测试 GET /backup.zip
      final zipReq =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/backup.zip'));
      final zipRes = await zipReq.close();
      expect(zipRes.statusCode, HttpStatus.ok);
      expect(zipRes.headers.contentType?.mimeType, 'application/zip');
      await zipRes.drain();
      expect(lastState is SyncServerTransferring, true);

      // 测试 GET /sync_complete
      final compReq = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/sync_complete?status=success'));
      final compRes = await compReq.close();
      expect(compRes.statusCode, HttpStatus.ok);
      await compRes.drain();
      expect(lastState is SyncServerSuccess, true);

      client.close();
      await syncManager.stopServer();
      await syncManager.deleteBackup();
    });

    test(
        'importData successfully downloads and restores toys, images, and user',
        () async {
      // 1. 发送端准备数据
      final avatarFile = File('${testAppDocDir.path}/sender_avatar.jpg');
      await avatarFile.writeAsBytes(utf8.encode('sender_avatar_bytes'));

      final toyImgFile = File('${testAppDocDir.path}/sender_toy.jpg');
      await toyImgFile.writeAsBytes(utf8.encode('sender_toy_bytes'));

      final senderUser = OwnerModel(
        uid: 'user_remote_99',
        name: '远程备份用户',
        avatar: avatarFile.path,
      );

      final senderToy = ToyModel(
        id: 'remote_toy_88',
        toyName: '远程传输的机甲',
        localUrl: toyImgFile.path,
        toyPicUrl: toyImgFile.path,
        price: 588,
        sellPrice: 0,
        isSelled: false,
        sellAt: '',
        owner: senderUser,
        description: '局域网远程传输宝贝',
        labels: '电子产品',
        createAt: '2024-06-01',
      );

      await OfflineDataManager().saveToyForOffline(senderToy);

      final senderManager = SyncManager();
      await senderManager.exportData(user: senderUser);
      await senderManager.startServer(startPort: 18090);

      // 2. 接收端清空本地并执行导入
      await OfflineDataManager().clearOfflineData();
      final emptyToys = await OfflineDataManager().getOfflineToys();
      expect(emptyToys.isEmpty, true);

      final userState = UserState();
      final receiverManager = SyncManager();
      final summary = await receiverManager.importData(
        '127.0.0.1:18090',
        userState: userState,
      );

      expect(summary.itemCount, 1);
      expect(summary.hasUserInfo, true);
      expect(summary.userName, '远程备份用户');
      expect(summary.hasAvatar, true);
      expect(summary.totalSizeBytes, greaterThan(0));

      // 验证本地存储是否已更新
      final restoredToys = await OfflineDataManager().getOfflineToys();
      expect(restoredToys.length, 1);
      expect(restoredToys.first.toyName, '远程传输的机甲');
      expect(restoredToys.first.price, 588);
      expect(File(restoredToys.first.localUrl).existsSync(), true);

      expect(userState.currentUser.name, '远程备份用户');
      expect(File(userState.currentUser.avatar).existsSync(), true);

      await senderManager.stopServer();
      await senderManager.deleteBackup();
    });
  });

  group('LanSyncPage Widget Tests', () {
    testWidgets(
        'renders mode selection and navigates to sender and receiver modes',
        (WidgetTester tester) async {
      final user = OwnerModel(
        uid: 'test_user_1',
        name: '测试玩家',
        avatar: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LanSyncPage(currentUser: user),
        ),
      );
      await tester.pumpAndSettle();

      // 验证初始 NONE 模式界面
      expect(find.text('局域网数据同步'), findsOneWidget);
      expect(find.text('我是发送方 (分享数据)'), findsOneWidget);
      expect(find.text('我是接收方 (接收数据)'), findsOneWidget);

      // 切换至发送方模式
      await tester.tap(find.byKey(const Key('btn_sync_sender')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('打包数据明细'), findsOneWidget);

      // 点击返回图标应返回选择模式
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(find.text('我是发送方 (分享数据)'), findsOneWidget);

      // 切换至接收方模式
      await tester.tap(find.byKey(const Key('btn_sync_receiver')));
      await tester.pumpAndSettle();

      expect(find.text('输入发送端 IP 地址'), findsOneWidget);
      expect(find.byKey(const Key('input_sync_ip')), findsOneWidget);
      expect(find.byKey(const Key('btn_connect_sync')), findsOneWidget);

      final inputWidth =
          tester.getSize(find.byKey(const Key('input_sync_ip'))).width;
      final btnWidth =
          tester.getSize(find.byKey(const Key('btn_connect_sync'))).width;
      expect(btnWidth, equals(inputWidth));
    });

    testWidgets('ProfilePage opens LanSyncPage when tapping 同步数据 button',
        (WidgetTester tester) async {
      final user = OwnerModel(
        uid: 'user_123',
        name: '主页玩家',
        avatar: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(
            user: user,
            toies: const [],
            toyCount: 0,
            totalValue: 0,
            getMore: (page) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_sync_btn')), findsOneWidget);
      expect(find.text('同步数据'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_sync_btn')));
      await tester.pumpAndSettle();

      // 验证打开了 LanSyncPage
      expect(find.text('局域网数据同步'), findsOneWidget);
      expect(find.text('我是发送方 (分享数据)'), findsOneWidget);
      expect(find.text('我是接收方 (接收数据)'), findsOneWidget);
    });
  });
}
