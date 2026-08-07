import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

// ── Défaut 2 (Lot C) ──────────────────────────────────────
// Quatre chemins supprimaient un engagement ou un règlement sans jamais
// demander confirmation : « Gérer les règlements » (dans la boîte ouverte
// depuis l'onglet Engagements), le menu « Supprimer » de l'onglet
// Engagements, et les deux icônes « Supprimer » de la section « Dettes &
// créances réglées » de l'onglet Comptabilité (tableau bureau et carte
// téléphone). Ces quatre chemins doivent désormais confirmer, ne rien faire
// à l'annulation, et supprimer effectivement à la confirmation.
void main() {
  setUpAll(loadTestFonts);

  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
  }

  // ── 1. « Gérer les règlements » ────────────────────────
  group('suppression d\'un règlement depuis « Gérer les règlements »', () {
    testWidgets('demande confirmation et ne retire rien à l\'annulation', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 400, DateTime(2026, 3, 3));
      state.ajouterReglement(1, 200, DateTime(2026, 4, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gérer les règlements'));
      await tester.pumpAndSettle();

      expect(find.text('Règlements'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      // La confirmation nomme concrètement ce qui va disparaître.
      expect(find.text('Supprimer ce règlement ?'), findsOneWidget);
      expect(state.engagements.first.reglements.length, 2,
          reason: 'rien ne doit disparaître avant confirmation');

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer ce règlement ?'), findsNothing);
      expect(state.engagements.first.reglements.length, 2,
          reason: 'annuler la confirmation ne doit rien retirer');
      expect(find.text('Règlements'), findsOneWidget, reason: 'la boîte Règlements reste ouverte');
    });

    testWidgets('confirmer retire bien le règlement visé', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
          montant: 1000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 400, DateTime(2026, 3, 3));
      state.ajouterReglement(1, 200, DateTime(2026, 4, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gérer les règlements'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(state.engagements.first.reglements.length, 1);
    });
  });

  // ── 2. Menu « Supprimer » de l'onglet Engagements ──────
  group('suppression d\'un engagement depuis le menu de l\'onglet Engagements', () {
    testWidgets('demande confirmation et ne supprime rien à l\'annulation', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Fournisseur X',
          montant: 80000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 30000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      // Le menu sépare visuellement la suppression du reste (annuler, etc).
      expect(find.byType(PopupMenuDivider), findsOneWidget);

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet engagement ?'), findsOneWidget);
      expect(state.engagements, hasLength(1));

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet engagement ?'), findsNothing);
      expect(state.engagements, hasLength(1));
      expect(find.text('Fournisseur X'), findsOneWidget);
    });

    testWidgets('confirmer supprime bien l\'engagement', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Fournisseur X',
          montant: 80000, echeance: DateTime(2026, 6, 30)));
      state.ajouterReglement(1, 30000, DateTime(2026, 3, 3));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(state.engagements, isEmpty);
      expect(find.text('Fournisseur X'), findsNothing);
    });
  });

  // ── 3 & 4. Section « Dettes & créances réglées » de Comptabilité ──
  // Un engagement réglé CE MOIS-CI (mois en cours) : les contrôles sont
  // actifs (le verrouillage du mois clôturé est couvert par un autre test,
  // voir suivi_compta_mois_cloture_test.dart) mais doivent tout de même
  // confirmer avant de supprimer.
  group('suppression depuis « Dettes & créances réglées » (mois en cours)', () {
    testWidgets('tableau bureau : demande confirmation, rien à l\'annulation, supprime à la confirmation',
        (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Dépense Courante',
          montant: 15000, echeance: DateTime.now()));
      state.ajouterReglement(1, 15000, DateTime.now());

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      expect(find.text('Dépense Courante'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet engagement ?'), findsOneWidget);
      expect(state.engagements, hasLength(1));

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(state.engagements, hasLength(1));
      expect(find.text('Dépense Courante'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(state.engagements, isEmpty);
      expect(find.text('Dépense Courante'), findsNothing);
    });

    testWidgets('carte téléphone : demande confirmation, rien à l\'annulation, supprime à la confirmation',
        (tester) async {
      phone(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Dépense Courante',
          montant: 15000, echeance: DateTime.now()));
      state.ajouterReglement(1, 15000, DateTime.now());

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      expect(find.text('Dépense Courante'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet engagement ?'), findsOneWidget);
      expect(state.engagements, hasLength(1));

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(state.engagements, hasLength(1));

      await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(state.engagements, isEmpty);
    });
  });
}
