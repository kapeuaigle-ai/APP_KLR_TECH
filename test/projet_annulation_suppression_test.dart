import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

Projet _p({int id = 1, String nom = 'Fourniture matériel'}) => Projet(
      id: id, nom: nom, typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

Future<void> _pump(WidgetTester tester, AppState state, Widget child) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  group('AppState.annulerProjet / reactiverProjet', () {
    test('annulerProjet met annule à vrai', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      s.annulerProjet(1);
      expect(s.projets.first.annule, isTrue);
    });

    test('reactiverProjet remet annule à faux', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      s.annulerProjet(1);
      s.reactiverProjet(1);
      expect(s.projets.first.annule, isFalse);
    });

    test('un id inconnu ne fait rien', () {
      final s = AppState()..viderDonnees();
      s.annulerProjet(999); // ne doit pas lancer d'exception
      expect(s.projets, isEmpty);
    });

    test('un projet annulé a le statut StatutProjet.annule', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      s.annulerProjet(1);
      final a = s.avancementProjet(1, now: DateTime(2026, 4, 1));
      expect(a.statut, StatutProjet.annule);
    });
  });

  group('un projet annulé disparaît du Kanban et du Gantt', () {
    testWidgets('Kanban : disparaît une fois annulé, réapparaît après réactivation',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await _pump(tester, state, const ProjetsScreen());

      expect(find.text('Fourniture matériel'), findsOneWidget);

      state.annulerProjet(1);
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsNothing);

      state.reactiverProjet(1);
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsOneWidget);
    });

    testWidgets('Gantt : disparaît une fois annulé, réapparaît après réactivation',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await _pump(tester, state, const GanttScreen());

      expect(find.text('Fourniture matériel'), findsOneWidget);

      state.annulerProjet(1);
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsNothing);

      state.reactiverProjet(1);
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsOneWidget);
    });
  });

  group('fiche projet — annuler / réactiver / supprimer', () {
    testWidgets('le bouton Annuler le projet est proposé, et bascule sur Réactiver',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await _pump(tester, state, const ProjetsScreen());

      await tester.tap(find.text('Fourniture matériel'));
      await tester.pumpAndSettle();

      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('Annuler le projet'), findsOneWidget);
      expect(find.text('Réactiver'), findsNothing);

      await tester.tap(find.text('Annuler le projet'));
      await tester.pumpAndSettle();

      expect(state.projets.first.annule, isTrue);

      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      expect(find.text('Réactiver'), findsOneWidget);
      expect(find.text('Annuler le projet'), findsNothing);
    });

    testWidgets('supprimer un projet sans rien rattaché ne demande pas de détail',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await _pump(tester, state, const ProjetsScreen());

      await tester.tap(find.text('Fourniture matériel'));
      await tester.pumpAndSettle();

      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('aucun document'), findsOneWidget);
    });

    testWidgets('la confirmation de suppression nomme les documents et engagements rattachés',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.saveOrUpdateProforma(DocumentItem(
        id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
        lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)],
      ));
      state.addEngagement(Engagement(
        id: 9, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
        echeance: DateTime(2026, 4, 1), projetId: 1));
      await _pump(tester, state, const ProjetsScreen());

      await tester.tap(find.text('Fourniture matériel'));
      await tester.pumpAndSettle();

      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 document'), findsOneWidget);
      expect(find.textContaining('1 engagement'), findsOneWidget);
      expect(find.textContaining('ne seront pas supprimés'), findsOneWidget);
    });

    testWidgets('annuler la confirmation ne change rien', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      await _pump(tester, state, const ProjetsScreen());

      await tester.tap(find.text('Fourniture matériel'));
      await tester.pumpAndSettle();
      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(state.projets, hasLength(1));
      // Toujours 2 : la carte Kanban derrière et le titre de la fiche —
      // preuve qu'elle est restée ouverte.
      expect(find.text('Fourniture matériel'), findsNWidgets(2));
    });

    testWidgets('confirmer supprime le projet mais laisse le document et l\'engagement, détachés',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.saveOrUpdateProforma(DocumentItem(
        id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
        lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)],
      ));
      state.addEngagement(Engagement(
        id: 9, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
        echeance: DateTime(2026, 4, 1), projetId: 1));
      await _pump(tester, state, const ProjetsScreen());

      await tester.tap(find.text('Fourniture matériel'));
      await tester.pumpAndSettle();
      // La carte Kanban, restée montée derrière la fiche, porte elle aussi
      // un bouton « more_vert » depuis l'ajout de son propre menu d'actions
      // (§ actions Kanban) : on cible ici précisément celui de la fiche.
      await tester.tap(find.descendant(
          of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.projets, isEmpty);
      final doc = state.documents['proforma']!.firstWhere((d) => d.id == 1);
      expect(doc.projetId, isNull, reason: 'détaché, pas supprimé');
      final eng = state.engagements.firstWhere((e) => e.id == 9);
      expect(eng.projetId, isNull, reason: 'détaché, pas supprimé');
    });
  });
}
