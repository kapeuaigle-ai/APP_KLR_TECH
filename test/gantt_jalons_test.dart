import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les jalons d\'un projet apparaissent en repères sur sa barre', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Câblage siège', typeId: 'installation', clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      jalons: [
        Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 20), realisee: DateTime(2026, 3, 22), poids: 1),
        Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3),
      ]));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: GanttScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('jalon-1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('jalon-1-1')), findsOneWidget);
  });

  testWidgets('un projet en mode quantites n\'affiche aucun repère de jalon', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture', typeId: 'fourniture', clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: GanttScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('jalon-1-0')), findsNothing);
  });
}
