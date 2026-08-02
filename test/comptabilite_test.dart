import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

DocumentItem facture(String numero, List<LineItem> lines,
        {bool encaissee = false, String? dateEnc}) =>
    DocumentItem(
      id: numero.hashCode, numero: numero, date: '01/01/2026', clientId: 0,
      client: 'C', objet: 'O', montant: 0, statut: 'cours',
      lines: lines, encaissee: encaissee, dateEncaissement: dateEnc,
    );

LineItem l(int qte, double pu) => LineItem(ref: '01', designation: 'x', qte: qte, pu: pu);

Reglement reg(double montant, DateTime date) =>
    Reglement(id: date.microsecondsSinceEpoch, date: date, montant: montant);

/// Une facture encaissée devient un engagement entrant, rattaché à son
/// numéro de document, soldé par un unique règlement à la date d'encaissement.
Engagement factureEncaissee(String numero, double montant, DateTime dateEnc) =>
    Engagement(
      id: numero.hashCode, sens: 'entrant', tiers: 'C', montant: montant,
      echeance: dateEnc, documentNumero: numero,
      reglements: [reg(montant, dateEnc)],
    );

/// Une dépense au comptant devient un engagement sortant, réglé le jour même,
/// éventuellement rattaché à une facture fournisseur.
Engagement dep(double montant, DateTime date, {String? numero}) => Engagement(
    id: date.microsecondsSinceEpoch, sens: 'sortant', tiers: 'F',
    montant: montant, echeance: date, categorie: 'Autres',
    documentNumero: numero, reglements: [reg(montant, date)]);

Engagement creance(double montant, {String? regleLe}) => Engagement(
    id: montant.toInt(), sens: 'entrant', tiers: 'T',
    montant: montant, echeance: DateTime(2026, 1, 1),
    reglements: regleLe == null ? [] : [reg(montant, Comptabilite.parseJour(regleLe)!)]);

Engagement dette(double montant, {String? regleLe}) => Engagement(
    id: -montant.toInt(), sens: 'sortant', tiers: 'F',
    montant: montant, echeance: DateTime(2026, 1, 1),
    reglements: regleLe == null ? [] : [reg(montant, Comptabilite.parseJour(regleLe)!)]);

