import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/theme.dart';
import 'package:klr_tech_app/screens/parametres_screen.dart';
import 'support/test_fonts.dart';

// Défaut 3 de la revue finale de Phase 3 : éditer un type et changer son
// mode d'avancement recalculait instantanément le pourcentage et la colonne
// Kanban de tous ses projets, sans confirmation ni test — même ampleur que
// la suppression (défaut 2), mais aucune cérémonie.
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

  // Deux `AlertDialog` peuvent être empilés (édition du type, puis
  // confirmation du changement de mode par-dessus) : `find.text('Annuler')`
  // seul serait ambigu. On cible le dialogue qui contient son propre titre.
  Finder dansLeDialogue(String titre, Finder cible) => find.descendant(
      of: find.ancestor(of: find.text(titre), matching: find.byType(AlertDialog)),
      matching: cible);

  group('changement du mode d\'avancement d\'un type', () {
    testWidgets('changer uniquement la couleur applique sans dialogue',
        (tester) async {
      final state = AppState()..viderDonnees();
      await pump(tester, state);

      await tester.tap(find.byTooltip('Modifier').at(1)); // Installation
      await tester.pumpAndSettle();
      expect(find.text('Modifier le type'), findsOneWidget);

      // La pastille de couleur du type « Fourniture de matériel » dans la
      // liste en arrière-plan est aussi bleue (0xFF2563EB) : on distingue la
      // nuance du formulaire par sa taille (28×28, contre 12×12 la pastille).
      await tester.tap(find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == AppColors.blue &&
          w.constraints?.maxWidth == 28));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Enregistrer')));
      await tester.pumpAndSettle();

      expect(find.text('Modifier le type'), findsNothing);
      expect(find.text('Changer le mode d\'avancement ?'), findsNothing);
      final t = state.settings.typesProjet.firstWhere((t) => t.id == 'installation');
      expect(t.mode, ModeAvancement.jalons);
      expect(t.couleur, AppColors.blue);
    });

    testWidgets('changer le mode déclenche une confirmation', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      await pump(tester, state);

      await tester.tap(find.byTooltip('Modifier').at(1)); // Installation, mode jalons
      await tester.pumpAndSettle();

      await tester.tap(dansLeDialogue('Modifier le type', find.text('Durée écoulée')));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Enregistrer')));
      await tester.pumpAndSettle();

      expect(find.text('Changer le mode d\'avancement ?'), findsOneWidget);
      expect(find.textContaining('Jalons'), findsWidgets);
      expect(find.textContaining('Durée écoulée'), findsWidgets);
      // Toujours l'ancien mode tant que rien n'est confirmé.
      final t = state.settings.typesProjet.firstWhere((t) => t.id == 'installation');
      expect(t.mode, ModeAvancement.jalons);
    });

    testWidgets('annuler la confirmation laisse l\'ancien mode', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      await pump(tester, state);

      await tester.tap(find.byTooltip('Modifier').at(1));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Durée écoulée')));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Enregistrer')));
      await tester.pumpAndSettle();

      await tester.tap(dansLeDialogue('Changer le mode d\'avancement ?', find.text('Annuler')));
      await tester.pumpAndSettle();

      final t = state.settings.typesProjet.firstWhere((t) => t.id == 'installation');
      expect(t.mode, ModeAvancement.jalons);
    });

    testWidgets('confirmer applique le nouveau mode', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(1, 'installation'));
      await pump(tester, state);

      await tester.tap(find.byTooltip('Modifier').at(1));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Durée écoulée')));
      await tester.pumpAndSettle();
      await tester.tap(dansLeDialogue('Modifier le type', find.text('Enregistrer')));
      await tester.pumpAndSettle();

      await tester.tap(dansLeDialogue('Changer le mode d\'avancement ?', find.text('Confirmer')));
      await tester.pumpAndSettle();

      final t = state.settings.typesProjet.firstWhere((t) => t.id == 'installation');
      expect(t.mode, ModeAvancement.duree);
      expect(find.text('Modifier le type'), findsNothing);
    });
  });
}
