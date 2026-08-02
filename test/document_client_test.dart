import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'support/test_fonts.dart';

/// Défaut n°1 : `document_create_screen.dart` écrivait `clientId: 0` en dur à
/// l'enregistrement, quel que soit le client choisi dans l'autocomplete.
/// Survivable tant que `clientId` n'était que décoratif (l'affichage se fait
/// sur `client`, le nom) ; devenu conséquent depuis que `validateProforma`
/// propage `clientId` à l'engagement entrant de la facture.
void main() {
  setUpAll(loadTestFonts);

  Future<void> pumpEcran(WidgetTester tester, AppState state, {DocumentItem? existing}) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: existing))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'sélectionner un client dans l\'autocomplete puis enregistrer '
      'sauvegarde son id réel, pas 0', (tester) async {
    final state = AppState()..viderDonnees();
    state.addClient(const Client(
        id: 42, initials: 'AC', color: Colors.blue, name: 'ACME Fournitures',
        contact: 'Jean', email: 'j@acme.ci', phone: '600', totalFacture: 0));
    state.setDocType('proforma');

    await pumpEcran(tester, state);

    // Tape un préfixe distinctif pour ouvrir l'autocomplete, puis choisit
    // l'unique suggestion.
    await tester.enterText(find.byType(TextField).first, 'ACME Four');
    await tester.pumpAndSettle();
    expect(find.text('ACME Fournitures'), findsOneWidget,
        reason: 'la suggestion doit apparaître avant sélection');
    await tester.tap(find.text('ACME Fournitures'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final doc = state.documents['proforma']!.single;
    expect(doc.clientId, 42, reason: 'clientId doit suivre le client choisi, pas rester à 0');
    expect(doc.client, 'ACME Fournitures');
  });

  testWidgets(
      'rouvrir une proforma existante pour modification puis enregistrer '
      'conserve son clientId', (tester) async {
    final state = AppState()..viderDonnees();
    final existante = DocumentItem(
      id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026',
      clientId: 77, client: 'Client existant', objet: 'Objet initial',
      montant: 1000, statut: 'cours',
      lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 1000)],
    );
    state.addDocument('proforma', existante);

    await pumpEcran(tester, state, existing: existante);

    // Aucune modification du client : juste ré-enregistrer.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final doc = state.documents['proforma']!.singleWhere((d) => d.id == 900);
    expect(doc.clientId, 77, reason: 'l\'édition ne doit pas réinitialiser le clientId à 0');
  });

  testWidgets(
      'valider une proforma créée via l\'écran produit un engagement entrant '
      'portant le même clientId', (tester) async {
    final state = AppState()..viderDonnees();
    state.addClient(const Client(
        id: 15, initials: 'BT', color: Colors.teal, name: 'Beta Tech',
        contact: 'Awa', email: 'awa@beta.ci', phone: '601', totalFacture: 0));
    state.setDocType('proforma');

    await pumpEcran(tester, state);

    await tester.enterText(find.byType(TextField).first, 'Beta Te');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta Tech'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Enregistrer'));
    await tester.pumpAndSettle();

    final proforma = state.documents['proforma']!.single;
    state.validateProforma(proforma.id);

    final engagement = state.engagements.firstWhere((e) => e.estEntrant);
    expect(engagement.clientId, 15);
  });
}
