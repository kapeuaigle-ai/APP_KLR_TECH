import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/main.dart';
import 'package:klr_tech_app/core/app_state.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const KlrTechApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
