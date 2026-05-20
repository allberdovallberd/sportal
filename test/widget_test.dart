import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportal/app/sportal_app.dart';

void main() {
  testWidgets('app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SportalApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
