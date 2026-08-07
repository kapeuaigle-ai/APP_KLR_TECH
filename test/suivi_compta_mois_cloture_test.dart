import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

// ── Défaut 1 (Lot C) ──────────────────────────────────────
// Un mois passé affiche « Mois clôturé — consultation seule », mais ce
// badge ne gelait que le bouton « Nouvelle Dépense » : l'interrupteur
// Encaissée et le bouton Supprimer de « Dettes & créances réglées »
// restaient actifs, et pouvaient rouvrir la comptabilité d'un mois que le
// manager croit clos (dont la dîme est peut-être déjà versée).
//
// Vérifié par ailleurs (voir suivi_suppression_confirmation_test.dart et
// l'onglet Engagements) : un engagement réglé un mois passé reste
// atteignable depuis l'onglet Engagements, quel que soit le mois affiché
// en Comptabilité — « Gérer les règlements » n'y est jamais gelé. Verrouiller
// la vue mensuelle ne prive donc le manager d'aucun moyen de corriger une
// erreur passée, seulement de le faire par mégarde depuis cette vue-là.
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

  /// Sélectionne un mois dans le menu déroulant de Comptabilité.
  Future<void> selectionnerMois(WidgetTester tester, String monthKey) async {
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Comptabilite.monthLabel(monthKey)).last);
    await tester.pumpAndSettle();
  }

  /// Construit un état avec une facture entièrement encaissée sur un mois
  /// ancien (mars 2020 — nécessairement passé, quelle que soit la date
  /// réelle de la machine qui exécute le test) : elle apparaît donc dans
  /// « Bénéfice par facture » avec l'interrupteur Encaissée activé.
  AppState etatFacturePasseeEncaissee() {
    final state = AppState()..viderDonnees();
    state.documents['facture'] = [
      DocumentItem(id: 1, numero: 'F-2020-01', date: '15/03/2020', clientId: 0,
          client: 'Client Ancien', objet: 'Fourniture', montant: 100000, statut: 'validee'),
    ];
    state.addEngagement(Engagement(
      id: 10, sens: 'entrant', tiers: 'Client Ancien', montant: 100000,
      echeance: DateTime(2020, 3, 15), documentNumero: 'F-2020-01',
    ));
    state.ajouterReglement(10, 100000, DateTime(2020, 3, 15));
    return state;
  }

  /// Construit un état avec une dette payée (sans facture) sur le même mois
  /// ancien : elle apparaît dans « Dettes & créances réglées ».
  AppState etatDettePasseeReglee() {
    final state = AppState()..viderDonnees();
    state.addEngagement(Engagement(
      id: 20, sens: 'sortant', tiers: 'Fournisseur Ancien', montant: 50000,
      echeance: DateTime(2020, 3, 10),
    ));
    state.ajouterReglement(20, 50000, DateTime(2020, 3, 10));
    return state;
  }

  group('mois clôturé — contrôles désactivés', () {
    testWidgets('l\'interrupteur Encaissée est désactivé et un tap ne change rien (tableau bureau)',
        (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);
      final state = etatFacturePasseeEncaissee();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await selectionnerMois(tester, '2020-03');

      expect(find.text('Mois clôturé — consultation seule'), findsOneWidget);
      expect(find.text('F-2020-01'), findsOneWidget);

      final sw = tester.widget<Switch>(find.byType(Switch).first);
      expect(sw.onChanged, isNull, reason: 'désactivé, pas seulement inerte');
      expect(sw.value, isTrue, reason: 'la facture est bien encaissée');

      await tester.tap(find.byType(Switch).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.engagements.first.reglements.length, 1,
          reason: 'un tap sur un contrôle désactivé ne doit rien changer');
      expect(state.engagements.first.solde, isTrue);
    });

    testWidgets('l\'interrupteur Encaissée est désactivé et un tap ne change rien (carte téléphone)',
        (tester) async {
      phone(tester);
      addTearDown(tester.view.reset);
      final state = etatFacturePasseeEncaissee();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await selectionnerMois(tester, '2020-03');

      expect(find.text('F-2020-01'), findsOneWidget);

      final sw = tester.widget<Switch>(find.byType(Switch).first);
      expect(sw.onChanged, isNull);

      await tester.tap(find.byType(Switch).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.engagements.first.reglements.length, 1);
    });

    testWidgets('le bouton Supprimer de « Dettes & créances réglées » est désactivé (tableau bureau)',
        (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);
      final state = etatDettePasseeReglee();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await selectionnerMois(tester, '2020-03');

      expect(find.text('Fournisseur Ancien'), findsOneWidget);

      final btn = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ).first);
      expect(btn.onPressed, isNull, reason: 'désactivé, pas seulement inerte');

      await tester.tap(find.byIcon(Icons.delete_outline).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer cet engagement ?'), findsNothing,
          reason: 'un contrôle désactivé ne doit même pas ouvrir la confirmation');
      expect(state.engagements, hasLength(1));
    });

    testWidgets('le bouton Supprimer de « Dettes & créances réglées » est désactivé (carte téléphone)',
        (tester) async {
      phone(tester);
      addTearDown(tester.view.reset);
      final state = etatDettePasseeReglee();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await selectionnerMois(tester, '2020-03');

      expect(find.text('Fournisseur Ancien'), findsOneWidget);

      final btn = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ).first);
      expect(btn.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.delete_outline).first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(state.engagements, hasLength(1));
    });
  });

  group('mois en cours — contrôles actifs', () {
    testWidgets('l\'interrupteur Encaissée et le bouton Supprimer restent actifs', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.documents['facture'] = [
        DocumentItem(id: 1, numero: 'F-COURANT', date: '01/01/2026', clientId: 0,
            client: 'Client Courant', objet: 'Fourniture', montant: 50000, statut: 'validee'),
      ];
      state.addEngagement(Engagement(
        id: 1, sens: 'entrant', tiers: 'Client Courant', montant: 50000,
        echeance: DateTime.now(), documentNumero: 'F-COURANT',
      ));
      state.ajouterReglement(1, 50000, DateTime.now());
      state.addEngagement(Engagement(
        id: 2, sens: 'sortant', tiers: 'Fournisseur Courant', montant: 20000,
        echeance: DateTime.now(),
      ));
      state.ajouterReglement(2, 20000, DateTime.now());

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      expect(find.text('Mois clôturé — consultation seule'), findsNothing);

      final sw = tester.widget<Switch>(find.byType(Switch).first);
      expect(sw.onChanged, isNotNull);

      final btn = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ).first);
      expect(btn.onPressed, isNotNull);
    });
  });

  group('retirer un encaissement demande confirmation', () {
    AppState etatCourantEncaisse() {
      final state = AppState()..viderDonnees();
      state.documents['facture'] = [
        DocumentItem(id: 1, numero: 'F-COURANT', date: '01/01/2026', clientId: 0,
            client: 'Client Courant', objet: 'Fourniture', montant: 50000, statut: 'validee'),
      ];
      state.addEngagement(Engagement(
        id: 1, sens: 'entrant', tiers: 'Client Courant', montant: 50000,
        echeance: DateTime.now(), documentNumero: 'F-COURANT',
      ));
      state.ajouterReglement(1, 50000, DateTime.now());
      return state;
    }

    testWidgets('demande confirmation et ne retire rien à l\'annulation', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);
      final state = etatCourantEncaisse();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('Retirer l\'encaissement ?'), findsOneWidget);
      // Nomme concrètement ce qui va disparaître.
      expect(find.textContaining(Fmt.money(50000)), findsWidgets);
      expect(state.engagements.first.reglements.length, 1,
          reason: 'rien ne doit disparaître avant confirmation');

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Retirer l\'encaissement ?'), findsNothing);
      expect(state.engagements.first.reglements.length, 1);
      expect(state.engagements.first.solde, isTrue);
    });

    testWidgets('confirmer retire bien tous les règlements', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);
      final state = etatCourantEncaisse();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer'));
      await tester.pumpAndSettle();

      expect(state.engagements.first.reglements, isEmpty);
      expect(state.engagements.first.solde, isFalse);
    });
  });
}
