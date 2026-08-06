import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// La boîte « Nouveau projet » n'a plus de registre de types à proposer : le
/// type est une étiquette libre, et le mode d'avancement se choisit à part,
/// par une puce dédiée. `quantites` est le cas le plus courant du métier :
/// c'est le mode sélectionné par défaut, avant toute saisie.
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

  testWidgets('la boîte « Nouveau projet » propose un champ TYPE libre et un sélecteur de mode',
      (tester) async {
    await pump(tester, AppState()..viderDonnees());

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('MODE D\'AVANCEMENT'), findsOneWidget);
    // Les quatre modes, jamais un registre de métiers figé dans le code.
    expect(find.text('Quantités livrées'), findsOneWidget);
    expect(find.text('Jalons'), findsOneWidget);
    expect(find.text('Durée écoulée'), findsOneWidget);
    expect(find.text('Saisie manuelle'), findsOneWidget);
  });

  testWidgets('le mode « Quantités livrées » est sélectionné par défaut, avec son explication',
      (tester) async {
    await pump(tester, AppState()..viderDonnees());
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pondérées par le montant'), findsOneWidget);
  });

  testWidgets('choisir un autre mode change l\'explication affichée', (tester) async {
    await pump(tester, AppState()..viderDonnees());
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Durée écoulée'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pondérées par le montant'), findsNothing);
    expect(find.textContaining('suit le calendrier'), findsOneWidget);
  });
}
