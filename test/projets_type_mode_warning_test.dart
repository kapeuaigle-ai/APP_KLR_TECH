import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

// Défaut 4 de la revue finale de Phase 3 : le mode d'avancement d'un projet
// existant pouvait changer d'un tap, sans avertissement. Le registre de
// types a disparu (§ type-libre) : le mode se choisit maintenant par une
// puce dédiée (MODE D'AVANCEMENT), plus via un type qui l'impliquait — mais
// l'avertissement doit survivre, comparant `mode` directement.
void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('choisir un mode différent affiche un avertissement',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    ));
    await pump(tester, state);

    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le projet'), findsOneWidget);

    // Bascule sur la puce « Jalons », mode différent du mode enregistré.
    await tester.tap(find.text('Jalons'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quantités livrées'), findsWidgets);
    expect(find.textContaining('Jalons'), findsWidgets);
    // Le projet n'est pas modifié tant que rien n'est enregistré.
    expect(state.projets.first.mode, ModeAvancement.quantites);
  });

  testWidgets('choisir le même mode n\'affiche aucun avertissement', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    ));
    await pump(tester, state);

    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();

    // Retape le même mode, déjà sélectionné.
    await tester.tap(find.text('Quantités livrées'));
    await tester.pumpAndSettle();

    expect(find.textContaining('mesuré différemment'), findsNothing);
    expect(find.textContaining('sera désormais mesuré'), findsNothing);
  });

  testWidgets('un nouveau projet n\'affiche jamais l\'avertissement', (tester) async {
    final state = AppState()..viderDonnees();
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jalons'));
    await tester.pumpAndSettle();

    expect(find.textContaining('sera désormais mesuré'), findsNothing);
  });
}
