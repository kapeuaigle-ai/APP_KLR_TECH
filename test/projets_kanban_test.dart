import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

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

AppState _avecProjet({int qteLivree = 0, double encaisse = 0}) {
  final s = AppState()..viderDonnees();
  s.addProjet(Projet(
    id: 1, nom: 'Fourniture ACME',
    type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: 5,
    client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
  s.saveOrUpdateProforma(DocumentItem(
    id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
    client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
    lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: qteLivree)]));
  s.validateProforma(1);
  if (encaisse > 0) s.ajouterReglement(s.engagements.first.id, encaisse, DateTime(2026, 4, 1));
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les cartes factices ont disparu', (tester) async {
    await _pump(tester, AppState()..viderDonnees());
    expect(find.text('Refonte interface mobile'), findsNothing);
    expect(find.text('Migration cloud AWS'), findsNothing);
  });

  testWidgets('un projet sans rien livré ni encaissé va dans « À démarrer »', (tester) async {
    await _pump(tester, _avecProjet());
    expect(tester.takeException(), isNull);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Fourniture ACME'), findsOneWidget);
  });

  testWidgets('tout livré, rien encaissé : colonne « En révision »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10));
    expect(find.text('En révision'), findsWidgets);
  });

  testWidgets('tout livré et tout encaissé : colonne « Terminé »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10, encaisse: 3000));
    expect(find.text('Terminé'), findsWidgets);
  });

  testWidgets('les cartes ne sont plus déplaçables', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 5));
    expect(find.byType(Draggable), findsNothing,
        reason: 'la colonne est deduite : la deplacer a la main n\'aurait aucun sens');
  });

  // Le mot « Livré » ne parlait que de fourniture ; la barre physique est
  // commune aux quatre modes d'avancement (quantités, jalons, durée,
  // manuel), d'où le renommage en « Réalisé ». « Encaissé » reste inchangé :
  // l'argent est de l'argent, quel que soit le type de projet.
  testWidgets('la fiche projet affiche les libellés « Réalisé » et « Encaissé »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 5, encaisse: 900));
    await tester.tap(find.text('Fourniture ACME'));
    await tester.pumpAndSettle();
    expect(find.text('Réalisé'), findsWidgets);
    expect(find.text('Encaissé'), findsWidgets);
    expect(find.text('Livré'), findsNothing);
  });

  // ── Badge « Échéance atteinte » ──────────────────────────
  // Rien livré, rien encaissé, mais l'échéance est passée : le projet reste
  // en « À démarrer » (règle 3 avant règle 4) — le badge est le seul rappel
  // qu'il reste au manager.
  testWidgets('à démarrer, échéance passée : le badge « Échéance atteinte » apparaît', (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Idée jamais lancée', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
      client: '', debut: DateTime(2020, 1, 1), finPrevue: DateTime(2020, 6, 30)));
    await _pump(tester, s);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Échéance atteinte'), findsOneWidget);
  });

  testWidgets('à démarrer, échéance PAS passée : pas de badge', (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Projet futur', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
      client: '', debut: DateTime(2030, 1, 1), finPrevue: DateTime(2030, 6, 30)));
    await _pump(tester, s);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Échéance atteinte'), findsNothing);
  });

  testWidgets('« En révision » ne porte pas le badge : le statut est déjà le signal', (tester) async {
    // Livré et échéance dépassée (finPrevue par défaut le 30 juin 2026, bien
    // avant la date système réelle) : la carte tombe en « En révision », pas
    // « À démarrer », et ne doit donc jamais porter le badge.
    await _pump(tester, _avecProjet(qteLivree: 10));
    expect(find.text('En révision'), findsWidgets);
    expect(find.text('Échéance atteinte'), findsNothing);
  });

  // ── Menu d'actions sur la carte ──────────────────────────
  group('menu d\'actions de la carte', () {
    testWidgets('propose « Relancer le client » quand le projet a un engagement entrant', (tester) async {
      await _pump(tester, _avecProjet(qteLivree: 10)); // validateProforma crée l'entrant
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Relancer le client'), findsOneWidget);
      expect(find.text('Reporter l\'échéance'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Annuler le projet'), findsOneWidget);
      // Irréversible : ne doit jamais être à un clic de la carte.
      expect(find.text('Supprimer'), findsNothing);
    });

    testWidgets('n\'offre pas « Relancer le client » sans engagement entrant', (tester) async {
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Projet interne', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
        client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));
      await _pump(tester, s);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Relancer le client'), findsNothing);
    });

    testWidgets('« Relancer le client » bascule sur l\'écran Suivi', (tester) async {
      final s = _avecProjet(qteLivree: 10);
      await _pump(tester, s);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relancer le client'));
      await tester.pumpAndSettle();
      expect(s.screen, NavScreen.suivi);
    });

    testWidgets('« Annuler le projet » fait sortir la carte du Kanban', (tester) async {
      final s = _avecProjet();
      await _pump(tester, s);
      expect(find.text('Fourniture ACME'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler le projet'));
      await tester.pumpAndSettle();
      expect(find.text('Fourniture ACME'), findsNothing);
      expect(s.projets.first.annule, isTrue);
    });

    testWidgets('« Modifier » ouvre le formulaire d\'édition du projet', (tester) async {
      // Projet interne (pas de clientId) : le sélecteur client du
      // formulaire n'a alors qu'une seule entrée valide (« Projet
      // interne »), sans quoi `DropdownButtonFormField` exigerait un
      // client 5 inexistant dans `state.clients`.
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: 'Projet interne', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
        client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 12, 31)));
      await _pump(tester, s);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le projet'), findsOneWidget);
    });

    testWidgets('« Reporter l\'échéance » ouvre un calendrier et repousse la fin prévue',
        (tester) async {
      final s = _avecProjet(qteLivree: 10); // livré, rien encaissé, échéance dépassée → En révision
      await _pump(tester, s);
      expect(find.text('En révision'), findsWidgets);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reporter l\'échéance'));
      await tester.pumpAndSettle();

      // Le calendrier s'ouvre sur la fin prévue actuelle (30 juin 2026).
      // Avancer d'un mois et choisir le 15 donne une date déterministe
      // (15 juillet 2026), sans dépendre de l'horloge réelle — la règle
      // « ça sort d'En révision » est déjà couverte, déterministe elle
      // aussi, au niveau AppState (reporterEcheance, app_state_projets_test).
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(s.projets.first.finPrevue, DateTime(2026, 7, 15));
    });
  });
}
