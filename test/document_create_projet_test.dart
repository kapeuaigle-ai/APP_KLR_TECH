import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('le sélecteur de projet propose les projets du client', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addClient(const Client(
        id: 5, initials: 'AC', color: Colors.blue, name: 'ACME',
        contact: 'Jean', email: 'j@acme.cm', phone: '600', totalFacture: 0));
    state.addProjet(Projet(
        id: 1, nom: 'Fourniture matériel', typeId: 'fourniture',
        clientId: 5, client: 'ACME',
        debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    state.setDocType('proforma');

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PROJET'), findsOneWidget);
  });

  testWidgets('sans projet enregistré, le sélecteur reste absent', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.setDocType('proforma');

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PROJET'), findsNothing);
  });
}
