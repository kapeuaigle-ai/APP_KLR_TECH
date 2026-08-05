import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// Un projet annulé n'a nulle part où aller : il quitte le Kanban (le
/// tableau des quatre statuts actifs) mais reste invisible pour toujours,
/// sans bouton pour le retrouver, le réactiver ou le supprimer. Cette suite
/// couvre le correctif : un filtre « Annulés » dans l'en-tête de l'écran
/// Projets, affichant les projets annulés en liste unique quand il est actif.

Projet _p({int id = 1, String nom = 'Fourniture matériel'}) => Projet(
      id: id, nom: nom, typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('le chip « Annulés » est visible avec un compteur à 0 quand rien n\'est annulé',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p());
    await _pump(tester, state);
    expect(find.text('Annulés (0)'), findsOneWidget);
  });

  testWidgets('le chip affiche le bon compteur de projets annulés', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p(id: 1, nom: 'Projet A'));
    state.addProjet(_p(id: 2, nom: 'Projet B'));
    state.addProjet(_p(id: 3, nom: 'Projet C'));
    state.annulerProjet(1);
    state.annulerProjet(2);
    await _pump(tester, state);
    expect(find.text('Annulés (2)'), findsOneWidget);
  });

  testWidgets('par défaut (chip inactif) : un projet annulé est absent, un projet vivant est présent',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p(id: 1, nom: 'Projet vivant'));
    state.addProjet(_p(id: 2, nom: 'Projet annulé'));
    state.annulerProjet(2);
    await _pump(tester, state);

    expect(find.text('Projet vivant'), findsOneWidget);
    expect(find.text('Projet annulé'), findsNothing);
  });

  testWidgets('chip actif : seul le projet annulé apparaît, le vivant disparaît',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p(id: 1, nom: 'Projet vivant'));
    state.addProjet(_p(id: 2, nom: 'Projet annulé'));
    state.annulerProjet(2);
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Projet annulé'), findsOneWidget);
    expect(find.text('Projet vivant'), findsNothing);
  });

  testWidgets('chip actif puis réactivé : le toggle repasse au tableau normal',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p(id: 1, nom: 'Projet vivant'));
    state.addProjet(_p(id: 2, nom: 'Projet annulé'));
    state.annulerProjet(2);
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Projet annulé'), findsOneWidget);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Projet vivant'), findsOneWidget);
    expect(find.text('Projet annulé'), findsNothing);
  });

  testWidgets('liste des annulés vide : message dédié plutôt que « Aucun projet enregistré »',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p());
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (0)'));
    await tester.pumpAndSettle();

    expect(find.text('Aucun projet annulé.'), findsOneWidget);
    expect(find.text('Fourniture matériel'), findsNothing);
  });

  testWidgets('réactiver depuis la liste des annulés fait revenir le projet dans le tableau normal',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p());
    state.annulerProjet(1);
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fourniture matériel'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    expect(find.text('Réactiver'), findsOneWidget);
    expect(find.text('Annuler le projet'), findsNothing);
    await tester.tap(find.text('Réactiver'));
    await tester.pumpAndSettle();

    expect(state.projets.first.annule, isFalse);

    // Ferme la fiche puis désactive le filtre : le projet doit être de
    // retour dans le tableau normal, plus dans la liste des annulés.
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Annulés (0)'), findsOneWidget);
    await tester.tap(find.text('Annulés (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Fourniture matériel'), findsOneWidget);
  });

  testWidgets('la fiche d\'un projet annulé, ouverte depuis la liste, propose Réactiver et Supprimer, pas Annuler',
      (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(_p());
    state.annulerProjet(1);
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fourniture matériel'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(Dialog), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();

    expect(find.text('Réactiver'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.text('Annuler le projet'), findsNothing);
  });

  testWidgets('supprimer un projet annulé depuis la liste détache ses documents et engagements',
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
    state.annulerProjet(1);
    await _pump(tester, state);

    await tester.tap(find.text('Annulés (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fourniture matériel'));
    await tester.pumpAndSettle();
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

  // ── Menu de la carte, dans la liste des annulés ──────────
  // « Annuler le projet » sur un projet déjà annulé est un geste sans
  // effet visible : le manager clique et doute que l'application ait
  // enregistré quoi que ce soit. « Reporter l'échéance » sur un projet
  // abandonné n'a pas plus de sens. La carte doit suivre la même
  // distinction que la fiche (§ !projet.annule).
  group('menu de la carte — projet annulé', () {
    testWidgets('propose seulement Réactiver et Modifier — pas Relancer, Reporter, Annuler ni Supprimer',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.annulerProjet(1);
      await _pump(tester, state);

      await tester.tap(find.text('Annulés (1)'));
      await tester.pumpAndSettle();

      // Aucun dialogue n'est ouvert ici : le more_vert n'est pas ambigu.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Réactiver'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Relancer le client'), findsNothing);
      expect(find.text('Reporter l\'échéance'), findsNothing);
      expect(find.text('Annuler le projet'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('un projet vivant garde son menu de carte inchangé — les quatre entrées',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.saveOrUpdateProforma(DocumentItem(
        id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
        lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)],
      ));
      state.validateProforma(1); // crée un entrant → « Relancer le client » proposé
      await _pump(tester, state);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Relancer le client'), findsOneWidget);
      expect(find.text('Reporter l\'échéance'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Annuler le projet'), findsOneWidget);
      expect(find.text('Réactiver'), findsNothing);
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('taper Réactiver depuis la carte fait revenir le projet au tableau normal',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_p());
      state.annulerProjet(1);
      await _pump(tester, state);

      await tester.tap(find.text('Annulés (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réactiver'));
      await tester.pumpAndSettle();

      expect(state.projets.first.annule, isFalse);
      // Disparaît de la liste des annulés — son compteur retombe à 0.
      expect(find.text('Annulés (0)'), findsOneWidget);
      expect(find.text('Fourniture matériel'), findsNothing);

      // Réapparaît parmi les vivants une fois le filtre désactivé.
      await tester.tap(find.text('Annulés (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Fourniture matériel'), findsOneWidget);
    });
  });
}
