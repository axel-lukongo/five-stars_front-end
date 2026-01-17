import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:five_star_5v5/app.dart';
import 'package:five_star_5v5/providers/auth_provider.dart';
import 'package:five_star_5v5/providers/fields_provider.dart';
import 'package:five_star_5v5/providers/friends_provider.dart';
import 'package:five_star_5v5/providers/messages_provider.dart';
import 'package:five_star_5v5/providers/teams_provider.dart';
import 'package:five_star_5v5/providers/theme_provider.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => FriendsProvider()),
          ChangeNotifierProvider(create: (_) => MessagesProvider()),
          ChangeNotifierProvider(create: (_) => TeamsProvider()),
          ChangeNotifierProvider(create: (_) => FieldsProvider()),
        ],
        child: const FootApp(),
      ),
    );

    // Verify that the app loads without errors
    expect(find.byType(FootApp), findsOneWidget);
  });
}
