import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// « Relancer le client » ne doit apparaître que s'il reste réellement
/// quelque chose à percevoir ET que le moment de réclamer est venu — soit
/// l'échéance du projet est dépassée (le motif même de « En révision »),
/// soit une créance est elle-même échue alors que le projet, lui, tient
/// encore ses délais. Chaque test ci-dessous pointe une ligne du tableau de
/// la demande de correction.
void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, AppState state) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> ouvrirMenu(WidgetTester tester, String nomProjet) async {
    final carte = find.ancestor(of: find.text(nomProjet), matching: find.byType(InkWell));
    final bouton = find.descendant(of: carte, matching: find.byIcon(Icons.more_vert));
    await tester.tap(bouton);
    await tester.pumpAndSettle();
  }

  /// Projet avec un engagement entrant unique, dont l'échéance (indépendante
  /// de la fin prévue du projet) et le montant réglé sont contrôlés
  /// séparément — c'est ce qui permet de distinguer « le projet est en
  /// retard » de « la créance est en retard ».
  AppState projetAvecCreance({
    required String nom,
    required DateTime finPrevueProjet,
    required String echeanceCreance,
    double montant = 1000,
    double regle = 0,
  }) {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: nom, typeId: 'interne', clientId: 5, client: 'ACME',
      debut: DateTime(2020, 1, 1), finPrevue: finPrevueProjet));
    s.setAvancementManuel(1, 0.5); // ni 0 ni 1 : ne tombe jamais dans « À démarrer »/« Terminé ».
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-01012020', date: echeanceCreance, clientId: 5,
      client: 'ACME', objet: 'Prestation', montant: montant, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'X', designation: 'X', qte: 1, pu: montant)]));
    s.validateProforma(1);
    if (regle > 0) s.ajouterReglement(s.engagements.first.id, regle, DateTime(2020, 1, 2));
    return s;
  }

  testWidgets('Terminé, tout encaissé : pas de « Relancer le client »', (tester) async {
    final s = projetAvecCreance(
      nom: 'Contrat soldé',
      finPrevueProjet: DateTime(2020, 6, 30), // passée : sans incidence, tout est réglé.
      echeanceCreance: '01/01/2020',
      montant: 1000, regle: 1000,
    );
    await pump(tester, s);
    await ouvrirMenu(tester, 'Contrat soldé');
    expect(find.text('Relancer le client'), findsNothing);
  });

  testWidgets('En révision, reste dû : « Relancer le client » proposé', (tester) async {
    final s = projetAvecCreance(
      nom: 'Contrat en révision',
      finPrevueProjet: DateTime(2020, 6, 30), // dépassée → En révision.
      echeanceCreance: '01/01/2020',
      montant: 1000, regle: 0,
    );
    await pump(tester, s);
    await ouvrirMenu(tester, 'Contrat en révision');
    expect(find.text('Relancer le client'), findsOneWidget);
  });

  testWidgets('En cours, échéance du projet devant, créance à jour : pas de relance',
      (tester) async {
    final s = projetAvecCreance(
      nom: 'Contrat en cours à jour',
      finPrevueProjet: DateTime(2035, 1, 1), // future → toujours En cours.
      echeanceCreance: '01/01/2035', // la créance n'est pas encore due non plus.
      montant: 1000, regle: 0,
    );
    await pump(tester, s);
    await ouvrirMenu(tester, 'Contrat en cours à jour');
    expect(find.text('Relancer le client'), findsNothing,
        reason: 'trop tôt pour réclamer : ni le projet ni la créance ne sont en retard');
  });

  testWidgets('En cours, échéance du projet devant, créance échue : relance proposée',
      (tester) async {
    final s = projetAvecCreance(
      nom: 'Contrat en cours en retard de paiement',
      finPrevueProjet: DateTime(2035, 1, 1), // le projet, lui, tient ses délais.
      echeanceCreance: '01/01/2020', // mais la créance est déjà échue.
      montant: 1000, regle: 0,
    );
    await pump(tester, s);
    await ouvrirMenu(tester, 'Contrat en cours en retard de paiement');
    expect(find.text('Relancer le client'), findsOneWidget,
        reason: 'c\'est le paiement qui est en retard, pas le projet');
  });

  testWidgets('À démarrer, aucune créance : pas de relance', (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Idée sans client', typeId: 'interne', clientId: null,
      client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2035, 1, 1)));
    await pump(tester, s);
    await ouvrirMenu(tester, 'Idée sans client');
    expect(find.text('Relancer le client'), findsNothing);
  });
}
