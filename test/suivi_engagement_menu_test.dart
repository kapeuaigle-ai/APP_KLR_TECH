import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

// ── Défaut G1/G4 (Lot G) ──────────────────────────────────
// « Annuler l'engagement » n'a plus rien à changer une fois l'engagement
// soldé (reste déjà à 0) : l'entrée disparaît du menu plutôt que de rester un
// geste sans effet. « Gérer les règlements » reste utile sur un engagement
// soldé (retirer un règlement mal saisi le déclot), mais son libellé ne doit
// plus laisser croire à un encours encore ouvert.
void main() {
  setUpAll(loadTestFonts);

  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> ouvrirEngagements(WidgetTester tester) async {
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
  }

  group('« Annuler l\'engagement » — présence selon l\'état', () {
    testWidgets('en cours (non soldé, non annulé) : proposée', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Annuler l\'engagement'), findsOneWidget);
      expect(find.text('Réactiver'), findsNothing);
    });

    testWidgets('partiellement réglé (non soldé) : toujours proposée', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 400, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Annuler l\'engagement'), findsOneWidget);
    });

    testWidgets('soldé (reste à 0) : absente, et « Réactiver » n\'apparaît pas non plus',
        (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 1000, DateTime(2026, 3, 3));
      expect(state.engagements.first.solde, isTrue);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      // Un engagement soldé vit sous le filtre « Réglées ».
      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Annuler l\'engagement'), findsNothing,
          reason: 'reste déjà à 0 : annuler ne changerait rien');
      expect(find.text('Réactiver'), findsNothing,
          reason: 'l\'engagement n\'est pas annulé, rien à réactiver');
    });

    testWidgets('annulé : « Réactiver » proposée, « Annuler » absente', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.annulerEngagement(1);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Réactiver'), findsOneWidget);
      expect(find.text('Annuler l\'engagement'), findsNothing);
    });
  });

  group('libellé de « Gérer les règlements » selon l\'état (défaut G4)', () {
    testWidgets('non soldé, un règlement déjà passé : « Gérer les règlements », '
        'la boîte s\'ouvre sous le titre « Règlements » et liste le règlement',
        (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 400, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Gérer les règlements'), findsOneWidget);
      expect(find.text('Corriger un règlement'), findsNothing);

      await tester.tap(find.text('Gérer les règlements'));
      await tester.pumpAndSettle();

      expect(find.text('Règlements'), findsOneWidget);
      expect(find.textContaining('03/03/2026'), findsOneWidget,
          reason: 'le règlement déjà passé reste listé');
    });

    testWidgets('soldé : « Corriger un règlement », la boîte s\'ouvre sous ce même '
        'titre et liste toujours le règlement', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 1000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Corriger un règlement'), findsOneWidget);
      expect(find.text('Gérer les règlements'), findsNothing);

      await tester.tap(find.text('Corriger un règlement'));
      await tester.pumpAndSettle();

      // Le titre de la boîte suit la même distinction que l'entrée de menu
      // qui l'a ouverte : un seul « Corriger un règlement » doit être visible
      // (l'entrée de menu a disparu avec la fermeture du popup).
      expect(find.text('Corriger un règlement'), findsOneWidget);
      // Scopé à la boîte : l'engagement soldé affiche aussi sa date de
      // règlement dans la ligne de tableau derrière le dialogue (colonne
      // « RÉGLÉ LE »), donc une recherche non scopée trouve deux widgets.
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('03/03/2026')),
        findsOneWidget,
        reason: 'le règlement reste listé : seule la suppression corrige',
      );

      // Le comportement du bouton « Ajouter un règlement » n'est pas
      // touché par ce lot : il reste désactivé sur un engagement soldé.
      final ajouter = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Ajouter un règlement'));
      expect(ajouter.onPressed, isNull);
    });

    testWidgets('sans aucun règlement encore enregistré : « Enregistrer un règlement » '
        '(régression, comportement inchangé)', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await ouvrirEngagements(tester);
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer un règlement'), findsOneWidget);
    });
  });

  // ── Même code path table (bureau) / carte (téléphone) ──────
  // `_engagementMenu` est appelée depuis les deux layouts avec les mêmes
  // arguments (voir suivi_screen.dart, `trailing: _engagementMenu(...)` dans
  // le `ListCard` téléphone et dans la cellule de la ligne de tableau) : un
  // seul test à largeur téléphone suffit donc à couvrir ce chemin partagé.
  testWidgets('carte téléphone : même libellé « Corriger un règlement » sur un '
      'engagement soldé', (tester) async {
    phone(tester);
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
        montant: 1000, echeance: DateTime(2026, 6, 30)));
    state.ajouterReglement(1, 1000, DateTime(2026, 3, 3));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await ouvrirEngagements(tester);
    await tester.tap(find.text('Réglées (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();

    expect(find.text('Corriger un règlement'), findsOneWidget);
    expect(find.text('Annuler l\'engagement'), findsNothing);

    await tester.tap(find.text('Corriger un règlement'));
    await tester.pumpAndSettle();

    expect(find.text('Corriger un règlement'), findsOneWidget,
        reason: 'la boîte ouverte porte le même titre');
    // Scopé à la boîte pour la même raison que le test bureau ci-dessus : la
    // carte, derrière le dialogue, affiche elle aussi la date (« RÉGLÉ LE »).
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('03/03/2026')),
      findsOneWidget,
    );
  });
}
