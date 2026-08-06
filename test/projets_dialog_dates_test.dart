import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

// Défaut 4 : la boîte « Nouveau projet » / « Modifier le projet » acceptait
// une fin prévue antérieure au début. La durée devenait négative et tout ce
// qui se construit sur la période (Gantt, retards) n'avait plus de sens.
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

  testWidgets(
      'reculer le début après la fin prévue refuse l\'enregistrement, avec un message',
      (tester) async {
    final state = AppState()..viderDonnees();
    // Même mois pour début et fin prévue : faire pointer le début après la
    // fin ne demande de choisir qu'un autre jour dans le calendrier déjà
    // ouvert sur ce mois-là, sans naviguer entre les mois.
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: null, client: '',
      debut: DateTime(2026, 6, 5), finPrevue: DateTime(2026, 6, 25),
    ));

    await pump(tester, state);

    // Ouvre la fiche projet, puis « Modifier ».
    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le projet'), findsOneWidget);

    // Ouvre le sélecteur de DÉBUT (calendrier centré sur juin 2026, puisque
    // le début actuel y est) et choisit le 28 — après la fin prévue (25).
    await tester.tap(find.text('05/06/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('28'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // Le dialogue reste ouvert, un message explique le refus, et le projet
    // n'a pas été modifié.
    expect(find.text('Modifier le projet'), findsOneWidget);
    expect(find.text('La fin prévue ne peut pas être antérieure au début.'),
        findsOneWidget);
    expect(state.projets.first.debut, DateTime(2026, 6, 5));
    expect(state.projets.first.finPrevue, DateTime(2026, 6, 25));
  });

  testWidgets('une fin prévue le même jour que le début est acceptée', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: null, client: '',
      debut: DateTime(2026, 6, 5), finPrevue: DateTime(2026, 6, 25),
    ));

    await pump(tester, state);

    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Modifier'));
    await tester.pumpAndSettle();

    // Ramène le début au même jour que la fin prévue (25 juin) : cas limite
    // valide, un projet peut durer un seul jour.
    await tester.tap(find.text('05/06/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le projet'), findsNothing);
    expect(state.projets.first.debut, DateTime(2026, 6, 25));
    expect(state.projets.first.finPrevue, DateTime(2026, 6, 25));
  });
}
