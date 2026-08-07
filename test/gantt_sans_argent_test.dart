import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

/// Un projet interne (aucun engagement entrant rattaché) a un
/// `montantAttendu` de 0 — `Avancement.financier` reste alors bloqué à 0
/// pour toujours. Avant ce correctif, le Gantt dessinait quand même sa barre
/// « Encaissé » à 0 %, qui se lit comme « un paiement est attendu et rien
/// n'est arrivé » — faux pour un projet où rien n'a jamais été dû (défaut 2,
/// revue finitions).
Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
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

  testWidgets('un projet sans aucun engagement n\'affiche que la barre Réalisé',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Aménagement bureau',
      type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await _pump(tester, s);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('barre-physique-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('barre-financiere-1')), findsNothing);
  });

  testWidgets(
      'un projet avec un engagement mais rien encaissé garde ses deux barres, la financière à 0 %',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Prestation ACME',
      type: 'Projet interne', mode: ModeAvancement.manuel, clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    s.addEngagement(Engagement(
      id: 9, sens: 'entrant', tiers: 'ACME', montant: 1000,
      echeance: DateTime(2026, 6, 30), projetId: 1));

    await _pump(tester, s);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('barre-physique-1')), findsOneWidget);
    // Une créance réelle, pas encore réglée : cacher cette barre dissimulerait
    // une information réelle (§ distinction à ne pas manquer, revue finitions).
    expect(find.byKey(const ValueKey('barre-financiere-1')), findsOneWidget);
    final tooltip = tester.widget<Tooltip>(find.byKey(const ValueKey('barre-financiere-1')));
    expect(tooltip.message, contains('Encaissé — 0 %'));
  });

  testWidgets('la légende du Gantt reste exacte pour les projets sans argent',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Aménagement bureau',
      type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await _pump(tester, s);

    // La légende ne doit plus affirmer sans condition qu'une barre claire
    // « encaissé » existe pour chaque ligne — certains projets n'en ont pas.
    expect(find.textContaining('encaissé (si une rentrée est attendue)'), findsOneWidget);
  });
}