void main() {
  test('factureHt = somme des lignes (HT)', () {
    expect(Comptabilite.factureHt(facture('F1', [l(2, 1000), l(1, 500)])), 2500);
  });

  test('beneficeFacture = HT - dépenses rattachées', () {
    final f = facture('F1', [l(1, 1000)]);
    final ex = [
      dep(300, DateTime(2026, 1, 1), numero: 'F1'),
      dep(999, DateTime(2026, 1, 1), numero: 'F2'),
    ];
    expect(Comptabilite.beneficeFacture(f, ex), 700);
  });

  test('totaux : le revenu ne compte que les factures encaissées', () {
    final engagements = [
      factureEncaissee('F1', 1000, DateTime(2026, 1, 10)),
      // F2 non encaissée -> aucun règlement, donc exclue du revenu
      Engagement(id: 2, sens: 'entrant', tiers: 'C', montant: 5000,
          echeance: DateTime(2026, 1, 1), documentNumero: 'F2'),
      dep(200, DateTime(2026, 1, 5)),
    ];
    final t = Comptabilite.totaux(engagements);
    expect(t.revenuHt, 1000);
    expect(t.depenses, 200);
    expect(t.benefice, 800);
  });

  test('bilanMensuel : revenu au mois d\'encaissement, dépenses à leur mois', () {
    final engagements = [
      factureEncaissee('F1', 1000, DateTime(2026, 1, 10)),
      factureEncaissee('F2', 2000, DateTime(2026, 2, 10)),
      dep(300, DateTime(2026, 1, 20)),
      dep(500, DateTime(2026, 2, 2)),
    ];
    final rows = Comptabilite.bilanMensuel(engagements, const {}, const {});
    expect(rows.length, 2);
    expect(rows[0].monthKey, '2026-01');
    expect(rows[0].revenuHt, 1000);
    expect(rows[0].depenses, 300);
    expect(rows[0].benefice, 700);
    expect(rows[0].dime, closeTo(70, 0.001));
    expect(rows[1].monthKey, '2026-02');
    expect(rows[1].dime, closeTo(150, 0.001));
  });

  test('dîme = 0 sur un mois en perte', () {
    final engagements = [
      factureEncaissee('F1', 1000, DateTime(2026, 3, 10)),
      dep(3000, DateTime(2026, 3, 5)),
    ];
    final rows = Comptabilite.bilanMensuel(engagements, const {}, const {});
    expect(rows.single.benefice, -2000);
    expect(rows.single.dime, 0);
  });

  test('libellé et clé de mois', () {
    expect(Comptabilite.monthKeyFromDdMmYyyy('05/07/2026'), '2026-07');
    expect(Comptabilite.monthKeyFromDate(DateTime(2026, 7, 5)), '2026-07');
    expect(Comptabilite.monthLabel('2026-07'), 'Juillet 2026');
  });

  test('statut de versement de la dîme propagé', () {
    final engagements = [factureEncaissee('F1', 1000, DateTime(2026, 1, 10))];
    final rows = Comptabilite.bilanMensuel(
        engagements, {'2026-01'}, {'2026-01': '03/02/2026'});
    expect(rows.single.dimePaid, isTrue);
    expect(rows.single.dimeDate, '03/02/2026');
  });

  // ── Engagements (dettes & créances) en comptabilité ──────
  group('engagements', () {
    test('une créance validée entre en revenu, une créance en cours non', () {
      final t = Comptabilite.totaux([
        creance(1000, regleLe: '10/01/2026'),
        creance(9999), // en cours -> hors comptabilité
      ]);
      expect(t.revenuHt, 1000);
      expect(t.benefice, 1000);
    });

    test('une dette validée entre en dépense', () {
      final t = Comptabilite.totaux([
        dette(400, regleLe: '10/01/2026'),
        dette(7777), // en cours -> hors comptabilité
      ]);
      expect(t.depenses, 400);
      expect(t.benefice, -400);
    });

    test('rattachement au mois du règlement, pas à celui de l\'échéance', () {
      // échéance en janvier (cf. helper), réglée en mars.
      final rows = Comptabilite.bilanMensuel(
          [creance(2000, regleLe: '05/03/2026')], const {}, const {});
      expect(rows.single.monthKey, '2026-03');
      expect(rows.single.revenuHt, 2000);
      expect(rows.single.dime, closeTo(200, 0.001));
    });

    test('créance et dette du même mois se compensent dans le bénéfice', () {
      final rows = Comptabilite.bilanMensuel([
        creance(5000, regleLe: '05/04/2026'),
        dette(2000, regleLe: '20/04/2026'),
      ], const {}, const {});
      expect(rows.single.revenuHt, 5000);
      expect(rows.single.depenses, 2000);
      expect(rows.single.benefice, 3000);
    });

    test('engagement sans règlement : ignoré', () {
      final e = creance(1000);
      expect(Comptabilite.totaux([e]).revenuHt, 0);
      expect(Comptabilite.bilanMensuel([e], const {}, const {}), isEmpty);
    });

    test('les créances s\'ajoutent aux factures encaissées du même mois', () {
      final engagements = [
        factureEncaissee('F1', 1500, DateTime(2026, 5, 10)),
        creance(500, regleLe: '25/05/2026'),
      ];
      final rows = Comptabilite.bilanMensuel(engagements, const {}, const {});
      expect(rows.single.revenuHt, 2000);
    });
  });

  // ── Clôture mensuelle ────────────────────────────────────
  group('moisAClore', () {
    test('premier lancement (aucun mois connu) : rien à clôturer', () {
      expect(Comptabilite.moisAClore(null, DateTime(2026, 8, 1)), isEmpty);
    });

    test('toujours dans le même mois : rien à clôturer', () {
      expect(Comptabilite.moisAClore('2026-08', DateTime(2026, 8, 31)), isEmpty);
    });

    test('mois suivant : le mois écoulé est à clôturer', () {
      expect(Comptabilite.moisAClore('2026-07', DateTime(2026, 8, 1)), ['2026-07']);
    });

    test('app non ouverte pendant plusieurs mois : tous sont clôturés', () {
      expect(Comptabilite.moisAClore('2026-07', DateTime(2026, 10, 15)),
          ['2026-07', '2026-08', '2026-09']);
    });

    test('passage d\'année', () {
      expect(Comptabilite.moisAClore('2026-11', DateTime(2027, 1, 3)),
          ['2026-11', '2026-12']);
    });

    test('horloge en arrière : rien à clôturer', () {
      expect(Comptabilite.moisAClore('2026-09', DateTime(2026, 7, 1)), isEmpty);
    });
  });

  test('ligneMois retrouve le bilan d\'un mois donné', () {
    final engagements = [factureEncaissee('F1', 1000, DateTime(2026, 1, 10))];
    final rows = Comptabilite.bilanMensuel(engagements, const {}, const {});
    expect(Comptabilite.ligneMois('2026-01', rows)?.revenuHt, 1000);
    expect(Comptabilite.ligneMois('2026-02', rows), isNull);
  });
}
