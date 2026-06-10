// This is a basic Flutter widget test for the IzApp.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iz_mobile/features/auth/presentation/screens/login_screen.dart';

void main() {
  testWidgets('Login screen elements smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify that the login screen title, input labels and buttons exist in English (auto-detected).
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('End-to-end encrypted and completely traceless chat.'), findsOneWidget);
    expect(find.text('Username'), findsWidgets);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}

