import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('la boîte « Nouveau projet » propose les types paramétrés', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('Fourniture de matériel'), findsWidgets);
  });

  testWidgets('le mode du type choisi est expliqué dans la boîte', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pondérées par le montant'), findsOneWidget);
  });
}
