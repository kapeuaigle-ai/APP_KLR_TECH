import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/documents_list_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  Widget host(AppState state) => ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DocumentsListScreen())),
      );

  testWidgets('les compteurs sont dans les filtres, plus dans des cartes', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(AppState()));
    await tester.pumpAndSettle();

    // Les petites cartes VALIDÉS / EN COURS ont disparu.
    expect(find.text('VALIDÉS'), findsNothing);
    expect(find.text('EN COURS'), findsNothing);

    // Échantillon : 1 en cours, 1 validée, 1 annulée (3 au total).
    expect(find.text('Tous (3)'), findsOneWidget);
    expect(find.text('En cours (1)'), findsOneWidget);
    expect(find.text('Validé (1)'), findsOneWidget);
    expect(find.text('Annulé (1)'), findsOneWidget);
  });

  testWidgets('un statut à 0 s\'affiche sans compteur', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    // Ne garder qu'une proforma en cours : plus de validée ni d'annulée.
    state.documents['proforma'] = [
      DocumentItem(id: 1, numero: 'KLR-01-240726', date: '24/07/2026', clientId: 0,
          client: 'C', objet: 'O', montant: 1000, statut: 'cours'),
    ];

    await tester.pumpWidget(host(state));
    await tester.pumpAndSettle();

    expect(find.text('Tous (1)'), findsOneWidget);
    expect(find.text('En cours (1)'), findsOneWidget);
    // Compteur nul masqué : le libellé reste nu.
    expect(find.text('Validé'), findsOneWidget);
    expect(find.text('Annulé'), findsOneWidget);
    expect(find.text('Validé (0)'), findsNothing);
    expect(find.text('Annulé (0)'), findsNothing);
  });
}
