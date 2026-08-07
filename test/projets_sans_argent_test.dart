import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// Un projet interne (aucun engagement entrant rattaché, `montantAttendu ==
/// 0`) n'a rien à encaisser : la carte Kanban et la fiche ne doivent plus
/// afficher la paire réalisé/encaissé ni les montants qui n'ont jamais été
/// dus, sous peine de montrer des chiffres qui ne veulent rien dire (défaut
/// 2, revue finitions). Un projet qui A une créance réelle, pas encore
/// réglée, doit lui garder sa barre à 0 % — c'est une vraie information, pas
/// un artefact.
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

void main() {
  setUpAll(loadTestFonts);

  group('carte Kanban', () {
    testWidgets('sans engagement : une seule ligne d\'avancement, pas de montants',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Aménagement bureau', type: 'Projet interne', mode: ModeAvancement.manuel,
        clientId: null, client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));

      await _pump(tester, s);

      expect(find.text('Réalisé'), findsOneWidget);
      expect(find.text('Encaissé'), findsNothing);
      expect(find.text('Attendu'), findsNothing);
      expect(find.text('Reste dû'), findsNothing);
    });

    testWidgets('avec un engagement non réglé : les deux lignes restent, la financière à 0 %',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Prestation ACME', type: 'Projet interne', mode: ModeAvancement.manuel,
        clientId: 5, client: 'ACME', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));
      s.addEngagement(Engagement(
        id: 9, sens: 'entrant', tiers: 'ACME', montant: 1000,
        echeance: DateTime(2026, 12, 31), projetId: 1));

      await _pump(tester, s);

      expect(find.text('Réalisé'), findsOneWidget);
      expect(find.text('Encaissé'), findsOneWidget);
      expect(find.text('Attendu'), findsOneWidget);
      expect(find.text('Reste dû'), findsOneWidget);
    });
  });

  group('fiche projet', () {
    testWidgets('sans engagement : une phrase plutôt que trois montants à zéro',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Aménagement bureau', type: 'Projet interne', mode: ModeAvancement.manuel,
        clientId: null, client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));

      await _pump(tester, s);
      await tester.tap(find.text('Aménagement bureau'));
      await tester.pumpAndSettle();

      expect(find.text('Encaissé'), findsNothing);
      expect(find.text('Montant attendu'), findsNothing);
      expect(find.text('Reste dû'), findsNothing);
      expect(find.textContaining('Aucun montant attendu'), findsOneWidget);
    });

    testWidgets('avec un engagement non réglé : la fiche garde ses montants, financière à 0 %',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Prestation ACME', type: 'Projet interne', mode: ModeAvancement.manuel,
        clientId: 5, client: 'ACME', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));
      s.addEngagement(Engagement(
        id: 9, sens: 'entrant', tiers: 'ACME', montant: 1000,
        echeance: DateTime(2026, 12, 31), projetId: 1));

      await _pump(tester, s);
      await tester.tap(find.text('Prestation ACME'));
      await tester.pumpAndSettle();

      // `findsWidgets` et non `findsOneWidget` : la carte Kanban reste
      // montée derrière la fiche ouverte en dialogue, et porte les mêmes
      // libellés « Encaissé » / « Reste dû » (même convention que le test
      // « la fiche projet affiche les libellés » de projets_kanban_test.dart).
      expect(find.text('Encaissé'), findsWidgets);
      expect(find.text('Reste dû'), findsWidgets);
      // « Montant attendu », en revanche, n'existe que sur la fiche.
      expect(find.text('Montant attendu'), findsOneWidget);
      expect(find.textContaining('Aucun montant attendu'), findsNothing);
    });
  });
}
