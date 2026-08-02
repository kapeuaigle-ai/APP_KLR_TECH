import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: GanttScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('sans projet, le Gantt affiche un état vide, pas des données factices', (tester) async {
    await _pump(tester, AppState()..viderDonnees());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Aucun projet'), findsOneWidget);
    expect(find.text('Migration cloud AWS'), findsNothing,
        reason: 'les projets codes en dur doivent avoir disparu');
  });

  testWidgets('un projet enregistré apparaît avec son nom', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture matériel ACME', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await _pump(tester, state);
    expect(tester.takeException(), isNull);
    expect(find.text('Fourniture matériel ACME'), findsOneWidget);
  });

  testWidgets('les deux barres sont distinctes : livré et encaissé', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    state.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 8)]));
    state.validateProforma(1);
    state.ajouterReglement(state.engagements.first.id, 900, DateTime(2026, 4, 1));

    await _pump(tester, state);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('80'), findsWidgets, reason: '80 % livré');
    expect(find.textContaining('30'), findsWidgets, reason: '30 % encaissé');
  });

  testWidgets('un projet annulé n\'apparaît pas', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Abandonné', typeId: 'fourniture', clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30), annule: true));

    await _pump(tester, state);
    expect(find.text('Abandonné'), findsNothing);
  });
}
