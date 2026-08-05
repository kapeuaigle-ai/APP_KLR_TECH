import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// Le manager crée un type sans quitter la boîte « Nouveau projet », faute
/// d'avoir trouvé Paramètres → TYPES DE PROJET. La puce « + Nouveau type »
/// ouvre le même formulaire que Paramètres (`ouvrirFormulaireType`, dans
/// widgets/type_projet_dialog.dart) et sélectionne le type créé.
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

  testWidgets('la boîte « Nouveau projet » propose une puce « + Nouveau type »', (tester) async {
    final state = AppState()..viderDonnees();
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.text('+ Nouveau type'), findsOneWidget);
  });

  testWidgets('la puce ouvre le formulaire de création de type de Paramètres', (tester) async {
    final state = AppState()..viderDonnees();
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Nouveau type'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ajouter un type'), findsOneWidget);
    expect(find.text('MODE D\'AVANCEMENT'), findsOneWidget);
    expect(find.text('COULEUR'), findsOneWidget);
  });

  testWidgets('créer un type depuis la puce l\'ajoute aux paramètres et le sélectionne '
      'pour le nouveau projet', (tester) async {
    final state = AppState()..viderDonnees();
    final avant = state.settings.typesProjet.length;
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Nouveau type'));
    await tester.pumpAndSettle();

    final dialogType = find.ancestor(
        of: find.text('Ajouter un type'), matching: find.byType(AlertDialog));
    final champLibelle = find.descendant(of: dialogType, matching: find.byType(TextField));
    await tester.enterText(champLibelle, 'Formation');
    await tester.tap(find.descendant(of: dialogType, matching: find.text('Ajouter')));
    await tester.pumpAndSettle();

    // Retour à la boîte « Nouveau projet » : plus d'exception, le type
    // vient d'être créé et son libellé apparaît maintenant parmi les
    // puces de type — sélectionné, sans action supplémentaire du manager.
    expect(tester.takeException(), isNull);
    expect(find.text('Ajouter un type'), findsNothing);
    expect(state.settings.typesProjet.length, avant + 1);
    expect(find.text('Formation'), findsOneWidget);

    // La sélection se vérifie de bout en bout : le projet créé juste après
    // porte bien le nouveau type, sans que le manager n'ait eu à re-cliquer
    // dessus.
    await tester.enterText(find.byType(TextField).first, 'Session de formation ACME');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(state.projets.last.typeId, 'formation');
  });
}
