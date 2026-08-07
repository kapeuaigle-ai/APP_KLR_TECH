import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'support/test_fonts.dart';

/// `DocumentCreateScreen` ne devrait plus jamais s'ouvrir sur une proforma
/// validée (voir documents_list_screen.dart, où « Modifier » explique le
/// verrou au lieu d'y naviguer). Ce fichier couvre malgré tout l'écran
/// directement — dernière ligne de défense (revue Lot D) — pour le cas où il
/// serait atteint par une autre voie que le bouton « Modifier ».
void main() {
  setUpAll(loadTestFonts);

  DocumentItem proformaValidee() => DocumentItem(
      id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 1000, statut: 'validee',
      lines: [LineItem(ref: '01', designation: 'Ordinateur', qte: 1, pu: 1000)]);

  testWidgets('affiche un bandeau expliquant le verrou, et désactive Enregistrer',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    final doc = proformaValidee();
    state.addDocument('proforma', doc);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('lecture seule'), findsOneWidget);

    final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    expect(btn.onPressed, isNull, reason: 'Enregistrer doit être désactivé');
  });

  testWidgets('les champs ne modifient plus le document sous-jacent : enregistrer '
      'ne change rien', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    final doc = proformaValidee();
    state.addDocument('proforma', doc);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
    ));
    await tester.pumpAndSettle();

    // Le champ CLIENT est visible mais figé (IgnorePointer) : une tentative
    // de saisie n'atteint pas le TextField.
    await tester.enterText(find.byType(TextField).first, 'CLIENT PIRATÉ');
    await tester.pumpAndSettle();

    // Le bouton Enregistrer étant désactivé, le taper ne fait rien —
    // vérifié malgré tout : ni exception, ni changement d'état.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final saved = state.documents['proforma']!.firstWhere((d) => d.id == 900);
    expect(saved.client, 'ACME');
    expect(saved.montant, 1000);
    expect(saved.statut, 'validee');
  });

  testWidgets('une proforma en cours reste pleinement modifiable (référence, non régressée)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    final doc = DocumentItem(
        id: 901, numero: 'KLR-P02-25072026', date: '25/07/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 1000, statut: 'cours',
        lines: [LineItem(ref: '01', designation: 'Ordinateur', qte: 1, pu: 1000)]);
    state.addDocument('proforma', doc);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('lecture seule'), findsNothing);
    final btn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    expect(btn.onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).first, 'ACME CORRIGÉ');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final saved = state.documents['proforma']!.firstWhere((d) => d.id == 901);
    expect(saved.client, 'ACME CORRIGÉ');
  });
}
