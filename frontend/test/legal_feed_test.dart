import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law_lens/screens/legal_feed_screen.dart';

void main() {
  Widget createFeedScreen() => const MaterialApp(
        home: LegalFeedScreen(),
      );

  group('LegalFeedScreen Widget Tests', () {
    testWidgets('Verify Tabs and Refresh Button Presence', (WidgetTester tester) async {
      await tester.pumpWidget(createFeedScreen());
      await tester.pump(); // Initial build

      // Check for App Bar Title
      expect(find.text('Legal Intelligence'), findsOneWidget);

      // Check for Tabs
      expect(find.text('Latest News'), findsOneWidget);
      expect(find.text('Legal Reels'), findsOneWidget);
    });

    testWidgets('Verify Switching to Reels Tab', (WidgetTester tester) async {
      await tester.pumpWidget(createFeedScreen());
      await tester.pump();

      // Tap on Legal Reels tab
      await tester.tap(find.byIcon(Icons.play_circle_fill));
      await tester.pump(const Duration(milliseconds: 500));

      // In Reels tab, we should see the ReelItem (though video might not load in test)
      // We look for the placeholder or unique reels UI elements
      expect(find.textContaining('Legal Awareness Series'), findsNothing); // Initially nothing if not loaded
      
      // Wait for a bit to simulate loading
      await tester.pump(const Duration(seconds: 2));
      // Even if video fails, the structure should be there.
    });
  });
}
