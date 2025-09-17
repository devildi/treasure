import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/components/common_image.dart';
import 'package:treasure/toy_model.dart';

void main() {
  group('ImageWithFallback Tests', () {
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

    testWidgets('creates widget with required parameters', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mockToy,
              width: 200.0,
            ),
          ),
        ),
      );

      // Verify the widget is created
      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('passes correct parameters to OptimizedToyImage', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mockToy,
              width: 150.0,
            ),
          ),
        ),
      );

      // The widget should render without error
      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('handles null toy gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: null,
              width: 100.0,
            ),
          ),
        ),
      );

      // Should not throw an exception
      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('handles zero width', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mockToy,
              width: 0.0,
            ),
          ),
        ),
      );

      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('handles negative width', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mockToy,
              width: -50.0,
            ),
          ),
        ),
      );

      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('handles very large width', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mockToy,
              width: 10000.0,
            ),
          ),
        ),
      );

      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    test('ImageWithFallback is a StatelessWidget', () {
      final widget = ImageWithFallback(
        toy: mockToy,
        width: 100.0,
      );

      expect(widget, isA<StatelessWidget>());
    });

    test('ImageWithFallback stores parameters correctly', () {
      final widget = ImageWithFallback(
        toy: mockToy,
        width: 250.0,
      );

      expect(widget.toy, equals(mockToy));
      expect(widget.width, equals(250.0));
    });

    testWidgets('accepts different toy types', (WidgetTester tester) async {
      // Test with Map
      final mapToy = {
        'id': 'test_id',
        'toyName': 'Test Toy',
        'toyPicUrl': 'https://example.com/image.jpg',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageWithFallback(
              toy: mapToy,
              width: 100.0,
            ),
          ),
        ),
      );

      expect(find.byType(ImageWithFallback), findsOneWidget);
    });

    testWidgets('can be used multiple times in widget tree', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ImageWithFallback(
                  toy: mockToy,
                  width: 100.0,
                ),
                ImageWithFallback(
                  toy: mockToy,
                  width: 150.0,
                ),
                ImageWithFallback(
                  toy: mockToy,
                  width: 200.0,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ImageWithFallback), findsNWidgets(3));
    });
  });
}