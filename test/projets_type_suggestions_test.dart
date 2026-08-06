import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// Le registre de types a disparu : plus rien à choisir dedans, plus rien à
/// maintenir. Le champ TYPE de la boîte « Nouveau projet » est un texte
/// libre ; les suggestions affichées dessous viennent des projets déjà
/// enregistrés (`AppState.suggestionsTypeProjet`), jamais d'une liste à part.
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

  Projet p(int id, String nom, String type) => Projet(
        id: id, nom: nom, type: type, mode: ModeAvancement.quantites,
        clientId: null, client: '',
        debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      );

  testWidgets('sans aucun projet enregistré, aucune suggestion ne s\'affiche', (tester) async {
    await pump(tester, AppState()..viderDonnees());
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fourniture de matériel'), findsNothing);
  });

  testWidgets('les types déjà utilisés par des projets apparaissent en suggestions', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(p(1, 'Projet A', 'Fourniture de matériel'));
    state.addProjet(p(2, 'Projet B', 'Voyage employés'));
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.text('Fourniture de matériel'), findsOneWidget);
    expect(find.text('Voyage employés'), findsOneWidget);
  });

  testWidgets('un type utilisé par plusieurs projets n\'apparaît qu\'une fois', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(p(1, 'Projet A', 'Fourniture de matériel'));
    state.addProjet(p(2, 'Projet B', 'Fourniture de matériel'));
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.text('Fourniture de matériel'), findsOneWidget);
  });

  testWidgets('taper une suggestion remplit le champ TYPE', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(p(1, 'Projet A', 'Fourniture de matériel'));
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Projet C');
    await tester.tap(find.text('Fourniture de matériel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(state.projets.first.type, 'Fourniture de matériel');
  });

  testWidgets('taper une valeur entièrement nouvelle reste possible', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(p(1, 'Projet A', 'Fourniture de matériel'));
    await pump(tester, state);

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Projet neuf');
    // Le champ TYPE est le second TextField de la boîte (le premier est NOM
    // DU PROJET) : aucune suggestion n'est tapée, une étiquette inédite est
    // saisie directement.
    await tester.enterText(find.byType(TextField).at(1), 'Formation employés');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.projets.first.type, 'Formation employés');
  });
}
