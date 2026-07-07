import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chat_app/src/screens/login_screen.dart';
import 'package:ai_chat_app/src/services/api_client.dart';
import 'package:ai_chat_app/src/services/auth_service.dart';

void main() {
  testWidgets('login screen shows Google sign-in action', (tester) async {
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(apiClient: apiClient, authService: authService),
      ),
    );

    expect(find.text('Lanjut dengan Google'), findsOneWidget);
  });
}
