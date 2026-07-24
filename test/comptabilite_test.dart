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

Expense dep(double amount, DateTime date, {String? numero}) => Expense(
    id: date.microsecondsSinceEpoch, date: date, label: 'd',
    amount: amount, category: 'Autre', factureNumero: numero);

void main() {
  test('factureHt = somme des lignes (HT)', () {
    expect(Comptabilite.factureHt(facture('F1', [l(2, 1000), l(1, 500)])), 2500);
  });

  test('beneficeFacture = HT - dépenses rattachées', () {
    final f = facture('F1', [l(1, 1000)]);
    final ex = [dep(300, DateTime(2026, 1, 1), numero: 'F1'), dep(999, DateTime(2026, 1, 1), numero: 'F2')];
    expect(Comptabilite.beneficeFacture(f, ex), 700);
  });

  test('totaux : le revenu ne compte que les factures encaissées', () {
    final factures = [
      facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026'),
      facture('F2', [l(1, 5000)]), // non encaissée -> exclue du revenu
    ];
    final ex = [dep(200, DateTime(2026, 1, 5))];
    final t = Comptabilite.totaux(factures, ex);
    expect(t.revenuHt, 1000);
    expect(t.depenses, 200);
    expect(t.benefice, 800);
  });

  test('bilanMensuel : revenu au mois d\'encaissement, dépenses à leur mois', () {
    final factures = [
      facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026'),
      facture('F2', [l(1, 2000)], encaissee: true, dateEnc: '10/02/2026'),
    ];
    final ex = [dep(300, DateTime(2026, 1, 20)), dep(500, DateTime(2026, 2, 2))];
    final rows = Comptabilite.bilanMensuel(factures, ex, const {}, const {});
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
    final factures = [facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/03/2026')];
    final ex = [dep(3000, DateTime(2026, 3, 5))];
    final rows = Comptabilite.bilanMensuel(factures, ex, const {}, const {});
    expect(rows.single.benefice, -2000);
    expect(rows.single.dime, 0);
  });

  test('libellé et clé de mois', () {
    expect(Comptabilite.monthKeyFromDdMmYyyy('05/07/2026'), '2026-07');
    expect(Comptabilite.monthKeyFromDate(DateTime(2026, 7, 5)), '2026-07');
    expect(Comptabilite.monthLabel('2026-07'), 'Juillet 2026');
  });

  test('statut de versement de la dîme propagé', () {
    final factures = [facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026')];
    final rows = Comptabilite.bilanMensuel(
        factures, const [], {'2026-01'}, {'2026-01': '03/02/2026'});
    expect(rows.single.dimePaid, isTrue);
    expect(rows.single.dimeDate, '03/02/2026');
  });
}
