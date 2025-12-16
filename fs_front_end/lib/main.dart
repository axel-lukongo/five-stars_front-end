import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/messages_provider.dart';
import 'providers/teams_provider.dart';
import 'providers/theme_provider.dart';

// Démarre l'application Flutter
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => MessagesProvider()),
        ChangeNotifierProvider(create: (_) => TeamsProvider()),
      ],
      child: FootApp(),
    ),
  );
}
