import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/components/swiper_item.dart';
import 'package:treasure/toy_model.dart';

void main() {
  group('ToyDetailCard Widget Tests', () {
    late ToyModel mockToy;

    setUp(() {
      mockToy = ToyModel(
        id: 'test_id',
        toyName: 'Test Toy',
        toyPicUrl: 'https://example.com/image.jpg',
        localUrl: '/local/path/image.jpg',
        picWidth: 200,
        picHeight: 300,
        description: 'Test description',
        labels: 'Test Label',
        owner: OwnerModel(
          name: 'Test Owner',
          uid: 'owner_id',
          avatar: 'avatar_url',
          family: 'Test Family',
        ),
        price: 100,
        sellPrice: 80,
        createAt: '2024-01-01T00:00:00.000Z',
        sellAt: '',
        isSelled: false,
      );
    });

    testWidgets('displays toy information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      // Verify toy name is displayed
      expect(find.text('Test Toy'), findsOneWidget);

      // Verify label is displayed
      expect(find.text('Test Label'), findsOneWidget);

      // Verify description is displayed
      expect(find.text('Test description'), findsOneWidget);

      // Verify prices are displayed
      expect(find.text('购买价：¥100'), findsOneWidget);
      expect(find.text('二手价：¥80'), findsOneWidget);

      // Verify purchase date is displayed
      expect(find.text('购买日期：24-01-01'), findsOneWidget);

      // Verify buttons are displayed
      expect(find.text('闲鱼二手价'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('displays sell price placeholder when sellPrice is 0', (WidgetTester tester) async {
      mockToy.sellPrice = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      expect(find.text('设置卖出价格'), findsOneWidget);
      expect(find.text('二手价：¥0'), findsNothing);
    });

    testWidgets('displays description placeholder when description is empty', (WidgetTester tester) async {
      mockToy.description = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      expect(find.text('点击添加宝贝的描述'), findsOneWidget);
    });

    testWidgets('switch toggles correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      // Find the switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Initial state should be false (isSelled = false)
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, false);

      // Tap the switch
      await tester.tap(switchFinder);
      await tester.pump();

      // Verify the switch state changed
      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, true);
    });

    testWidgets('shows price dialog when tapping on toy name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      // Find and tap on toy name gesture detector
      final gestureDetector = find.ancestor(
        of: find.text('Test Toy'),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(gestureDetector);
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('设置宝贝名字'), findsOneWidget);
      expect(find.text('请输入宝贝名字'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('renders save button correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      // Verify save button exists
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('闲鱼二手价'), findsOneWidget);
    });

    testWidgets('aspect ratio is calculated correctly', (WidgetTester tester) async {
      mockToy.picWidth = 400;
      mockToy.picHeight = 200;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      final aspectRatioWidget = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatioWidget.aspectRatio, 2.0); // 400/200 = 2.0
    });

    testWidgets('switch exists and can be interacted with', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToyDetailCard(
              toy: mockToy,
              dialogWidth: 300,
              getMore: (page) async {},
            ),
          ),
        ),
      );

      // Verify switch exists
      expect(find.byType(Switch), findsOneWidget);

      // Get initial switch state
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);
    });
  });

  group('ToyModel Tests', () {
    test('ToyModel creates instance with required parameters', () {
      final owner = OwnerModel(name: 'Test Owner');
      final toy = ToyModel(
        owner: owner,
        price: 100,
        sellPrice: 80,
        createAt: '2024-01-01',
        sellAt: '',
        isSelled: false,
      );

      expect(toy.owner, owner);
      expect(toy.price, 100);
      expect(toy.sellPrice, 80);
      expect(toy.createAt, '2024-01-01');
      expect(toy.isSelled, false);
      expect(toy.localUrl, ''); // Default value
    });

    test('ToyModel.fromJson creates instance correctly', () {
      final json = {
        '_id': 'test_id',
        'toyName': 'Test Toy',
        'toyPicUrl': 'http://example.com/image.jpg',
        'localUrl': '/local/path/image.jpg',
        'picWidth': 200,
        'picHeight': 300,
        'description': 'Test description',
        'labels': 'Test Label',
        'owner': {
          'name': 'Test Owner',
          '_id': 'owner_id',
          'avatar': 'avatar_url',
          'family': 'Test Family',
        },
        'price': 100,
        'sellPrice': 80,
        'createAt': '2024-01-01',
        'sellAt': '',
        'isSelled': false,
      };

      final toy = ToyModel.fromJson(json);

      expect(toy.id, 'test_id');
      expect(toy.toyName, 'Test Toy');
      expect(toy.toyPicUrl, 'http://example.com/image.jpg');
      expect(toy.localUrl, '/local/path/image.jpg');
      expect(toy.picWidth, 200);
      expect(toy.picHeight, 300);
      expect(toy.description, 'Test description');
      expect(toy.labels, 'Test Label');
      expect(toy.owner.name, 'Test Owner');
      expect(toy.price, 100);
      expect(toy.sellPrice, 80);
      expect(toy.createAt, '2024-01-01');
      expect(toy.isSelled, false);
    });

    test('ToyModel.fromJson handles null values correctly', () {
      final json = <String, dynamic>{
        'owner': null,
        'price': 0,
        'sellPrice': 0,
        'createAt': '',
        'sellAt': '',
        'isSelled': false,
      };

      final toy = ToyModel.fromJson(json);

      expect(toy.id, '');
      expect(toy.toyName, '');
      expect(toy.toyPicUrl, '');
      expect(toy.localUrl, '');
      expect(toy.picWidth, 0);
      expect(toy.picHeight, 0);
      expect(toy.description, '');
      expect(toy.labels, '');
      expect(toy.owner.name, '');
      expect(toy.price, 0);
      expect(toy.sellPrice, 0);
    });

    test('ToyModel.toJson serializes correctly', () {
      final owner = OwnerModel(name: 'Test Owner');
      final toy = ToyModel(
        id: 'test_id',
        toyName: 'Test Toy',
        toyPicUrl: 'http://example.com/image.jpg',
        localUrl: '/local/path/image.jpg',
        picWidth: 200,
        picHeight: 300,
        description: 'Test description',
        labels: 'Test Label',
        owner: owner,
        price: 100,
        sellPrice: 80,
        createAt: '2024-01-01',
        sellAt: '',
        isSelled: false,
      );

      final json = toy.toJson();

      expect(json['id'], 'test_id');
      expect(json['toyName'], 'Test Toy');
      expect(json['toyPicUrl'], 'http://example.com/image.jpg');
      expect(json['localUrl'], '/local/path/image.jpg');
      expect(json['picWidth'], 200);
      expect(json['picHeight'], 300);
      expect(json['description'], 'Test description');
      expect(json['labels'], 'Test Label');
      expect(json['owner'], owner);
      expect(json['price'], 100);
      expect(json['sellPrice'], 80);
      expect(json['createAt'], '2024-01-01');
      expect(json['isSelled'], false);
    });
  });

  group('OwnerModel Tests', () {
    test('OwnerModel creates with default values', () {
      final owner = OwnerModel();

      expect(owner.name, '');
      expect(owner.uid, '');
      expect(owner.avatar, '');
      expect(owner.family, '');
    });

    test('OwnerModel.fromJson creates instance correctly', () {
      final json = {
        'name': 'Test Owner',
        '_id': 'owner_id',
        'avatar': 'avatar_url',
        'family': 'Test Family',
      };

      final owner = OwnerModel.fromJson(json);

      expect(owner.name, 'Test Owner');
      expect(owner.uid, 'owner_id');
      expect(owner.avatar, 'avatar_url');
      expect(owner.family, 'Test Family');
    });

    test('OwnerModel.toJson serializes correctly', () {
      final owner = OwnerModel(
        name: 'Test Owner',
        uid: 'owner_id',
        avatar: 'avatar_url',
        family: 'Test Family',
      );

      final json = owner.toJson();

      expect(json['name'], 'Test Owner');
      expect(json['_id'], 'owner_id');
      expect(json['avatar'], 'avatar_url');
      expect(json['family'], 'Test Family');
    });
  });
}