import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Configuration API centralisée pour chaque service (supporte runtime config JS pour Flutter web)
class ApiConfig {
  static String _getEnv(String key, String fallback) {
    if (kIsWeb) {
      try {
        // Import dynamique pour dart:js (web only)
        // Utilise String.fromEnvironment comme fallback pour les tests
        final envValue = String.fromEnvironment(key, defaultValue: '');
        if (envValue.isNotEmpty) {
          return envValue;
        }
      } catch (e) {
        // Si dart:js n'est pas disponible, utiliser le fallback
      }
    }
    return fallback;
  }

  static String get authUrl {
    // fallback local/dev
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('AUTH_URL', 'http://10.0.2.2:8000');
    }
    return _getEnv('AUTH_URL', 'http://localhost:8000/auth');
  }

  static String get friendsUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('FRIENDS_URL', 'http://10.0.2.2:8001');
    }
    return _getEnv('FRIENDS_URL', 'http://localhost:8001/friends');
  }

  static String get messagesUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('MESSAGES_URL', 'http://10.0.2.2:8002');
    }
    return _getEnv('MESSAGES_URL', 'http://localhost:8002/messages');
  }

  static String get teamsUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _getEnv('TEAMS_URL', 'http://10.0.2.2:8003');
    }
    return _getEnv('TEAMS_URL', 'http://localhost:8003/teams');
  }
}
