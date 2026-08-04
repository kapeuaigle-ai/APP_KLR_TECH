import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

Projet _p({int id = 1, String nom = 'Fourniture matériel', bool annule = false}) => Projet(
      id: id, nom: nom, typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      annule: annule,
    );

void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.pumpAndSettle();
  }

  group('sélecteur de projet — créance/dette', () {
    testWidgets('absent quand aucun projet n\'existe', (tester) async {
      final state = AppState()..viderDonnees();
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Créance'));
      await tester.pumpAndSettle();

      expect(find.text('PROJET'), findsNothing);
    });

    testWidgets('apparaît quand au moins un projet existe', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Créance'));
      await tester.pumpAndSettle();

      expect(find.text('PROJET'), findsOneWidget);
    });

    testWidgets('créer une dette avec un projet choisi stocke projetId', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Dette'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ex : Orange CI'), 'Fournisseur X');
      await tester.enterText(find.widgetWithText(TextField, '0'), '60000');

      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fourniture matériel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.engagements.first.sens, 'sortant');
      expect(state.engagements.first.projetId, 1);
    });

    testWidgets('créer une dette sans choisir de projet stocke projetId nul', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (0)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Dette'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ex : Orange CI'), 'Fournisseur X');
      await tester.enterText(find.widgetWithText(TextField, '0'), '60000');

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.engagements.first.projetId, isNull);
    });

    testWidgets('les projets annulés ne sont pas proposés', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p(id: 1, nom: 'Projet Actif'));
      state.addProjet(_p(id: 2, nom: 'Projet Annulé', annule: true));
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Créance'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();

      expect(find.text('Projet Actif'), findsWidgets);
      expect(find.text('Projet Annulé'), findsNothing);
    });
  });

  group('sélecteur de projet — dépense', () {
    testWidgets('apparaît dans le formulaire de dépense', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await pump(tester, state);

      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Dépense'));
      await tester.pumpAndSettle();

      expect(find.text('PROJET'), findsOneWidget);
    });

    testWidgets('créer une dépense avec un projet choisi stocke projetId', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await pump(tester, state);

      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nouvelle Dépense'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Ex : Achat matériel'), 'Carburant');
      await tester.enterText(find.widgetWithText(TextField, '0'), '45000');

      // Deux DropdownButton<...> coexistent (RATTACHEMENT en facture, PROJET) :
      // le sélecteur de projet est le second.
      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fourniture matériel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.engagements.first.sens, 'sortant');
      expect(state.engagements.first.projetId, 1);
    });
  });

  group('rattacher un engagement existant à un projet', () {
    testWidgets('un engagement créé sans projet peut être rattaché après coup', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur Ancien', montant: 500,
        echeance: DateTime(2026, 4, 1),
      ));
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rattacher à un projet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fourniture matériel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.engagements.first.projetId, 1);
    });

    testWidgets('l\'action n\'apparaît pas quand aucun projet n\'existe', (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur Ancien', montant: 500,
        echeance: DateTime(2026, 4, 1),
      ));
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dettes (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Rattacher à un projet'), findsNothing);
    });
  });

  group('rendu au format téléphone', () {
    testWidgets('le formulaire de dette avec sélecteur de projet ne déborde pas à 360x800',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addProjet(_p());

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      // Le bouton s'appelle « Nouvelle Créance » tant que la liste Dettes
      // n'est pas sélectionnée.
      await tester.ensureVisible(find.text('Dettes (0)'));
      await tester.tap(find.text('Dettes (0)'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nouvelle Dette').first);
      await tester.tap(find.text('Nouvelle Dette').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PROJET'), findsOneWidget);
    });

    testWidgets('le formulaire de dépense avec sélecteur de projet ne déborde pas à 360x800',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.addProjet(_p());

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Comptabilité'));
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nouvelle Dépense').first);
      await tester.tap(find.text('Nouvelle Dépense').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('PROJET'), findsOneWidget);
    });
  });
}
