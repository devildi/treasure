import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/state/ui_state.dart';

void main() {
  group('Simplified State Management Tests', () {
    group('UIState Tests', () {
      late UIState uiState;

      setUp(() {
        uiState = UIState();
      });

      tearDown(() {
        uiState.dispose();
      });

      test('should initialize with default UI state', () {
        expect(uiState.currentPage, 0);
        expect(uiState.previousPage, 0);
        expect(uiState.isNetworkAvailable, true);
        expect(uiState.isOfflineMode, false);
        expect(uiState.hasAnyComponentLoading, false);
      });

      test('should update current page', () {
        uiState.setCurrentPage(2);

        expect(uiState.currentPage, 2);
        expect(uiState.previousPage, 0);

        uiState.setCurrentPage(1);

        expect(uiState.currentPage, 1);
        expect(uiState.previousPage, 2);
      });

      test('should manage network status', () {
        expect(uiState.isNetworkAvailable, true);
        expect(uiState.isOfflineMode, false);

        uiState.setNetworkStatus(false);

        expect(uiState.isNetworkAvailable, false);
        expect(uiState.isOfflineMode, true); // Should auto-enable offline mode
      });

      test('should manage component loading states', () {
        expect(uiState.isComponentLoading('test'), false);
        expect(uiState.hasAnyComponentLoading, false);

        uiState.setComponentLoading('test', true);

        expect(uiState.isComponentLoading('test'), true);
        expect(uiState.hasAnyComponentLoading, true);
        expect(uiState.loadingComponents, contains('test'));

        uiState.setComponentLoading('test', false);

        expect(uiState.isComponentLoading('test'), false);
        expect(uiState.hasAnyComponentLoading, false);
      });

      test('should clear all loading states', () {
        uiState.setComponentLoading('comp1', true);
        uiState.setComponentLoading('comp2', true);

        expect(uiState.hasAnyComponentLoading, true);
        expect(uiState.loadingComponents.length, 2);

        uiState.clearAllLoadingStates();

        expect(uiState.hasAnyComponentLoading, false);
        expect(uiState.loadingComponents.length, 0);
      });

      test('should manage navigation history', () {
        expect(uiState.navigationHistory.length, 0);

        uiState.addToNavigationHistory('/home');
        uiState.addToNavigationHistory('/profile');

        expect(uiState.navigationHistory.length, 2);
        expect(uiState.navigationHistory, contains('/home'));
        expect(uiState.navigationHistory, contains('/profile'));

        uiState.clearNavigationHistory();

        expect(uiState.navigationHistory.length, 0);
      });

      test('should provide state summary', () {
        uiState.setCurrentPage(1);
        uiState.setComponentLoading('summary_test', true);

        final summary = uiState.getStateSummary();

        expect(summary['currentPage'], 1);
        expect(summary['networkAvailable'], true);
        expect(summary['loadingComponents'], contains('summary_test'));
        expect(summary['hasError'], false);
      });

      test('should support batch UI updates', () {
        uiState.batchUIUpdate((updater) {
          updater.setPage(2);
          updater.setNetwork(false);
          updater.setComponentLoading('batch_test', true);
          updater.addNavigationHistory('/batch');
        });

        expect(uiState.currentPage, 2);
        expect(uiState.isNetworkAvailable, false);
        expect(uiState.isComponentLoading('batch_test'), true);
        expect(uiState.navigationHistory, contains('/batch'));
      });

      test('should reset to initial state', () {
        uiState.setCurrentPage(5);
        uiState.setNetworkStatus(false);
        uiState.setComponentLoading('test', true);

        uiState.reset();

        expect(uiState.currentPage, 0);
        expect(uiState.isNetworkAvailable, true);
        expect(uiState.isOfflineMode, false);
        expect(uiState.hasAnyComponentLoading, false);
      });
    });
  });
}