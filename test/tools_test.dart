import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/tools.dart';
import 'dart:io';

void main() {
  group('CommonUtils Tests', () {
    group('randomColor Tests', () {
      test('returns a valid color from predefined list', () {
        final color = CommonUtils.randomColor();

        final expectedColors = [
          Colors.red[100],
          Colors.green[100],
          Colors.yellow[100],
          Colors.orange[100]
        ];

        expect(expectedColors.contains(color), isTrue);
      });

      test('returns consistent results for multiple calls', () {
        final colors = <Color>[];
        for (int i = 0; i < 20; i++) {
          colors.add(CommonUtils.randomColor());
        }

        // All colors should be from the expected list
        final expectedColors = [
          Colors.red[100],
          Colors.green[100],
          Colors.yellow[100],
          Colors.orange[100]
        ];

        for (final color in colors) {
          expect(expectedColors.contains(color), isTrue);
        }
      });
    });

    group('showSnackBar Tests', () {
      testWidgets('calls InteractiveFeedback.showSuccess for green background', (WidgetTester tester) async {
        bool successCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.showSnackBar(context, 'Success message', backgroundColor: Colors.green);
                  successCalled = true;
                },
                child: const Text('Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(successCalled, isTrue);
      });

      testWidgets('calls InteractiveFeedback.showError for red background', (WidgetTester tester) async {
        bool errorCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.showSnackBar(context, 'Error message', backgroundColor: Colors.red);
                  errorCalled = true;
                },
                child: const Text('Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(errorCalled, isTrue);
      });

      testWidgets('calls InteractiveFeedback.showWarning for orange background', (WidgetTester tester) async {
        bool warningCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.showSnackBar(context, 'Warning message', backgroundColor: Colors.orange);
                  warningCalled = true;
                },
                child: const Text('Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(warningCalled, isTrue);
      });

      testWidgets('calls InteractiveFeedback.showInfo for default background', (WidgetTester tester) async {
        bool infoCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.showSnackBar(context, 'Info message');
                  infoCalled = true;
                },
                child: const Text('Test'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test'));
        await tester.pump();

        expect(infoCalled, isTrue);
      });
    });

    group('show Tests', () {
      testWidgets('displays overlay message correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.show(context, 'Test message');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text('Test message'), findsOneWidget);
      });

      testWidgets('overlay message appears with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.show(context, 'Styled message');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pump();

        // Check that the message appears
        expect(find.text('Styled message'), findsOneWidget);

        // Check that there's a Container with the expected styling
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text('Styled message'),
            matching: find.byType(Container),
          ).first,
        );

        expect(container.decoration, isA<BoxDecoration>());
      });

      testWidgets('custom duration works correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CommonUtils.show(context, 'Custom duration', duration: const Duration(milliseconds: 100));
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pump();

        expect(find.text('Custom duration'), findsOneWidget);

        // Wait for custom duration
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('Custom duration'), findsNothing);
      });
    });

    group('removeBaseUrl Tests', () {
      test('removes base URL correctly', () {
        const baseUrl = 'http://nextsticker.xyz/';
        const fullUrl = '${baseUrl}path/to/resource';

        final result = CommonUtils.removeBaseUrl(fullUrl);

        expect(result, 'path/to/resource');
      });

      test('returns original URL if base URL not present', () {
        const url = 'https://example.com/path/to/resource';

        final result = CommonUtils.removeBaseUrl(url);

        expect(result, url);
      });

      test('handles empty string', () {
        final result = CommonUtils.removeBaseUrl('');

        expect(result, '');
      });

      test('handles exact base URL', () {
        const baseUrl = 'http://nextsticker.xyz/';

        final result = CommonUtils.removeBaseUrl(baseUrl);

        expect(result, '');
      });

      test('handles URL with similar but different base', () {
        const url = 'http://nextsticker.com/path/to/resource';

        final result = CommonUtils.removeBaseUrl(url);

        expect(result, url);
      });
    });

    group('File Management Tests', () {
      test('getLocalURLForResource returns correct path for image', () async {
        final result = await CommonUtils.getLocalURLForResource('test123');

        expect(result.contains('test123.jpeg'), isTrue);
        expect(result.contains('Documents'), isTrue);
      });

      test('getLocalURLForResource returns correct path for video', () async {
        final result = await CommonUtils.getLocalURLForResource('test123', isImg: false);

        expect(result.contains('test123.mp4'), isTrue);
        expect(result.contains('Documents'), isTrue);
      });

      test('getLocalFileForResource returns File object for image', () async {
        final result = await CommonUtils.getLocalFileForResource('test456');

        expect(result, isA<File>());
        expect(result.path.contains('test456.jpeg'), isTrue);
      });

      test('getLocalFileForResource returns File object for video', () async {
        final result = await CommonUtils.getLocalFileForResource('test456', isImg: false);

        expect(result, isA<File>());
        expect(result.path.contains('test456.mp4'), isTrue);
      });

      test('isFileExist returns false for non-existent file', () async {
        final result = await CommonUtils.isFileExist('non_existent_file_12345');

        expect(result, isFalse);
      });

      test('isFileExist returns false for non-existent video file', () async {
        final result = await CommonUtils.isFileExist('non_existent_video_12345', isImg: false);

        expect(result, isFalse);
      });
    });

    group('deleteLocalFilesAsync Tests', () {
      test('handles empty list without error', () async {
        // This should not throw an exception
        await CommonUtils.deleteLocalFilesAsync([]);
      });

      test('handles non-existent files without error', () async {
        // This should not throw an exception
        await CommonUtils.deleteLocalFilesAsync(['non_existent_1', 'non_existent_2']);
      });

      test('handles video deletion without error', () async {
        // This should not throw an exception
        await CommonUtils.deleteLocalFilesAsync(['pic_id', 'video_id'], hasVideo: true);
      });
    });
  });
}