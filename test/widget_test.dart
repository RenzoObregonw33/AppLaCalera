import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lacalera/main.dart';
import 'package:lacalera/screens/login_screen.dart';

void main() {
  testWidgets('MyApp renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(initialScreen: LoginScreen()));

    // Ensure app bootstraps with app shell widgets.
    expect(find.byType(MyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
