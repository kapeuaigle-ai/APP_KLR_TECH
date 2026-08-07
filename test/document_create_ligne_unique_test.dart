import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'support/test_fonts.dart';

// ── Défaut G2 (Lot G) ─────────────────────────────────────
// Une proforma doit garder au moins une ligne : `_removeLine` refuse déjà de
// vider la dernière (voir document_create_screen.dart), mais le bouton de
// suppression restait offert et actif quand même — un tap sans effet. Il doit
// désormais être réellement inerte (pas seulement grisé) sur la dernière
// ligne, et redevenir actif dès qu'une deuxième ligne existe.
void main() {
  setUpAll(loadTestFonts);

  testWidgets('bureau : le bouton de la ligne unique est désactivé et ne retire rien',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'une seule ligne');

    // Le contrôle doit être réellement inerte : un `GestureDetector` sans
    // `onTap` (nul), pas seulement grisé visuellement en gardant `onTap`.
    final detecteur = tester.widget<GestureDetector>(
      find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(GestureDetector)).first,
    );
    expect(detecteur.onTap, isNull,
        reason: 'sur la dernière ligne, le contrôle ne doit plus rien déclencher');

    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'toujours une seule ligne');
  });

  testWidgets('bureau : dès une deuxième ligne, les deux boutons redeviennent actifs',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter une ligne'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNWidgets(2));

    for (final detecteur in tester
        .widgetList<GestureDetector>(find.ancestor(
            of: find.byIcon(Icons.close), matching: find.byType(GestureDetector)))
        ) {
      expect(detecteur.onTap, isNotNull);
    }

    // Retirer une ligne ramène à une seule : le contrôle restant redevient
    // inerte, exactement comme au départ.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
    final apres = tester.widget<GestureDetector>(
      find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(GestureDetector)).first,
    );
    expect(apres.onTap, isNull);
  });

  testWidgets('téléphone : le bouton de la ligne unique est désactivé (IconButton.onPressed nul)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    final bouton = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.close), matching: find.byType(IconButton)).first,
    );
    expect(bouton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
