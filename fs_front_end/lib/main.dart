import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/fields_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/teams_provider.dart';
import 'providers/theme_provider.dart';

// Démarre l'application Flutter
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les données de localisation pour le formatage des dates
  await initializeDateFormatting('fr_FR', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => TeamsProvider()),
        ChangeNotifierProvider(create: (_) => FieldsProvider()),
      ],
      child: FootApp(),
    ),
  );
}
