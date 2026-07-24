import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('l\'onglet Comptabilité s\'affiche sans erreur', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));

    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ajouter une dépense'), findsOneWidget);
    expect(find.text('Bénéfice par facture'), findsOneWidget);
    expect(find.text('Bilan mensuel'), findsOneWidget);
  });

  testWidgets('l\'onglet Dîme recalculé s\'affiche et propose un versement', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Dîme'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DÎME TOTALE (10%)'), findsOneWidget);
    expect(find.byTooltip('Marquer versée'), findsWidgets);
  });
}
