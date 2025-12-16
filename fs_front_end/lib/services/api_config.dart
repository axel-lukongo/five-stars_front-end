import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Configuration API centralisée.
/// Utilise une valeur par défaut adaptée à la plateforme.
class ApiConfig {
  static String get baseUrl {
    // Permet de surcharger via --dart-define
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Web utilise localhost directement
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // Détection automatique selon la plateforme native
    if (defaultTargetPlatform == TargetPlatform.android) {
      // L'émulateur Android mappe 10.0.2.2 vers localhost de l'hôte
      return 'http://10.0.2.2:8000';
    } else {
      // iOS Simulator, macOS, Linux, Windows
      return 'http://127.0.0.1:8000';
    }
  }
}
