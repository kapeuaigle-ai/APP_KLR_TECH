import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

// Point mineur de la revue finale de Phase 3 : `modeDuProjet` retombe sur
// `quantites` quand le `typeId` d'un projet ne correspond plus à aucun type
// (restauration d'une sauvegarde plus ancienne, par exemple) — mais rien ne
// le disait au manager dans la fiche projet.
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

  testWidgets('un type disparu affiche un indice dans la fiche', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Vieux projet', typeId: 'type_disparu',
      clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    ));
    await pump(tester, state);

    await tester.tap(find.text('Vieux projet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('type de ce projet n\'existe plus'), findsOneWidget);
    expect(find.textContaining('quantités livrées'), findsOneWidget);
  });

  testWidgets('un type existant n\'affiche aucun indice', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', typeId: 'fourniture',
      clientId: null, client: '',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    ));
    await pump(tester, state);

    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();

    expect(find.textContaining('type de ce projet n\'existe plus'), findsNothing);
  });
}
