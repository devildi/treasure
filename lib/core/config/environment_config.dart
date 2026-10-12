import 'package:flutter/foundation.dart';
import 'app_config.dart';

class EnvironmentConfig {
  // 在这里修改环境，重新编译即可切换
  static const Environment currentEnv = Environment.production;

  static void configureApp() {
    // 可以根据环境设置不同的配置
    switch (currentEnv) {
      case Environment.development:
        debugPrint('🔧 Running in DEVELOPMENT mode');
        break;
      case Environment.staging:
        debugPrint('🧪 Running in STAGING mode');
        break;
      case Environment.production:
        debugPrint('🚀 Running in PRODUCTION mode');
        break;
    }
  }

  // 获取当前环境信息
  static String get environmentName {
    switch (currentEnv) {
      case Environment.development:
        return 'Development';
      case Environment.staging:
        return 'Staging';
      case Environment.production:
        return 'Production';
    }
  }

  static bool get isProduction => currentEnv == Environment.production;
  static bool get isDevelopment => currentEnv == Environment.development;
  static bool get isStaging => currentEnv == Environment.staging;
}
