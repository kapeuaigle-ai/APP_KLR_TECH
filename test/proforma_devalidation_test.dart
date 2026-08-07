import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

/// Une proforma validée a produit une facture, un BL et un engagement figés
/// sur son contenu (voir `AppState.validateProforma`). Ce fichier couvre le
/// défaut critique de la revue Lot D : l'éditer en place désynchronisait ces
/// trois documents en silence — le manager voyait un montant sur sa proforma,
/// son client un autre sur sa facture, et la comptabilité un troisième.
///
/// Le correctif tient en deux volets, testés séparément :
///  1. toute tentative de réécrire une proforma déjà validée est refusée
///     (`saveOrUpdateProforma`, `startEditProforma`, `setDocumentStatus`
///     sorti de 'validee') ;
///  2. une échappatoire explicite existe (`devaliderProforma`), gardée par
///     l'absence de tout règlement sur l'engagement généré.
void main() {
  DocumentItem proforma(int id, String numero, {
    String statut = 'cours', String client = 'ACME', int? clientId = 5,
    double pu = 1000, int qte = 1,
  }) =>
      DocumentItem(id: id, numero: numero, date: '25/07/2026', clientId: clientId,
          client: client, objet: 'PC', montant: pu * qte, statut: statut,
          lines: [LineItem(ref: '01', designation: 'Ordinateur', qte: qte, pu: pu)]);

  group('éditer une proforma validée est refusé', () {
    test('saveOrUpdateProforma : aucun changement, facture/BL/engagement intacts', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026'));
      s.validateProforma(1);

      final factureAvant = s.documents['facture']!.first;
      final engagementAvant = s.engagements.first;

      // Reproduction du bug : le manager rouvre la proforma, change le
      // client et les lignes (1000 → 5000), et « enregistre ».
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026',
          statut: 'validee', client: 'AUTRE CLIENT', clientId: 9, pu: 5000));

      final p = s.documents['proforma']!.firstWhere((d) => d.id == 1);
      final facture = s.documents['facture']!.first;
      final engagement = s.engagements.first;

      // Rien n'a bougé : la proforma garde son contenu d'origine...
      expect(p.client, 'ACME');
      expect(p.montant, 1000);
      // ...et la facture/l'engagement, déjà générés, restent identiques.
      expect(facture.montant, factureAvant.montant);
      expect(facture.client, factureAvant.client);
      expect(engagement.montant, engagementAvant.montant);
      expect(engagement.tiers, engagementAvant.tiers);

      // L'invariant central de cette revue : les trois montants coïncident
      // toujours pour une proforma validée.
      final total = p.lines.fold(0.0, (sum, l) => sum + l.total);
      expect(facture.montant, total);
      expect(engagement.montant, total);
    });

    test('startEditProforma refuse d\'ouvrir l\'écran sur une proforma validée', () {
      final s = AppState()..viderDonnees();
      final doc = proforma(1, 'KLR-P01-25072026');
      s.saveOrUpdateProforma(doc);
      s.validateProforma(1);
      final validee = s.documents['proforma']!.first;

      s.startEditProforma(validee);

      expect(s.creating, isFalse);
      expect(s.editingProforma, isNull);
    });

    test('setDocumentStatus refuse de sortir une proforma validée de \'validee\'', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026'));
      s.validateProforma(1);

      s.setDocumentStatus('proforma', 1, 'cours');
      expect(s.documents['proforma']!.first.statut, 'validee');

      s.setDocumentStatus('proforma', 1, 'annulee');
      expect(s.documents['proforma']!.first.statut, 'validee');

      // La facture, le BL et l'engagement restent en place — aucun orphelin.
      expect(s.documents['facture']!.length, 1);
      expect(s.documents['bl']!.length, 1);
      expect(s.engagements.length, 1);
    });

    test('setDocumentStatus continue de fonctionner hors de \'validee\'', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026', statut: 'cours'));

      s.setDocumentStatus('proforma', 1, 'annulee');
      expect(s.documents['proforma']!.first.statut, 'annulee');

      s.setDocumentStatus('proforma', 1, 'cours');
      expect(s.documents['proforma']!.first.statut, 'cours');
    });
  });

  group('devaliderProforma', () {
    test('sans règlement : retire facture, BL et engagement, repasse en cours', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026'));
      s.validateProforma(1);
      expect(s.documents['facture']!.length, 1);
      expect(s.documents['bl']!.length, 1);
      expect(s.engagements.length, 1);
      final avantActivites = s.activities.length;

      final ok = s.devaliderProforma(1);

      expect(ok, isTrue);
      expect(s.documents['proforma']!.first.statut, 'cours');
      expect(s.documents['facture'], isEmpty);
      expect(s.documents['bl'], isEmpty);
      expect(s.engagements, isEmpty);
      expect(s.activities.length, avantActivites + 1);
      expect(s.activities.first.titre, contains('dévalidée'));
    });

    test('refusée si un règlement existe : rien ne change', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026'));
      s.validateProforma(1);
      final engagementId = s.engagements.first.id;
      s.ajouterReglement(engagementId, 400, DateTime(2026, 7, 26));

      expect(s.peutDevaliderProforma(1), isFalse);
      final ok = s.devaliderProforma(1);

      expect(ok, isFalse);
      expect(s.documents['proforma']!.first.statut, 'validee');
      expect(s.documents['facture'], hasLength(1));
      expect(s.documents['bl'], hasLength(1));
      expect(s.engagements, hasLength(1));
      expect(s.engagements.first.regle, 400); // le règlement reste, intact
    });

    test('peutDevaliderProforma : false pour une proforma non validée', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026', statut: 'cours'));
      expect(s.peutDevaliderProforma(1), isFalse);
    });

    test('devaliderProforma : no-op sur une proforma déjà en cours', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026', statut: 'cours'));
      expect(s.devaliderProforma(1), isFalse);
      expect(s.documents['proforma']!.first.statut, 'cours');
    });

    test('re-valider après dévalidation : exactement une facture, un BL, un engagement, '
        'même numéro qu\'avant', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026'));
      s.validateProforma(1);
      final numeroFactureAvant = s.documents['facture']!.first.numero;
      final numeroBlAvant = s.documents['bl']!.first.numero;

      s.devaliderProforma(1);
      s.validateProforma(1);

      expect(s.documents['facture'], hasLength(1));
      expect(s.documents['bl'], hasLength(1));
      expect(s.engagements, hasLength(1));
      expect(s.documents['facture']!.first.numero, numeroFactureAvant);
      expect(s.documents['bl']!.first.numero, numeroBlAvant);
      expect(s.documents['proforma']!.first.statut, 'validee');
    });

    test('dévalider puis modifier puis re-valider : la nouvelle facture reflète '
        'le nouveau contenu, l\'invariant tient toujours', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026', pu: 1000));
      s.validateProforma(1);

      s.devaliderProforma(1); // repasse en 'cours' : de nouveau modifiable
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026',
          statut: 'cours', client: 'NOUVEAU CLIENT', clientId: 12, pu: 5000));
      s.validateProforma(1);

      final p = s.documents['proforma']!.first;
      final facture = s.documents['facture']!.first;
      final engagement = s.engagements.first;
      final total = p.lines.fold(0.0, (sum, l) => sum + l.total);

      expect(p.client, 'NOUVEAU CLIENT');
      expect(total, 5000);
      expect(facture.montant, total);
      expect(engagement.montant, total);
      expect(facture.client, 'NOUVEAU CLIENT');
    });
  });

  group('invariant : facture, engagement et proforma coïncident toujours', () {
    test('pour plusieurs proformas validées, avant et après un cycle dévalider/revalider', () {
      final s = AppState()..viderDonnees();
      s.saveOrUpdateProforma(proforma(1, 'KLR-P01-25072026', pu: 1000));
      s.saveOrUpdateProforma(proforma(2, 'KLR-P02-25072026', pu: 2500, qte: 2));
      s.validateProforma(1);
      s.validateProforma(2);

      void verifierInvariant() {
        for (final p in s.documents['proforma']!.where((d) => d.statut == 'validee')) {
          final gen = s.docsGeneresPourProforma(p);
          final total = p.lines.fold(0.0, (sum, l) => sum + l.total);
          expect(gen.facture, isNotNull, reason: 'proforma ${p.numero} sans facture');
          expect(gen.engagement, isNotNull, reason: 'proforma ${p.numero} sans engagement');
          expect(gen.facture!.montant, total, reason: 'facture ${p.numero}');
          expect(gen.engagement!.montant, total, reason: 'engagement ${p.numero}');
        }
      }

      verifierInvariant();

      s.devaliderProforma(1);
      s.validateProforma(1);
      verifierInvariant();
    });
  });
}
