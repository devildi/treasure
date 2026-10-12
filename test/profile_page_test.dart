import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/components/swiper_item.dart';
import 'package:treasure/pages/user.dart';
import 'package:treasure/toy_model.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/state/ui_state.dart';

void main() {
  Widget createTestWidget(OwnerModel user,
      {List toies = const [], int? toyCount}) {
    return StateProviders(
      initialUserState: UserStateData(
        user: user,
        isLoggedIn: user.uid.isNotEmpty,
      ),
      initialUIState: const UIStateData(
        currentPageIndex: 1,
        isNetworkAvailable: true,
        isOfflineMode: false,
      ),
      child: MaterialApp(
        home: ProfilePage(
          user: user,
          toies: toies,
          toyCount: toyCount ?? toies.length,
          totalValue: 0.0,
          getMore: (page) async {},
        ),
      ),
    );
  }

  group('ProfilePage Unauthenticated / Authenticated Tests', () {
    testWidgets('shows unauthenticated view when user.uid is empty',
        (WidgetTester tester) async {
      final guestUser = OwnerModel(name: '', uid: '', avatar: '');

      await tester.pumpWidget(createTestWidget(guestUser));
      await tester.pumpAndSettle();

      // Should display login prompt and CTA
      expect(find.text('点击登录'), findsOneWidget);
      expect(find.text('登录后管理您的宝贝收藏'), findsOneWidget);
      expect(find.text('登录后查看个人收藏'), findsOneWidget);
      expect(find.text('立即登录'), findsOneWidget);
      expect(find.text('登录'), findsWidgets); // Text button in header
      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('shows authenticated view when user.uid is present',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '玩具收藏大师',
        uid: 'user_12345',
        avatar: '',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser));
      await tester.pumpAndSettle();

      // Should display user name, collector title and 宝贝总数 (logout button is hidden)
      expect(find.text('玩具收藏大师'), findsOneWidget);
      expect(find.text('初级玩家'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsNothing);
      expect(find.text('宝贝总数'), findsOneWidget);
      expect(find.text('点击登录'), findsNothing);
      expect(find.text('暂无收藏物品'), findsOneWidget);
    });

    testWidgets('tapping an item opens unified ToyDetailCard dialog',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '玩具收藏大师',
        uid: 'user_12345',
        avatar: '',
      );
      final testToy = ToyModel(
        id: 'toy_1',
        toyName: '限量高达模型',
        toyPicUrl: 'https://example.com/pic.jpg',
        localUrl: '',
        picWidth: 200,
        picHeight: 200,
        description: '帅气的高达',
        labels: '',
        owner: loggedInUser,
        price: 100,
        sellPrice: 0.0,
        isSelled: false,
        sellAt: '',
        createAt: '2024-05-01T00:00:00.000Z',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser, toies: [testToy]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the item in the collection list and tap it
      expect(find.text('暂无收藏物品'), findsNothing);
      final itemFinder = find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.child is ClipRRect);
      expect(itemFinder, findsOneWidget);

      await tester.tap(itemFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Unified dialog displays ToyDetailCard contents:
      expect(find.text('限量高达模型'), findsOneWidget);
      expect(find.text('帅气的高达'), findsOneWidget);
      expect(find.text('入手价：¥100'), findsOneWidget);
      expect(find.text('入手日期：24-05-01'), findsOneWidget);
      expect(
          find.text(
              '已入手${ToyDetailCard.calculateHoldingDays(testToy.createAt)}天'),
          findsOneWidget);
      // Unified dialog does NOT display old dialog buttons or sell price:
      expect(find.text('二手价'), findsNothing);
      expect(find.text('闲鱼二手价'), findsNothing);
      expect(find.text('保存'), findsNothing);
    });

    testWidgets('displays sync button and edit name icon when logged in',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '玩具收藏大师',
        uid: 'user_12345',
        avatar: '',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_sync_btn')), findsOneWidget);
      expect(find.byKey(const Key('profile_edit_name_btn')), findsOneWidget);
      expect(find.byKey(const Key('profile_avatar_tap')), findsOneWidget);
      expect(find.text('同步数据'), findsOneWidget);
    });

    testWidgets(
        'tapping edit name button opens edit name dialog and updates name',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '初始玩家',
        uid: 'user_12345',
        avatar: '',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser));
      await tester.pumpAndSettle();

      expect(find.text('初始玩家'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_edit_name_btn')));
      await tester.pumpAndSettle();

      expect(find.text('修改用户名字'), findsOneWidget);
      expect(find.byKey(const Key('edit_name_input')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('edit_name_input')), '超级高达玩家');
      await tester.tap(find.byKey(const Key('save_name_btn')));
      await tester.pumpAndSettle();

      expect(find.text('超级高达玩家'), findsOneWidget);
      expect(find.text('初始玩家'), findsNothing);
    });

    testWidgets('does not display edit profile button and shows sync button',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '老收藏家',
        uid: 'user_12345',
        avatar: '',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_edit_btn')), findsNothing);
      expect(find.text('编辑资料'), findsNothing);
      expect(find.byKey(const Key('profile_sync_btn')), findsOneWidget);
    });

    testWidgets('tapping avatar opens change avatar options sheet',
        (WidgetTester tester) async {
      final loggedInUser = OwnerModel(
        name: '玩具收藏大师',
        uid: 'user_12345',
        avatar: 'assets/wechat.png',
      );

      await tester.pumpWidget(createTestWidget(loggedInUser));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('profile_avatar_tap')));
      await tester.pumpAndSettle();

      expect(find.text('选择头像来源'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('输入图片链接'), findsOneWidget);
      expect(find.text('恢复默认头像'), findsOneWidget);
    });

    testWidgets('displays correct player title based on toy count thresholds',
        (WidgetTester tester) async {
      final user = OwnerModel(
        name: '玩家小王',
        uid: 'user_12345',
        avatar: '',
      );

      // 1. toyCount < 25 -> 初级玩家
      await tester.pumpWidget(createTestWidget(user, toyCount: 24));
      await tester.pumpAndSettle();
      expect(find.text('初级玩家'), findsOneWidget);
      expect(find.text('生活在奔小康的路上'), findsNothing);
      expect(find.text('头号玩家'), findsNothing);

      // 2. toyCount >= 25 && < 75 -> 生活在奔小康的路上 (边界值 25)
      await tester.pumpWidget(createTestWidget(user, toyCount: 25));
      await tester.pumpAndSettle();
      expect(find.text('初级玩家'), findsNothing);
      expect(find.text('生活在奔小康的路上'), findsOneWidget);
      expect(find.text('头号玩家'), findsNothing);

      // 3. toyCount >= 25 && < 75 -> 生活在奔小康的路上 (边界值 74)
      await tester.pumpWidget(createTestWidget(user, toyCount: 74));
      await tester.pumpAndSettle();
      expect(find.text('生活在奔小康的路上'), findsOneWidget);
      expect(find.text('头号玩家'), findsNothing);

      // 4. toyCount >= 75 -> 头号玩家 (边界值 75)
      await tester.pumpWidget(createTestWidget(user, toyCount: 75));
      await tester.pumpAndSettle();
      expect(find.text('生活在奔小康的路上'), findsNothing);
      expect(find.text('头号玩家'), findsOneWidget);

      // 5. toyCount > 75 -> 头号玩家 (100)
      await tester.pumpWidget(createTestWidget(user, toyCount: 100));
      await tester.pumpAndSettle();
      expect(find.text('头号玩家'), findsOneWidget);
    });
  });
}
