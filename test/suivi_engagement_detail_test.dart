import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

// Une créance dont la description et le règlement sont tronqués dans le
// tableau — c'est exactement le cas rapporté : « Réglé 1 000 000 FCFA · re… ».
// La boîte « Détail » doit donner accès à tout ce que la ligne ne montre pas.
Engagement _creance({
  int id = 1,
  String tiers = 'ACME SARL',
  String description = '',
  double montant = 1000000,
  DateTime? echeance,
  int? projetId,
  int? clientId,
  String? documentNumero,
  List<Reglement> reglements = const [],
}) =>
    Engagement(
      id: id, sens: 'entrant', tiers: tiers, description: description,
      montant: montant, echeance: echeance ?? DateTime(2026, 9, 1),
      projetId: projetId, clientId: clientId, documentNumero: documentNumero,
      reglements: reglements,
    );

Projet _projet({int id = 1, String nom = 'Fourniture matériel', int? clientId}) => Projet(
      id: id, nom: nom,
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: clientId, client: clientId == null ? '' : 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
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

  /// Ouvre le menu d'actions de la première créance affichée, puis le
  /// « Détail ».
  Future<void> ouvrirDetail(WidgetTester tester) async {
    await tester.tap(find.text('Engagements'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Détail'));
    await tester.pumpAndSettle();
  }

  group('menu d\'actions', () {
    testWidgets('propose une entrée « Détail »', (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance());
      await pump(tester, state);

      await tester.tap(find.text('Engagements'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz).first);
      await tester.pumpAndSettle();

      expect(find.text('Détail'), findsOneWidget);
    });
  });

  group('boîte de détail', () {
    testWidgets('affiche la description complète, sans troncature', (tester) async {
      final longue = 'Fourniture et pose de matériel réseau pour le site principal, '
          'incluant câblage structuré, baies de brassage, onduleurs et mise en '
          'service complète avec tests de bout en bout sur chaque liaison installée.';
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance(description: longue));
      await pump(tester, state);

      await ouvrirDetail(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(longue)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste tous les règlements, du plus ancien au plus récent, avec date et moyen',
        (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance(montant: 500000, reglements: [
        Reglement(id: 1, date: DateTime(2026, 5, 20), montant: 200000, moyen: 'virement'),
        Reglement(id: 2, date: DateTime(2026, 4, 10), montant: 150000, moyen: 'especes'),
      ]));
      await pump(tester, state);

      await ouvrirDetail(tester);

      final ligneAncienne =
          '${Fmt.jour(DateTime(2026, 4, 10))} · ${Fmt.money(150000)} · Espèces';
      final ligneRecente =
          '${Fmt.jour(DateTime(2026, 5, 20))} · ${Fmt.money(200000)} · Virement';

      final ancienne = find.descendant(of: find.byType(Dialog), matching: find.text(ligneAncienne));
      final recente = find.descendant(of: find.byType(Dialog), matching: find.text(ligneRecente));
      expect(ancienne, findsOneWidget);
      expect(recente, findsOneWidget);

      // Oldest first : le règlement d'avril doit apparaître au-dessus de
      // celui de mai.
      expect(tester.getCenter(ancienne).dy, lessThan(tester.getCenter(recente).dy));
    });

    testWidgets('indique clairement l\'absence de règlement', (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance());
      await pump(tester, state);

      await ouvrirDetail(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Aucun règlement enregistré.')),
        findsOneWidget,
      );
    });

    testWidgets('affiche le nom du projet lié', (tester) async {
      final state = AppState()..viderDonnees();
      state.addProjet(_projet(id: 7, nom: 'Rénovation agence Nord'));
      state.addEngagement(_creance(projetId: 7));
      await pump(tester, state);

      await ouvrirDetail(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Rénovation agence Nord')),
        findsOneWidget,
      );
    });

    testWidgets('affiche le client lié quand clientId est renseigné', (tester) async {
      final state = AppState()..viderDonnees();
      const client = Client(
        id: 9, initials: 'AS', color: Colors.blue, name: 'Advans SA',
        contact: 'M. Koné', email: 'contact@advans.ci', phone: '0102030405',
        totalFacture: 0,
      );
      state.addClient(client);
      state.addEngagement(_creance(clientId: client.id));
      await pump(tester, state);

      await ouvrirDetail(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(client.name)),
        findsOneWidget,
      );
    });

    testWidgets('affiche le reste dû', (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance(montant: 1000000, reglements: [
        Reglement(id: 1, date: DateTime(2026, 5, 1), montant: 400000, moyen: 'especes'),
      ]));
      await pump(tester, state);

      await ouvrirDetail(tester);

      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(Fmt.money(600000))),
        findsOneWidget,
      );
    });

    testWidgets('ne propose aucune action destructive ou de modification', (tester) async {
      final state = AppState()..viderDonnees();
      state.addEngagement(_creance());
      await pump(tester, state);

      await ouvrirDetail(tester);

      final dansLaBoite = find.byType(Dialog);
      expect(find.descendant(of: dansLaBoite, matching: find.text('Supprimer')), findsNothing);
      expect(find.descendant(of: dansLaBoite, matching: find.text('Annuler l\'engagement')), findsNothing);
      expect(find.descendant(of: dansLaBoite, matching: find.text('Gérer les règlements')), findsNothing);
      expect(find.descendant(of: dansLaBoite, matching: find.byIcon(Icons.delete_outline)), findsNothing);
      expect(find.descendant(of: dansLaBoite, matching: find.text('Fermer')), findsOneWidget);
    });
  });
}
