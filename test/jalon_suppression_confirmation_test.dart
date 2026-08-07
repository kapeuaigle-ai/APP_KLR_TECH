import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

// Lot G (hygiène) : supprimer un jalon n'affichait aucune confirmation,
// contrairement à toute autre action destructrice de l'app (règlement,
// engagement, client, projet). Cérémonie allégée — un jalon n'est qu'un
// repère d'avancement, pas de l'argent — mais confirmation quand même.
void main() {
  setUpAll(loadTestFonts);

  Projet projetAJalons() => Projet(
        id: 1, nom: 'Câblage Riviera', type: 'Fourniture de matériel',
        mode: ModeAvancement.jalons, clientId: 5, client: 'ACME',
        debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
        jalons: [Jalon(nom: 'Livraison matériel', prevue: DateTime(2026, 4, 1), poids: 1)],
      );

  Future<AppState> ouvrirFiche(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final state = AppState()..viderDonnees();
    state.addProjet(projetAJalons());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Câblage Riviera'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('supprimer un jalon demande confirmation et ne supprime rien à l\'annulation',
      (tester) async {
    final state = await ouvrirFiche(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ce jalon ?'), findsOneWidget);
    expect(state.projets.first.jalons, hasLength(1)); // rien tant que non confirmé

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ce jalon ?'), findsNothing);
    expect(state.projets.first.jalons, hasLength(1));
  });

  testWidgets('confirmer supprime bien le jalon', (tester) async {
    final state = await ouvrirFiche(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    // Le bouton « Supprimer » du dialogue, pas celui (absent ici) du menu
    // d'actions du projet — un seul candidat dans cette fiche en mode jalons.
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('Supprimer ce jalon ?'), findsNothing);
    expect(state.projets.first.jalons, isEmpty);
  });
}
