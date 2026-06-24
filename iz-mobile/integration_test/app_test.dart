import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iz_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E App Flow Tests', () {
    testWidgets('App should launch and show Login Screen', (tester) async {
      // Build the app
      app.main();
      
      // Wait for app to render and navigation to settle
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Check if LoginScreen or email field is present
      expect(find.text('Giriş Yap'), findsWidgets);
      
      // Check if Email/Username text field exists
      expect(find.byType(TextFormField), findsWidgets);
    });

    // Note: A full E2E messaging test requires a mocked backend or a dedicated test DB environment.
    // We add a placeholder here for the actual messaging flow.
    testWidgets('Mocked Messaging Flow', (tester) async {
      // 1. Enter email & pass
      // 2. Tap Login
      // 3. Check for Home/Conversation list
      // 4. Tap a friend
      // 5. Send message
      // 6. Verify message appears in UI
    }, skip: true); // Skipped until backend test env is configured
  });
}
