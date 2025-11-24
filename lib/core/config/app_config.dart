import 'environment_config.dart';
enum Environment {
  development,
  staging,
  production,
}
class AppConfig {
  static Environment get _currentEnvironment => EnvironmentConfig.currentEnv;
  
  static Environment get currentEnvironment => _currentEnvironment;
  
  static String get baseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        return 'http://10.96.162.50:4000/';
      case Environment.staging:
        return 'https://staging.nextsticker.cn/';
      case Environment.production:
        return 'https://nextsticker.cn/';
    }
  }
  
  static bool get isDevelopment => _currentEnvironment == Environment.development;
  static bool get isProduction => _currentEnvironment == Environment.production;
  static bool get isStaging => _currentEnvironment == Environment.staging;
  
  // Network configuration
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  static const int sendTimeout = 15000;
  
  // Cache configuration
  static const Duration cacheExpiration = Duration(minutes: 5);
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);
  
  // API endpoints
  static const String loginEndpoint = 'api/treasure/login';
  static const String registerEndpoint = 'api/treasure/register';
  static const String uploadTokenEndpoint = 'api/trip/getUploadToken';
  static const String createToyEndpoint = 'api/treasure/newItem';
  static const String getAllToysEndpoint = 'api/treasure/getAllTreasures';
  static const String getTotalPriceEndpoint = 'api/treasure/getTotalPriceAndCount';
  static const String searchEndpoint = 'api/treasure/search';
  static const String modifyToyEndpoint = 'api/treasure/modify';
  static const String deleteToyEndpoint = 'api/treasure/delete';
}
