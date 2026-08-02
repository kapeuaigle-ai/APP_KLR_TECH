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

  // Défaut 2 : une proforma validée a déjà produit une facture, un BL et un
  // engagement rattachés à SON projet. Rouvrir sa fiche et la réassigner à
  // un autre projet déconnecterait silencieusement l'argent du physique.
  group('proforma validée — projet figé', () {
    AppState stateAvecDeuxProjets() {
      final state = AppState()..viderDonnees();
      state.addClient(const Client(
          id: 5, initials: 'AC', color: Colors.blue, name: 'ACME',
          contact: 'Jean', email: 'j@acme.cm', phone: '600', totalFacture: 0));
      state.addProjet(Projet(
          id: 1, nom: 'Projet A', typeId: 'fourniture',
          clientId: 5, client: 'ACME',
          debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
      state.addProjet(Projet(
          id: 2, nom: 'Projet B', typeId: 'fourniture',
          clientId: 5, client: 'ACME',
          debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
      return state;
    }

    DocumentItem proformaValidee({int projetId = 1}) => DocumentItem(
        id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 1000, statut: 'validee',
        projetId: projetId,
        lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 1000)]);

    testWidgets('le sélecteur de projet est désactivé', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = stateAvecDeuxProjets();
      final doc = proformaValidee();
      state.addDocument('proforma', doc);
      state.startEditProforma(doc);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
      ));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<int?>>(
          find.byType(DropdownButtonFormField<int?>));
      expect(dropdown.onChanged, isNull,
          reason: 'le projet d\'une proforma validée ne doit pas être modifiable');
      // Le nom du projet en cours reste visible.
      expect(find.text('Projet A'), findsOneWidget);
    });

    testWidgets('enregistrer une proforma validée conserve son statut et son projet',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = stateAvecDeuxProjets();
      final doc = proformaValidee();
      state.addDocument('proforma', doc);
      state.startEditProforma(doc);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer').first);
      await tester.pumpAndSettle();

      final saved = state.documents['proforma']!.firstWhere((d) => d.id == 900);
      expect(saved.statut, 'validee');
      expect(saved.projetId, 1);
    });

    testWidgets('une proforma non validée reste librement modifiable, projet compris',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = stateAvecDeuxProjets();
      final doc = DocumentItem(
          id: 901, numero: 'KLR-P02-25072026', date: '25/07/2026', clientId: 5,
          client: 'ACME', objet: 'PC', montant: 1000, statut: 'cours',
          projetId: 1,
          lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 1000)]);
      state.addDocument('proforma', doc);
      state.startEditProforma(doc);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: Scaffold(body: DocumentCreateScreen(existing: doc))),
      ));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<int?>>(
          find.byType(DropdownButtonFormField<int?>));
      expect(dropdown.onChanged, isNotNull);

      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projet B').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer').first);
      await tester.pumpAndSettle();

      final saved = state.documents['proforma']!.firstWhere((d) => d.id == 901);
      expect(saved.statut, 'cours');
      expect(saved.projetId, 2);
    });
  });
}
