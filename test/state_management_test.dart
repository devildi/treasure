import 'package:flutter_test/flutter_test.dart';
import 'package:treasure/core/state/user_state.dart';
import 'package:treasure/core/state/ui_state.dart';
import 'package:treasure/core/state/state_persistence.dart';
import 'package:treasure/toy_model.dart';

void main() {
  group('State Management Tests', () {
    group('UserState Tests', () {
      late UserState userState;

      setUp(() {
        userState = UserState();
      });

      tearDown(() {
        userState.dispose();
      });

      test('should initialize with empty user state', () {
        expect(userState.isLoggedIn, false);
        expect(userState.currentUser.uid, isEmpty);
        expect(userState.isLoading, false);
        expect(userState.hasError, false);
      });

      test('should login successfully', () async {
        final testUser = OwnerModel(
          uid: 'test_uid_123',
          name: 'Test User',
        );

        final result = await userState.login(testUser);

        expect(result, true);
        expect(userState.isLoggedIn, true);
        expect(userState.currentUser.uid, 'test_uid_123');
        expect(userState.currentUser.name, 'Test User');
        expect(userState.state.lastLoginTime, isNotNull);
      });

      test('should logout successfully', () async {
        // First login
        final testUser = OwnerModel(uid: 'test_uid_123');
        await userState.login(testUser);
        expect(userState.isLoggedIn, true);

        // Then logout
        final result = await userState.logout();

        expect(result, true);
        expect(userState.isLoggedIn, false);
        expect(userState.currentUser.uid, isEmpty);
      });

      test('should update user preferences', () async {
        await userState.updatePreference('theme', 'dark');
        await userState.updatePreference('language', 'zh');

        expect(userState.getPreference('theme'), 'dark');
        expect(userState.getPreference('language'), 'zh');
        expect(userState.getPreference('unknown', defaultValue: 'default'), 'default');
      });

      test('should handle batch preference updates', () async {
        final preferences = {
          'theme': 'light',
          'notifications': true,
          'autoSave': false,
        };

        final result = await userState.updatePreferences(preferences);

        expect(result, true);
        expect(userState.getPreference('theme'), 'light');
        expect(userState.getPreference('notifications'), true);
        expect(userState.getPreference('autoSave'), false);
      });

      test('should validate login status', () {
        expect(userState.isLoginValid(), false);

        // Login with a test user
        final testUser = OwnerModel(uid: 'test_123');
        userState.login(testUser);

        expect(userState.isLoginValid(), true);
      });
    });

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

      test('should go to previous page', () {
        uiState.setCurrentPage(3);
        uiState.setCurrentPage(1);

        expect(uiState.currentPage, 1);
        expect(uiState.previousPage, 3);

        uiState.goToPreviousPage();

        expect(uiState.currentPage, 3);
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

      test('should provide state summary', () {
        uiState.setCurrentPage(1);
        uiState.setComponentLoading('summary_test', true);

        final summary = uiState.getStateSummary();

        expect(summary['currentPage'], 1);
        expect(summary['networkAvailable'], true);
        expect(summary['loadingComponents'], contains('summary_test'));
        expect(summary['hasError'], false);
      });
    });

    group('State Persistence Tests', () {
      test('should create SharedPreferences persistence by default', () {
        final persistence = StatePersistence();
        expect(persistence, isNotNull);
      });

      test('should handle save and load operations', () async {
        final persistence = StatePersistence();
        final testData = {'key': 'value', 'number': 42};

        await persistence.save('test_key', testData);
        final loadedData = await persistence.load('test_key');

        expect(loadedData, isNotNull);
        expect(loadedData!['key'], 'value');
        expect(loadedData['number'], 42);
      });

      test('should return null for non-existent keys', () async {
        final persistence = StatePersistence();
        final result = await persistence.load('non_existent_key');

        expect(result, isNull);
      });

      test('should delete data correctly', () async {
        final persistence = StatePersistence();
        final testData = {'test': 'data'};

        await persistence.save('delete_test', testData);
        expect(await persistence.exists('delete_test'), true);

        await persistence.delete('delete_test');
        expect(await persistence.exists('delete_test'), false);
      });
    });
  });
}