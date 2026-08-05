import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
  ));
  await tester.pumpAndSettle();
}

AppState _avecProjet({int qteLivree = 0, double encaisse = 0}) {
  final s = AppState()..viderDonnees();
  s.addProjet(Projet(
    id: 1, nom: 'Fourniture ACME', typeId: 'fourniture', clientId: 5,
    client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
  s.saveOrUpdateProforma(DocumentItem(
    id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
    client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
    lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: qteLivree)]));
  s.validateProforma(1);
  if (encaisse > 0) s.ajouterReglement(s.engagements.first.id, encaisse, DateTime(2026, 4, 1));
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les cartes factices ont disparu', (tester) async {
    await _pump(tester, AppState()..viderDonnees());
    expect(find.text('Refonte interface mobile'), findsNothing);
    expect(find.text('Migration cloud AWS'), findsNothing);
  });

  testWidgets('un projet sans rien livré ni encaissé va dans « À démarrer »', (tester) async {
    await _pump(tester, _avecProjet());
    expect(tester.takeException(), isNull);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Fourniture ACME'), findsOneWidget);
  });

  testWidgets('tout livré, rien encaissé : colonne « En révision »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10));
    expect(find.text('En révision'), findsWidgets);
  });

  testWidgets('tout livré et tout encaissé : colonne « Terminé »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10, encaisse: 3000));
    expect(find.text('Terminé'), findsWidgets);
  });

  testWidgets('les cartes ne sont plus déplaçables', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 5));
    expect(find.byType(Draggable), findsNothing,
        reason: 'la colonne est deduite : la deplacer a la main n\'aurait aucun sens');
  });

  // Le mot « Livré » ne parlait que de fourniture ; la barre physique est
  // commune aux quatre modes d'avancement (quantités, jalons, durée,
  // manuel), d'où le renommage en « Réalisé ». « Encaissé » reste inchangé :
  // l'argent est de l'argent, quel que soit le type de projet.
  testWidgets('la fiche projet affiche les libellés « Réalisé » et « Encaissé »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 5, encaisse: 900));
    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    expect(find.text('Réalisé'), findsWidgets);
    expect(find.text('Encaissé'), findsWidgets);
    expect(find.text('Livré'), findsNothing);
  });

  // ── Badge « Échéance atteinte » ──────────────────────────
  // Rien livré, rien encaissé, mais l'échéance est passée : le projet reste
  // en « À démarrer » (règle 3 avant règle 4) — le badge est le seul rappel
  // qu'il reste au manager.
  testWidgets('à démarrer, échéance passée : le badge « Échéance atteinte » apparaît', (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Idée jamais lancée', typeId: 'interne', clientId: null,
      client: '', debut: DateTime(2020, 1, 1), finPrevue: DateTime(2020, 6, 30)));
    await _pump(tester, s);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Échéance atteinte'), findsOneWidget);
  });

  testWidgets('à démarrer, échéance PAS passée : pas de badge', (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Projet futur', typeId: 'interne', clientId: null,
      client: '', debut: DateTime(2030, 1, 1), finPrevue: DateTime(2030, 6, 30)));
    await _pump(tester, s);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Échéance atteinte'), findsNothing);
  });

  testWidgets('« En révision » ne porte pas le badge : le statut est déjà le signal', (tester) async {
    // Livré et échéance dépassée (finPrevue par défaut le 30 juin 2026, bien
    // avant la date système réelle) : la carte tombe en « En révision », pas
    // « À démarrer », et ne doit donc jamais porter le badge.
    await _pump(tester, _avecProjet(qteLivree: 10));
    expect(find.text('En révision'), findsWidgets);
    expect(find.text('Échéance atteinte'), findsNothing);
  });
}
