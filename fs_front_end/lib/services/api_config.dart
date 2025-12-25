import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:js' as js;

/// Configuration API centralisée pour chaque service (supporte runtime config JS pour Flutter web)
class ApiConfig {
  static String _getEnv(String key, String fallback) {
    if (kIsWeb) {
      final env = js.context.hasProperty('env') ? js.context['env'] : null;
      if (env != null &&
          env.hasProperty(key) &&
          env[key] != null &&
          (env[key] as String).isNotEmpty) {
        return env[key] as String;
      }
    }
    return fallback;
  }

  static String get authUrl {
    // fallback local/dev
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('AUTH_URL', 'http://10.0.2.2:8000');
    }
    return _getEnv('AUTH_URL', 'http://127.0.0.1:8000');
  }

  static String get friendsUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('FRIENDS_URL', 'http://10.0.2.2:8001');
    }
    return _getEnv('FRIENDS_URL', 'http://127.0.0.1:8001');
  }

  static String get messagesUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('MESSAGES_URL', 'http://10.0.2.2:8002');
    }
    return _getEnv('MESSAGES_URL', 'http://127.0.0.1:8002');
  }

  static String get teamsUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('TEAMS_URL', 'http://10.0.2.2:8003');
    }
    return _getEnv('TEAMS_URL', 'http://127.0.0.1:8003');
  }
}
