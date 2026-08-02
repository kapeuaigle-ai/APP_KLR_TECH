import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/rapports_screen.dart';
import 'support/test_fonts.dart';

/// Défaut n°2 : l'onglet « Projets » de Rapports affichait une liste
/// `static final` de projets inventés (« Dashboard Analytics v2 », etc.),
/// avec pourcentages et initiales d'équipe fictifs. Des projets réels
/// existent depuis la phase 2 : la liste doit s'appuyer sur
/// `AppState.avancementProjet`, comme le Kanban et le Gantt.
void main() {
  setUpAll(loadTestFonts);

  Future<void> pumpRapportsProjets(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: RapportsScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projets'));
    await tester.pumpAndSettle();
  }

  testWidgets('les projets factices ont disparu de l\'onglet Projets', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
        id: 1, nom: 'Fourniture ACME', typeId: 'fourniture', clientId: 5,
        client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await pumpRapportsProjets(tester, state);

    expect(find.text('Dashboard Analytics v2'), findsNothing);
    expect(find.text('Migration cloud AWS'), findsNothing);
    expect(find.text('Module CRM clients'), findsNothing);
    expect(find.textContaining('AB, AK'), findsNothing, reason: 'plus d\'initiales d\'équipe');
  });

  testWidgets('un vrai projet apparaît avec son statut dérivé', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
        id: 1, nom: 'Fourniture ACME', typeId: 'fourniture', clientId: 5,
        client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await pumpRapportsProjets(tester, state);

    expect(find.text('Fourniture ACME'), findsOneWidget);
    // Rien livré, rien encaissé : statut « À démarrer » (voir avancement.dart).
    expect(find.text('À démarrer'), findsOneWidget);
  });

  testWidgets('un projet annulé n\'apparaît pas dans la liste', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
        id: 1, nom: 'Projet abandonné', typeId: 'fourniture', clientId: 5,
        client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
        annule: true));

    await pumpRapportsProjets(tester, state);

    expect(find.text('Projet abandonné'), findsNothing);
  });

  testWidgets('sans aucun projet, un état vide s\'affiche', (tester) async {
    final state = AppState()..viderDonnees();

    await pumpRapportsProjets(tester, state);

    expect(tester.takeException(), isNull);
    expect(find.text('Aucun projet enregistré.'), findsOneWidget);
  });
}
