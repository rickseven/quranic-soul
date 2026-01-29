import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quranic_soul/main.dart';

void main() {
  testWidgets('Quranic Soul app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QuranicSoulApp());

    // Verify home page elements are present
    expect(find.text('Listening now:'), findsOneWidget);
    expect(find.text('Suggestions:'), findsOneWidget);
    expect(find.text('Categories:'), findsOneWidget);

    // Verify bottom navigation exists
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
