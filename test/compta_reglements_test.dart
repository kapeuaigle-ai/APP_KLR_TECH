import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _entrant(double montant, List<Reglement> regs, {String tiers = 'ACME'}) =>
    Engagement(id: DateTime.now().microsecondsSinceEpoch, sens: 'entrant',
        tiers: tiers, montant: montant, echeance: DateTime(2026, 12, 31),
        reglements: regs);

Engagement _sortant(double montant, List<Reglement> regs, {String categorie = 'Transport'}) =>
    Engagement(id: DateTime.now().microsecondsSinceEpoch + 1, sens: 'sortant',
        tiers: 'Fournisseur', montant: montant, echeance: DateTime(2026, 12, 31),
        categorie: categorie, reglements: regs);

Reglement _r(double m, DateTime d) =>
    Reglement(id: d.microsecondsSinceEpoch, date: d, montant: m);

void main() {
  test('le revenu est la somme des règlements entrants, pas des montants attendus', () {
    final t = Comptabilite.totaux([
      _entrant(1000, [_r(400, DateTime(2026, 3, 3))]),
      _entrant(2000, []),
    ]);
    expect(t.revenuHt, 400);
    expect(t.depenses, 0);
    expect(t.benefice, 400);
  });

  test('les dépenses sont la somme des règlements sortants', () {
    final t = Comptabilite.totaux([
      _entrant(1000, [_r(1000, DateTime(2026, 3, 3))]),
      _sortant(600, [_r(600, DateTime(2026, 3, 5))]),
    ]);
    expect(t.revenuHt, 1000);
    expect(t.depenses, 600);
    expect(t.benefice, 400);
  });

  test('chaque règlement compte au mois de SA date', () {
    final rows = Comptabilite.bilanMensuel([
      _entrant(1000, [
        _r(400, DateTime(2026, 3, 3)),
        _r(600, DateTime(2026, 5, 9)),
      ]),
    ], const {}, const {});
    expect(Comptabilite.ligneMois('2026-03', rows)!.revenuHt, 400);
    expect(Comptabilite.ligneMois('2026-05', rows)!.revenuHt, 600);
    expect(Comptabilite.ligneMois('2026-04', rows), isNull);
  });

  test('la dîme vaut 10 % du bénéfice mensuel, et rien si le mois est déficitaire', () {
    final rows = Comptabilite.bilanMensuel([
      _entrant(1000, [_r(1000, DateTime(2026, 3, 3))]),
      _sortant(400, [_r(400, DateTime(2026, 3, 4))]),
      _sortant(500, [_r(500, DateTime(2026, 4, 4))]),
    ], const {}, const {});
    expect(Comptabilite.ligneMois('2026-03', rows)!.dime, closeTo(60, 0.001));
    expect(Comptabilite.ligneMois('2026-04', rows)!.dime, 0);
  });

  test('le rapport de période ne retient que les règlements dans les bornes', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 3, 1), fin: DateTime(2026, 3, 31),
      engagements: [
        _entrant(1000, [
          _r(400, DateTime(2026, 3, 3)),
          _r(600, DateTime(2026, 5, 9)),
        ]),
        _sortant(200, [_r(200, DateTime(2026, 3, 15))]),
      ],
    );
    expect(r.revenu, 400);
    expect(r.depenses, 200);
    expect(r.mouvements.length, 2);
    expect(r.depensesParCategorie['Transport'], 200);
  });

  test('les bornes du rapport sont incluses', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 3, 1), fin: DateTime(2026, 3, 31),
      engagements: [
        _entrant(300, [_r(100, DateTime(2026, 3, 1))]),
        _entrant(300, [_r(200, DateTime(2026, 3, 31))]),
      ],
    );
    expect(r.revenu, 300);
  });

  test('creancesEnCours est le reste dû des entrants non soldés', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [
        _entrant(1000, [_r(400, DateTime(2026, 3, 3))]),
        _entrant(500, [_r(500, DateTime(2026, 3, 3))]),
      ],
    );
    expect(r.creancesEnCours, 600);
  });

  test('un engagement annulé ne compte ni en attendu ni en flux', () {
    final annule = _entrant(1000, [])..annule = true;
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [annule],
    );
    expect(r.revenu, 0);
    expect(r.creancesEnCours, 0);
  });

  test('les mouvements sortent triés du plus ancien au plus récent', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [
        _entrant(900, [
          _r(300, DateTime(2026, 6, 1)),
          _r(300, DateTime(2026, 2, 1)),
          _r(300, DateTime(2026, 4, 1)),
        ]),
      ],
    );
    expect(r.mouvements.map((m) => m.date.month).toList(), [2, 4, 6]);
  });
}
