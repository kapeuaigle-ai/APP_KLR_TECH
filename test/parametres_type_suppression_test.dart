import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/parametres_screen.dart';
import 'support/test_fonts.dart';

// Défaut 2 de la revue finale de Phase 3 : supprimer un type rebasculait
// silencieusement ses projets sur le premier type restant — ce qui change
// aussi leur mode d'avancement, donc leur pourcentage affiché et leur
// colonne Kanban — sans jamais prévenir le manager.
Projet _p(int id, String typeId) => Projet(
      id: id, nom: 'P$id', typeId: typeId, clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
    ));
    await tester.pumpAndSettle();
  }

  group('suppression d\'un type', () {
    testWidgets('demande confirmation et nomme le nombre de projets affectés',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      state.addProjet(_p(2, 'installation'));
      await pump(tester, state);

      // Les types par défaut sont dans l'ordre : fourniture, installation,
      // maintenance, interne — le deuxième bouton « Supprimer » est celui
      // d'« Installation / déploiement ».
      await tester.tap(find.byTooltip('Supprimer').at(1));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce type ?'), findsOneWidget);
      expect(find.textContaining('2 projets'), findsOneWidget);
      expect(find.textContaining('Fourniture de matériel'), findsWidgets);
      // Rien n'a encore changé : la confirmation n'a pas été donnée.
      expect(state.settings.typesProjet.map((t) => t.id), contains('installation'));
      expect(state.projets.every((p) => p.typeId == 'installation'), isTrue);
    });

    testWidgets('annuler ne change rien', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      await pump(tester, state);

      await tester.tap(find.byTooltip('Supprimer').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(state.settings.typesProjet.map((t) => t.id), contains('installation'));
      expect(state.projets.first.typeId, 'installation');
    });

    testWidgets('confirmer réassigne les projets sur le type de repli',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      await pump(tester, state);

      await tester.tap(find.byTooltip('Supprimer').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(state.settings.typesProjet.map((t) => t.id), isNot(contains('installation')));
      expect(state.projets.first.typeId, 'fourniture');
    });

    testWidgets('sans projet concerné, le dialogue reste simple', (tester) async {
      final state = AppState()..viderDonnees();
      // Aucun projet n'utilise « Maintenance / contrat » (index 2).
      await pump(tester, state);

      await tester.tap(find.byTooltip('Supprimer').at(2));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce type ?'), findsOneWidget);
      expect(find.textContaining('aucun projet'), findsOneWidget);
    });
  });
}
