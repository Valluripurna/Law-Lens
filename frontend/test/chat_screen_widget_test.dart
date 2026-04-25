import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law_lens/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:law_lens/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'userId': 'test_user_123',
      'language': 'English',
    });
  });

  Widget createChatScreen() => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ChatScreen()),
        ),
      );

  group('ChatScreen Widget Tests', () {
    testWidgets('Verify Chat UI elements are present', (WidgetTester tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pump(); // Start building
      await tester.pump(const Duration(milliseconds: 500)); // Allow some time for init

      // Verify header text
      expect(find.text('AI Legal Assistant'), findsOneWidget);
      
      // Verify input field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ask your question here...'), findsOneWidget);

      // Verify Presence of Menu Button (The new 3-dot menu)
      expect(find.byIcon(Icons.more_vert), findsOneWidget);

      // Verify Presence of Voice Button
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      
      // Verify Send Button
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Verify Menu opens on tap', (WidgetTester tester) async {
      await tester.pumpWidget(createChatScreen());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the menu button
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check if menu items appear
      expect(find.text('New Chat'), findsOneWidget);
      expect(find.text('Vanish Mode'), findsOneWidget);
    });
  });
}
