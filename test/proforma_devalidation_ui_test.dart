import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/documents_list_screen.dart';
import 'support/test_fonts.dart';

/// Couverture UI du défaut critique (revue Lot D) : une proforma validée ne
/// s'ouvre plus en édition, et « CHANGER LE STATUT » ne permet plus d'en
/// sortir directement — seule « Dévalider » le peut, tant qu'aucun règlement
/// n'existe sur la créance générée. Couvre à la fois la carte téléphone et le
/// tableau bureau : `_DocActions.showDetails`/`showFullDocument` sont
/// partagés entre les deux (`_DocCard` et `_DocRow` appellent tous deux
/// `actions.showDetails`), donc un seul chemin logique à vérifier deux fois
/// pour la mise en page.
void main() {
  setUpAll(loadTestFonts);

  void desktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget host(AppState state) => ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DocumentsListScreen())),
      );

  AppState stateAvecProformaValidee() {
    final state = AppState()..viderDonnees();
    state.saveOrUpdateProforma(DocumentItem(
        id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026', clientId: 5,
        client: 'ACME', objet: 'PC', montant: 1000, statut: 'cours',
        lines: [LineItem(ref: '01', designation: 'Ordinateur', qte: 1, pu: 1000)]));
    state.validateProforma(900);
    return state;
  }

  // Ouvre la fiche détail d'un document depuis la table (bureau) ou la carte
  // (téléphone) — seul le point d'entrée diffère, `showDetails` est partagé.
  Future<void> ouvrirFicheDetail(WidgetTester tester, {required bool surPhone}) async {
    if (surPhone) {
      await tester.tap(find.text('KLR-P01-25072026'));
    } else {
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined).first);
    }
    await tester.pumpAndSettle();
  }

  for (final layout in [('bureau', false), ('téléphone', true)]) {
    final label = layout.$1;
    final surPhone = layout.$2;

    group('« CHANGER LE STATUT » sur une proforma validée — $label', () {
      testWidgets('les boutons rapides cours/annulée disparaissent, « Dévalider » apparaît',
          (tester) async {
        surPhone ? phone(tester) : desktop(tester);
        addTearDown(tester.view.reset);

        final state = stateAvecProformaValidee();
        await tester.pumpWidget(host(state));
        await tester.pumpAndSettle();

        await ouvrirFicheDetail(tester, surPhone: surPhone);

        expect(find.text('CHANGER LE STATUT'), findsNothing);
        expect(find.text('PROFORMA VALIDÉE'), findsOneWidget);
        expect(find.text('Dévalider'), findsOneWidget);
        // Les anciens boutons rapides de statut ont disparu — recherche
        // bornée à la fiche (« En cours » figure aussi dans les puces de
        // filtre de la page, hors de propos ici).
        final dansLaFiche = find.descendant(
            of: find.byType(AlertDialog), matching: find.text('En cours'));
        expect(dansLaFiche, findsNothing);
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Annulée')),
            findsNothing);
      });

      testWidgets('Dévalider : la confirmation nomme la facture, le BL et la créance',
          (tester) async {
        surPhone ? phone(tester) : desktop(tester);
        addTearDown(tester.view.reset);

        final state = stateAvecProformaValidee();
        final factureNumero = state.documents['facture']!.first.numero;
        final blNumero = state.documents['bl']!.first.numero;

        await tester.pumpWidget(host(state));
        await tester.pumpAndSettle();
        await ouvrirFicheDetail(tester, surPhone: surPhone);

        await tester.tap(find.text('Dévalider'));
        await tester.pumpAndSettle();

        expect(find.text('Dévalider cette proforma ?'), findsOneWidget);
        expect(find.textContaining(factureNumero), findsOneWidget);
        expect(find.textContaining(blNumero), findsOneWidget);
        // Rien n'a encore changé avant confirmation.
        expect(state.documents['proforma']!.first.statut, 'validee');
        expect(state.documents['facture'], hasLength(1));

        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(state.documents['facture'], hasLength(1),
            reason: 'annuler la confirmation ne doit rien retirer');
      });

      testWidgets('Dévalider puis confirmer : proforma repasse en cours, facture/BL/créance retirés',
          (tester) async {
        surPhone ? phone(tester) : desktop(tester);
        addTearDown(tester.view.reset);

        final state = stateAvecProformaValidee();
        await tester.pumpWidget(host(state));
        await tester.pumpAndSettle();
        await ouvrirFicheDetail(tester, surPhone: surPhone);

        await tester.tap(find.text('Dévalider'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dévalider').last);
        await tester.pumpAndSettle();

        expect(state.documents['proforma']!.first.statut, 'cours');
        expect(state.documents['facture'], isEmpty);
        expect(state.documents['bl'], isEmpty);
        expect(state.engagements, isEmpty);
      });

      testWidgets('un règlement déjà enregistré bloque la dévalidation, sans bouton',
          (tester) async {
        surPhone ? phone(tester) : desktop(tester);
        addTearDown(tester.view.reset);

        final state = stateAvecProformaValidee();
        state.ajouterReglement(state.engagements.first.id, 300, DateTime(2026, 7, 26));

        await tester.pumpWidget(host(state));
        await tester.pumpAndSettle();
        await ouvrirFicheDetail(tester, surPhone: surPhone);

        expect(find.text('Dévalider'), findsNothing);
        expect(find.textContaining('Dévalidation impossible'), findsOneWidget);
      });
    });
  }

  // « Modifier » vit dans `showFullDocument`, qui n'a pas de branche
  // isPhone/bureau distincte (une seule mise en page, réutilisée quelle que
  // soit l'entrée) : pas besoin de la dupliquer par taille d'écran. Testée à
  // une largeur bureau confortable — sa rangée d'actions (Modifier /
  // Imprimer / Télécharger) déborde déjà à 360 px sur un document ordinaire,
  // avant même ce correctif ; hors sujet ici, signalé séparément.
  group('« Modifier » sur une proforma validée', () {
    testWidgets('explique le verrou au lieu d\'ouvrir l\'écran d\'édition', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = stateAvecProformaValidee();
      await tester.pumpWidget(host(state));
      await tester.pumpAndSettle();
      await ouvrirFicheDetail(tester, surPhone: false);

      await tester.tap(find.text('Voir le document'));
      await tester.pumpAndSettle();

      expect(find.text('Modifier'), findsOneWidget);
      await tester.tap(find.text('Modifier'));
      await tester.pump(); // affiche le SnackBar sans attendre sa disparition

      expect(find.textContaining('ne peut plus être modifiée'), findsOneWidget);
      // L'écran d'édition ne s'est pas ouvert.
      expect(state.creating, isFalse);
      expect(state.editingProforma, isNull);
    });
  });

  group('« Modifier » sur une proforma en cours (référence, non régressée)', () {
    testWidgets('ouvre bien l\'écran d\'édition', (tester) async {
      desktop(tester);
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.saveOrUpdateProforma(DocumentItem(
          id: 901, numero: 'KLR-P02-25072026', date: '25/07/2026', clientId: 5,
          client: 'ACME', objet: 'PC', montant: 1000, statut: 'cours',
          lines: [LineItem(ref: '01', designation: 'Ordinateur', qte: 1, pu: 1000)]));

      await tester.pumpWidget(host(state));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir le document'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();

      expect(state.creating, isTrue);
      expect(state.editingProforma?.id, 901);
    });
  });
}
