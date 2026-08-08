import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/documents_list_screen.dart';
import 'support/test_fonts.dart';

/// Aucun document ne pouvait être supprimé : la liste n'offrait que « Voir le
/// document », et `AppState` n'avait aucune méthode pour en retirer un.
///
/// La suppression ne peut pas être inconditionnelle pour autant. Valider une
/// proforma génère une facture, un bon de livraison et une créance ; effacer
/// isolément l'un des quatre laisse les trois autres mentir — la proforma
/// affirme que sa facture existe, la créance n'a plus de pièce. Le refus
/// renvoie donc vers « Dévalider » (`AppState.devaliderProforma`), la seule
/// voie qui défait l'ensemble.
DocumentItem _proforma({int id = 1, String statut = 'cours',
        String numero = 'KLR-P01-25072026', String date = '25/07/2026'}) =>
    DocumentItem(
      id: id, numero: numero, date: date, clientId: null,
      client: 'Client Test', objet: 'Matériel', montant: 100000, statut: statut,
      lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 100000)],
    );

void main() {
  setUpAll(loadTestFonts);

  group('AppState.supprimerDocument', () {
    test('une proforma en cours part, et le fil d\'activité en garde trace', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());

      expect(s.supprimerDocument('proforma', 1), SuppressionDocument.ok);
      expect(s.documents['proforma'], isEmpty);
      expect(s.activities.first.titre, contains('KLR-P01-25072026'));
    });

    test('une proforma annulée part aussi : rien ne dépend d\'elle', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma(statut: 'annulee'));

      expect(s.supprimerDocument('proforma', 1), SuppressionDocument.ok);
      expect(s.documents['proforma'], isEmpty);
    });

    test('une proforma validée est refusée : facture, BL et créance en dépendent',
        () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      s.validateProforma(1);

      expect(s.supprimerDocument('proforma', 1),
          SuppressionDocument.proformaValidee);
      expect(s.documents['proforma'], hasLength(1), reason: 'rien n\'a bougé');
      expect(s.documents['facture'], hasLength(1));
      expect(s.engagements, hasLength(1));
    });

    test('la facture et le BL générés sont refusés tant que la proforma est validée',
        () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      s.validateProforma(1);
      final facture = s.documents['facture']!.single;
      final bl = s.documents['bl']!.single;

      expect(s.supprimerDocument('facture', facture.id),
          SuppressionDocument.genereParProforma);
      expect(s.supprimerDocument('bl', bl.id),
          SuppressionDocument.genereParProforma);
      expect(s.documents['facture'], hasLength(1));
      expect(s.documents['bl'], hasLength(1));
    });

    test('dévalider rouvre la porte : la proforma redevient supprimable', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      s.validateProforma(1);
      s.devaliderProforma(1);

      expect(s.supprimerDocument('proforma', 1), SuppressionDocument.ok);
      expect(s.documents['proforma'], isEmpty);
      expect(s.documents['facture'], isEmpty, reason: 'partie avec la dévalidation');
      expect(s.engagements, isEmpty);
    });

    test('un id inconnu ne fait rien et le dit', () {
      final s = AppState()..viderDonnees();
      expect(s.supprimerDocument('proforma', 404), SuppressionDocument.introuvable);
    });
  });

  group('Écran Documents', () {
    Future<void> pump(WidgetTester tester, AppState state,
        {Size taille = const Size(1440, 900)}) async {
      tester.view.physicalSize = taille;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DocumentsListScreen())),
      ));
      await tester.pumpAndSettle();
    }

    /// La liste ne porte pas d'icône de suppression : la rangée d'actions
    /// n'ouvre que la fiche détail, d'où part la suppression — même parcours
    /// au bureau qu'au téléphone.
    Future<void> ouvrirFicheEtDemanderSuppression(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Voir le document'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
    }

    testWidgets('la liste n\'affiche aucune corbeille : seule la fiche supprime',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      await pump(tester, s);

      expect(find.byTooltip('Supprimer'), findsNothing);
      expect(find.byTooltip('Voir le document'), findsOneWidget);
    });

    testWidgets('la fiche détail supprime après confirmation', (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      await pump(tester, s);

      await ouvrirFicheEtDemanderSuppression(tester);

      expect(find.text('Supprimer ce document ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(s.documents['proforma'], isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« Annuler » dans la confirmation ne supprime rien',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      await pump(tester, s);

      await ouvrirFicheEtDemanderSuppression(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Annuler'));
      await tester.pumpAndSettle();

      expect(s.documents['proforma'], hasLength(1));
    });

    testWidgets('proforma validée : le refus explique qu\'il faut dévalider',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      s.validateProforma(1);
      await pump(tester, s);

      await ouvrirFicheEtDemanderSuppression(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(s.documents['proforma'], hasLength(1));
      expect(find.textContaining('Dévalider'), findsOneWidget);
    });

    testWidgets('sur téléphone, la suppression passe par la fiche détail',
        (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(_proforma());
      await pump(tester, s, taille: const Size(360, 900));

      // La carte entière ouvre le détail (pas de rangée d'icônes au doigt).
      await tester.tap(find.text('KLR-P01-25072026'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
      await tester.pumpAndSettle();

      expect(s.documents['proforma'], isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la liste montre le document le plus récent en premier',
        (tester) async {
      final s = AppState()..viderDonnees();
      // Volontairement enregistrées dans le désordre : c'est la date qui
      // décide, pas l'ordre d'insertion (l'ancien comportement).
      s.saveOrUpdateProforma(
          _proforma(id: 1, numero: 'KLR-P01-10072026', date: '10/07/2026'));
      s.saveOrUpdateProforma(
          _proforma(id: 2, numero: 'KLR-P01-25072026', date: '25/07/2026'));
      s.saveOrUpdateProforma(
          _proforma(id: 3, numero: 'KLR-P01-18072026', date: '18/07/2026'));
      await pump(tester, s);

      double y(String numero) => tester.getTopLeft(find.text(numero)).dy;
      expect(y('KLR-P01-25072026'), lessThan(y('KLR-P01-18072026')));
      expect(y('KLR-P01-18072026'), lessThan(y('KLR-P01-10072026')));
    });

    testWidgets('à date égale, le dernier créé passe devant', (tester) async {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(
          _proforma(id: 1, numero: 'KLR-P01-25072026', date: '25/07/2026'));
      s.saveOrUpdateProforma(
          _proforma(id: 2, numero: 'KLR-P02-25072026', date: '25/07/2026'));
      await pump(tester, s);

      expect(tester.getTopLeft(find.text('KLR-P02-25072026')).dy,
          lessThan(tester.getTopLeft(find.text('KLR-P01-25072026')).dy));
    });
  });
}
