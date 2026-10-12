import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/state/state_manager.dart';
import 'package:treasure/core/state/ui_state.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/pages/search_results_page.dart';
import 'package:treasure/pages/toy.dart';
import 'package:treasure/toy_model.dart';

void main() {
  final testToy1 = ToyModel(
    id: 'toy_s1',
    toyName: '正义高达 MG 2.0',
    toyPicUrl: '',
    labels: '模型',
    price: 320.0,
    sellPrice: 0.0,
    sellAt: '',
    isSelled: false,
    createAt: '2024-01-01T00:00:00.000Z',
    owner: OwnerModel(name: '玩家A', uid: 'u1', avatar: ''),
  );

  final testToy2 = ToyModel(
    id: 'toy_s2',
    toyName: '自由高达 RG',
    toyPicUrl: '',
    labels: '万代',
    price: 180.0,
    sellPrice: 200.0,
    sellAt: '2024-03-01T00:00:00.000Z',
    isSelled: true,
    createAt: '2024-02-01T00:00:00.000Z',
    owner: OwnerModel(name: '玩家A', uid: 'u1', avatar: ''),
  );

  Widget createTestWidget({
    required Future<List<ToyModel>> Function(String) searchFn,
  }) {
    return StateProviders(
      initialUserState: UserStateData(
        user: OwnerModel(name: '测试用户', uid: 'u1', avatar: ''),
        isLoggedIn: true,
      ),
      initialUIState: const UIStateData(
        currentPageIndex: 0,
        isNetworkAvailable: true,
        isOfflineMode: false,
      ),
      child: MaterialApp(
        home: HomePage(
          search: searchFn,
          clearSearch: () {},
        ),
      ),
    );
  }

  group('Search Navigation & SearchResultsPage Widget Tests', () {
    testWidgets(
        'clicking search button navigates to SearchResultsPage when results found',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          searchFn: (keyword) async {
            if (keyword.contains('高达')) {
              return [testToy1, testToy2];
            }
            return [];
          },
        ),
      );
      await tester.pumpAndSettle();

      // Home page is rendered, search bar exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('search_btn')), findsOneWidget);

      // Enter search keyword
      await tester.enterText(find.byType(TextField), '高达');
      await tester.pumpAndSettle();

      // Click search button
      await tester.tap(find.byKey(const Key('search_btn')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verified: Navigated to SearchResultsPage!
      expect(find.byKey(const Key('search_results_page')), findsOneWidget);
      expect(find.text('关键词: "高达"'), findsOneWidget);
      expect(find.text('共 2 个结果'), findsOneWidget);
      expect(find.text('正义高达 MG 2.0'), findsOneWidget);
      expect(find.text('自由高达 RG'), findsOneWidget);
      expect(find.text('SOLD'), findsOneWidget);

      // Tap back button returns to HomePage
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('search_results_page')), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets(
        'clicking search button does not navigate when results are empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          searchFn: (keyword) async => [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '不存在的宝藏');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('search_btn')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verified: Does NOT navigate to SearchResultsPage
      expect(find.byKey(const Key('search_results_page')), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets(
        'SearchResultsPage displays empty state when results list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        StateProviders(
          initialUserState: UserStateData(
            user: OwnerModel(name: '测试用户', uid: 'u1', avatar: ''),
            isLoggedIn: true,
          ),
          initialUIState: const UIStateData(),
          child: const MaterialApp(
            home: SearchResultsPage(
              keyword: '空结果',
              results: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('关键词: "空结果"'), findsOneWidget);
      expect(find.text('共 0 个结果'), findsOneWidget);
      expect(find.text('未找到相关宝藏'), findsOneWidget);
      expect(find.text('换个关键词试试看吧'), findsOneWidget);
    });
  });
}
