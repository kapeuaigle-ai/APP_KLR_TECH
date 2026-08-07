import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/dashboard_screen.dart';
import 'package:klr_tech_app/widgets/app_header.dart';
import 'package:klr_tech_app/widgets/mobile_shell.dart';
import 'support/test_fonts.dart';

/// Lot E (défauts critiques) : le tableau de bord montrait des chiffres
/// figés — 25 000 000, 18 000 000, 142, 1 800 000 — qui ne bougeaient jamais
/// quoi qu'il arrive dans l'application, et un bouton « RELANCER CLIENT » qui
/// prétendait avoir envoyé un rappel sans rien envoyer. Ces tests vérifient
/// que le tableau de bord (et les deux en-têtes de notifications, qui
/// portaient les mêmes clients fictifs) ne peuvent plus diverger des vraies
/// données, et qu'aucune trace de la fiction d'origine ne subsiste.
void main() {
  setUpAll(loadTestFonts);

  AppState videAppState() {
    final state = AppState();
    state.engagements = [];
    state.clients = [];
    state.documents = {'proforma': [], 'facture': [], 'bl': []};
    return state;
  }

  /// Fenêtre large : la page défile, mais on veut voir tout son contenu (les
  /// alertes, tout en bas) sans avoir à faire défiler la vue de test.
  void grandeFenetre(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('E1 — les chiffres du tableau de bord sont dérivés, pas inventés', () {
    test('le calcul du mois en cours est identique à celui de la Comptabilité (Suivi)', () {
      final state = AppState();
      // Un engagement entrant réglé aujourd'hui : un vrai encaissement du
      // mois en cours.
      final id = state.nextId();
      state.addEngagement(Engagement(
        id: id, sens: 'entrant', tiers: 'Client Dashboard Test',
        montant: 654321, echeance: DateTime.now(),
      ));
      state.ajouterReglement(id, 654321, DateTime.now());

      // Exactement ce que fait dashboard_screen.dart.
      final (debut, fin) = Comptabilite.bornesMois(state.moisCourant);
      final rapportDashboard = Comptabilite.rapport(
          debut: debut, fin: fin, engagements: state.engagements);

      // Exactement ce que fait _ComptaTab (Suivi) par défaut.
      final rows = Comptabilite.bilanMensuel(
          state.engagements, state.dimePaidMonths, state.dimePaidDates);
      final bilanSuivi = Comptabilite.ligneMois(state.moisCourant, rows);

      expect(rapportDashboard.revenu, bilanSuivi!.revenu);
      expect(rapportDashboard.depenses, bilanSuivi.depenses);
      expect(rapportDashboard.benefice, bilanSuivi.benefice);
      expect(rapportDashboard.dime, bilanSuivi.dime);
      // Et concrètement, le nouvel encaissement y figure bien.
      expect(rapportDashboard.revenu, greaterThanOrEqualTo(654321));
    });

    testWidgets('le tableau de bord affiche le vrai revenu encaissé du mois, pas une constante', (tester) async {
      final state = videAppState();
      final id = state.nextId();
      state.addEngagement(Engagement(
        id: id, sens: 'entrant', tiers: 'Client Dashboard Test',
        montant: 777000, echeance: DateTime.now(),
      ));
      state.ajouterReglement(id, 777000, DateTime.now());
      // Une dépense aussi, pour que revenu et bénéfice diffèrent — sinon les
      // deux cartes afficheraient le même texte et l'assertion ci-dessous
      // deviendrait ambiguë entre deux widgets légitimement identiques.
      final idDep = state.nextId();
      state.addEngagement(Engagement(
        id: idDep, sens: 'sortant', tiers: 'Fournisseur Dashboard Test',
        montant: 100000, echeance: DateTime.now(), categorie: 'Autres',
      ));
      state.ajouterReglement(idDep, 100000, DateTime.now());

      grandeFenetre(tester);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('REVENU ENCAISSÉ'), findsOneWidget);
      expect(find.text(Fmt.number(777000)), findsOneWidget);
      // Les anciennes valeurs figées ont disparu.
      expect(find.text('25 000 000'), findsNothing);
      expect(find.text('18 000 000'), findsNothing);
      expect(find.text('1 800 000'), findsNothing);
      expect(find.text('142'), findsNothing);
    });

    testWidgets('installation vide : zéros et messages vides, jamais d\'exception', (tester) async {
      final state = videAppState();

      grandeFenetre(tester);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Quatre KPI à zéro (Fmt.number(0) == '0').
      expect(find.text('0'), findsWidgets);
      expect(find.text('Aucun encaissement enregistré pour l\'instant'), findsOneWidget);
      expect(find.text('Aucune dépense ce mois-ci'), findsOneWidget);
      expect(find.text('Aucune échéance en retard'), findsOneWidget);
      expect(find.text('Rien à encaisser pour le moment'), findsOneWidget);
    });
  });

  group('E2 — les alertes de paiement sont réelles, plus de bouton factice', () {
    testWidgets('une échéance réellement en retard apparaît, avec un lien honnête vers Suivi', (tester) async {
      final state = videAppState();
      final id = state.nextId();
      state.addEngagement(Engagement(
        id: id, sens: 'entrant', tiers: 'Client En Retard',
        montant: 500000, echeance: DateTime.now().subtract(const Duration(days: 10)),
        documentNumero: 'KLR-F09-TEST',
      ));

      grandeFenetre(tester);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Apparaît à la fois dans les alertes ET dans « À encaisser » : les
      // deux cartes sont honnêtes sur la même créance en retard, ce n'est
      // pas un doublon accidentel.
      expect(find.text('Client En Retard'), findsWidgets);
      expect(find.textContaining('KLR-F09-TEST'), findsOneWidget);
      expect(find.text('J+10'), findsOneWidget);

      // Le bouton ne prétend plus avoir envoyé un rappel : il navigue,
      // honnêtement, vers Suivi.
      expect(find.text('RELANCER CLIENT'), findsNothing);
      expect(find.textContaining('Rappel de paiement envoyé'), findsNothing);
      expect(find.text('VOIR DANS SUIVI'), findsOneWidget);

      expect(state.screen, isNot(NavScreen.suivi));
      await tester.tap(find.text('VOIR DANS SUIVI'));
      await tester.pumpAndSettle();
      expect(state.screen, NavScreen.suivi);
    });

    testWidgets('sans échéance en retard, aucune alerte ne s\'affiche', (tester) async {
      final state = videAppState();

      grandeFenetre(tester);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Groupe SAMA'), findsNothing);
      expect(find.text('AFRI TECH'), findsNothing);
    });

    testWidgets('l\'en-tête de bureau ne montre plus les clients fictifs', (tester) async {
      final state = videAppState();
      final id = state.nextId();
      state.addEngagement(Engagement(
        id: id, sens: 'entrant', tiers: 'Client Entete Bureau',
        montant: 300000, echeance: DateTime.now().subtract(const Duration(days: 2)),
      ));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: AppHeader())),
      ));
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Groupe SAMA'), findsNothing);
      expect(find.text('AFRI TECH'), findsNothing);
      expect(find.textContaining('Dîme Juin 2026'), findsNothing);
      expect(find.text('Client Entete Bureau'), findsOneWidget);
    });

    testWidgets('la feuille de notifications mobile ne montre plus les clients fictifs', (tester) async {
      final state = videAppState();
      final id = state.nextId();
      state.addEngagement(Engagement(
        id: id, sens: 'entrant', tiers: 'Client Mobile',
        montant: 300000, echeance: DateTime.now().subtract(const Duration(days: 2)),
      ));

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(home: MobileShell(child: Container())),
      ));
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Groupe SAMA'), findsNothing);
      expect(find.text('AFRI TECH'), findsNothing);
      expect(find.textContaining('Dîme Juin 2026'), findsNothing);
      expect(find.text('Client Mobile'), findsOneWidget);
    });
  });
}
