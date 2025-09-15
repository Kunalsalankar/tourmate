// Tourmate App Widget Tests
//
// This file contains basic widget tests for the Tourmate travel management app.

import 'package:flutter_test/flutter_test.dart';

import 'package:tourmate/app/app.dart';

void main() {
  testWidgets('Tourmate app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts with splash screen
    expect(find.text('Tourmate'), findsOneWidget);
    expect(find.text('Your Ultimate Travel Companion'), findsOneWidget);
  });
}
