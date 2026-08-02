import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('l\'onglet Comptabilité s\'affiche sans erreur', (tester) async {
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
    // La dépense se saisit dans une boîte, comme les créances et les dettes.
    expect(find.text('Nouvelle Dépense'), findsOneWidget);
    expect(find.text('Ajouter une dépense'), findsNothing);
    expect(find.text('Bénéfice par facture'), findsOneWidget);
    // La comptabilité est désormais cadrée sur un mois : elle annonce
    // lequel, et le bilan tous mois confondus a disparu.
    expect(find.text('EXERCICE AFFICHÉ'), findsOneWidget);
    expect(find.text('Dettes & créances réglées'), findsOneWidget);
    expect(find.text('Bilan mensuel'), findsNothing);
  });

  testWidgets('l\'onglet Dîme recalculé s\'affiche et propose un versement', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Dîme'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DÎME TOTALE (10%)'), findsOneWidget);
    expect(find.byTooltip('Marquer versée'), findsWidgets);
  });

  testWidgets('l\'onglet Engagements remplace Factures & Crédits', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));

    expect(find.text('Factures & Crédits'), findsNothing);
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TOTAL CRÉANCES'), findsOneWidget);
    expect(find.text('TOTAL DETTES'), findsOneWidget);
    expect(find.text('SOLDE NET'), findsOneWidget);
    // Deux listes séparées, comptées, et un bouton qui suit la liste ouverte.
    expect(find.text('Créances (4)'), findsOneWidget);
    expect(find.text('Dettes (7)'), findsOneWidget);
    expect(find.text('Nouvelle Créance'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('SENS'), findsNothing);
  });

  testWidgets('basculer sur Dettes change la liste et le bouton', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();

    // Liste Créances : les fournisseurs des dettes n'y figurent pas.
    // Advans (en cours) et non Acme Corp (déjà réglée) : la vue par défaut
    // du filtre En cours / Réglées ne montre plus les créances soldées.
    expect(find.text("Advans Côte d'Ivoire"), findsOneWidget);
    expect(find.text('Orange CI'), findsNothing);

    await tester.tap(find.text('Dettes (7)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Orange CI'), findsOneWidget);
    expect(find.text("Advans Côte d'Ivoire"), findsNothing);
    expect(find.text('Nouvelle Dette'), findsOneWidget);
  });

  testWidgets('le bouton Nouvelle Créance ouvre le questionnaire et enregistre', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    final avant = state.engagements.length;

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle Créance'));
    await tester.pumpAndSettle();

    // Le type vient de la liste ouverte : pas de sélecteur dans le formulaire.
    expect(find.text('NOM DU DÉBITEUR'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('CRÉANCIER'), findsNothing);
    expect(find.text('CATÉGORIE DE DÉPENSE'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Ex : Advans'), 'Client Dialogue');
    await tester.enterText(find.widgetWithText(TextField, 'Ex : Équipements réseau'), 'Appareils');
    await tester.enterText(find.widgetWithText(TextField, '0'), '125000');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nouvelle Créance'), findsOneWidget); // bouton, boîte fermée
    expect(state.engagements.length, avant + 1);
    // `sens` vaut désormais 'entrant'/'sortant' ('creance'/'dette' n'existent
    // plus sur Engagement depuis la tâche 2) : seule cette valeur change.
    expect(state.engagements.first.sens, 'entrant');
    expect(state.engagements.first.tiers, 'Client Dialogue');
    expect(state.engagements.first.description, 'Appareils');
    expect(state.engagements.first.montant, 125000);
  });

  testWidgets('le bouton Nouvelle Dépense ouvre le questionnaire et enregistre', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    final avant = state.engagements.length;

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle Dépense'));
    await tester.pumpAndSettle();

    // « LIBELLÉ » et « CATÉGORIE » sont aussi des en-têtes du tableau des
    // dépenses : on s'ancre sur le sous-titre de la boîte, lui unique.
    expect(find.text('Imputée au mois de sa date.'), findsOneWidget);
    expect(find.text('RATTACHEMENT'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ex : Achat matériel'), 'Carburant');
    await tester.enterText(find.widgetWithText(TextField, '0'), '45000');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Imputée au mois de sa date.'), findsNothing); // boîte refermée
    // `Expense` a disparu (tâche 2) : une dépense est désormais un engagement
    // sortant créé ET réglé le jour même. `addEngagement` insère en tête
    // (`.first`, pas `.last`), et le libellé saisi devient le `tiers` de
    // l'engagement (`Expense` n'avait pas de champ tiers distinct).
    expect(state.engagements.length, avant + 1);
    expect(state.engagements.first.sens, 'sortant');
    expect(state.engagements.first.tiers, 'Carburant');
    expect(state.engagements.first.montant, 45000);
    expect(state.engagements.first.regle, 45000);
    expect(state.engagements.first.solde, isTrue);
  });

  testWidgets('le formulaire de dette demande le créancier et la catégorie', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dettes (7)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle Dette'));
    await tester.pumpAndSettle();

    expect(find.text('CRÉANCIER'), findsOneWidget);
    expect(find.text('NOM DU DÉBITEUR'), findsNothing);
    expect(find.text('CATÉGORIE DE DÉPENSE'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ex : Orange CI'), 'Fournisseur X');
    await tester.enterText(find.widgetWithText(TextField, '0'), '60000');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(state.engagements.first.sens, 'sortant');
    expect(state.engagements.first.tiers, 'Fournisseur X');
  });

  testWidgets('le questionnaire refuse une saisie incomplète', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    final avant = state.engagements.length;

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouvelle Créance'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    // La boîte reste ouverte et dit ce qui manque.
    expect(find.text('NOM DU DÉBITEUR'), findsOneWidget);
    expect(find.textContaining('Renseignez le nom du débiteur'), findsOneWidget);
    expect(state.engagements.length, avant);
  });

  testWidgets('une créance validée apparaît dans la comptabilité du mois', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.addEngagement(Engagement(
      id: 4242, sens: 'entrant', tiers: 'Client Test',
      montant: 750000, echeance: DateTime(2030, 12, 31),
      documentNumero: 'CR-TEST-01',
    ));
    state.ajouterReglement(4242, 750000, DateTime.now());

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('CR-TEST-01'), findsOneWidget);
    expect(find.text('Client Test'), findsOneWidget);
  });
}
