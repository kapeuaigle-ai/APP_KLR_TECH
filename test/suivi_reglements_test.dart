import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('un engagement partiellement réglé affiche son reste', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addEngagement(Engagement(
      id: 1, sens: 'entrant', tiers: 'ACME', montant: 1000,
      echeance: DateTime(2026, 6, 30), description: 'Fourniture',
    ));
    state.ajouterReglement(1, 400, DateTime(2026, 3, 3));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('600'), findsWidgets, reason: 'le reste dû');
  });

  testWidgets('l\'onglet Comptabilité s\'affiche sans Expense', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bénéfice par facture'), findsOneWidget);
  });

  // ── Filtre En cours / Réglées (régression Phase 1) ─────────
  // Un engagement soldé le jour même (ex. dépense au comptant) reste un
  // Engagement, donc apparaît par défaut dans Suivi → Dettes/Créances — ce
  // qui noie l'unique dette réellement en cours sous des lignes déjà closes.
  // Le filtre doit cacher les lignes réglées/annulées par défaut, sans jamais
  // toucher les totaux (TOTAL DETTES/CRÉANCES/SOLDE NET), qui restent une
  // somme sur tous les engagements non annulés.
  group('filtre En cours / Réglées', () {
    testWidgets('par défaut, une dette réglée n\'apparaît pas et une dette en cours apparaît',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur En Cours', montant: 70000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.addEngagement(Engagement(
        id: 2, sens: 'sortant', tiers: 'Fournisseur Réglé', montant: 30000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.ajouterReglement(2, 30000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (2)'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fournisseur En Cours'), findsOneWidget);
      expect(find.text('Fournisseur Réglé'), findsNothing);
    });

    testWidgets('basculer sur Réglées inverse la liste affichée', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur En Cours', montant: 70000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.addEngagement(Engagement(
        id: 2, sens: 'sortant', tiers: 'Fournisseur Réglé', montant: 30000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.ajouterReglement(2, 30000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (2)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fournisseur Réglé'), findsOneWidget);
      expect(find.text('Fournisseur En Cours'), findsNothing);
    });

    testWidgets('une dette annulée apparaît sous Réglées, pas En cours', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur Annulé', montant: 50000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.annulerEngagement(1);

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Fournisseur Annulé'), findsNothing, reason: 'annulée : pas En cours');

      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Fournisseur Annulé'), findsOneWidget);
    });

    testWidgets('le TOTAL DETTES ne bouge pas selon le chip sélectionné', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur En Cours', montant: 70000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.addEngagement(Engagement(
        id: 2, sens: 'sortant', tiers: 'Fournisseur Réglé', montant: 30000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.ajouterReglement(2, 30000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (2)'));
      await tester.pumpAndSettle();

      // Seul l'engagement en cours a un reste dû non nul (70 000) : le total
      // ne doit refléter que ça, quel que soit le chip choisi ensuite.
      final totalAttendu = Fmt.number(70000);
      expect(find.text(totalAttendu), findsOneWidget,
          reason: 'TOTAL DETTES avec « En cours » sélectionné');

      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();

      expect(find.text(totalAttendu), findsOneWidget,
          reason: 'TOTAL DETTES ne doit pas bouger avec « Réglées » sélectionné');
    });

    testWidgets('les comptes des puces correspondent aux lignes affichées', (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'A En Cours', montant: 1000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.addEngagement(Engagement(
        id: 2, sens: 'sortant', tiers: 'B En Cours', montant: 2000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.addEngagement(Engagement(
        id: 3, sens: 'sortant', tiers: 'C Réglé', montant: 3000,
        echeance: DateTime(2026, 6, 30),
      ));
      state.ajouterReglement(3, 3000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (3)'));
      await tester.pumpAndSettle();

      expect(find.text('En cours (2)'), findsOneWidget);
      expect(find.text('Réglées (1)'), findsOneWidget);
      expect(find.text('A En Cours'), findsOneWidget);
      expect(find.text('B En Cours'), findsOneWidget);
      expect(find.text('C Réglé'), findsNothing);

      await tester.tap(find.text('Réglées (1)'));
      await tester.pumpAndSettle();

      expect(find.text('C Réglé'), findsOneWidget);
      expect(find.text('A En Cours'), findsNothing);
      expect(find.text('B En Cours'), findsNothing);
    });
  });
}
