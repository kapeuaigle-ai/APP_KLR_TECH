import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('un engagement partiellement réglé affiche son reste', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addEngagement(Engagement(
      id: 1, sens: 'entrant', tiers: 'ACME', montant: 1000,
      echeance: DateTime(2026, 6, 30), description: 'Fourniture',
    ));
    state.ajouterReglement(1, 400, DateTime(2026, 3, 3));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('600'), findsWidgets, reason: 'le reste dû');
  });

  testWidgets('l\'onglet Comptabilité s\'affiche sans Expense', (tester) async {
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
    expect(find.text('Bénéfice par facture'), findsOneWidget);
  });
}
