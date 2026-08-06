import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _e(String sens, double montant, DateTime echeance,
        {List<Reglement>? regs, int? projetId, bool annule = false}) =>
    Engagement(
      id: echeance.microsecondsSinceEpoch, sens: sens, tiers: 'T',
      montant: montant, echeance: echeance, projetId: projetId,
      reglements: regs, annule: annule);

Reglement _r(double m, DateTime d) => Reglement(id: 1, date: d, montant: m);

void main() {
  test('la trésorerie prévisionnelle est le reste dû des entrants, par échéance', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('entrant', 1000, DateTime(2026, 5, 31), regs: [_r(400, DateTime(2026, 4, 1))]),
        _e('entrant', 2000, DateTime(2026, 6, 30)),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t, hasLength(2));
    expect(t[0].echeance, DateTime(2026, 5, 31));
    expect(t[0].montant, 600);
    expect(t[1].montant, 2000);
  });

  test('les entrants soldés n\'apparaissent pas', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [_e('entrant', 1000, DateTime(2026, 5, 31), regs: [_r(1000, DateTime(2026, 4, 1))])],
      now: DateTime(2026, 4, 1),
    );
    expect(t, isEmpty);
  });

  test('les sortants et les annulés sont exclus', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('sortant', 900, DateTime(2026, 5, 31)),
        _e('entrant', 700, DateTime(2026, 5, 31), annule: true),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t, isEmpty);
  });

  test('les échéances sortent triées, de la plus proche à la plus lointaine', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('entrant', 100, DateTime(2026, 8, 1)),
        _e('entrant', 200, DateTime(2026, 5, 1)),
        _e('entrant', 300, DateTime(2026, 6, 1)),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t.map((x) => x.montant).toList(), [200, 300, 100]);
  });

  test('une échéance dépassée est signalée en retard', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [_e('entrant', 500, DateTime(2026, 3, 1))],
      now: DateTime(2026, 4, 1),
    );
    expect(t.single.enRetard, isTrue);
  });

  test('la marge d\'un projet est encaissé moins décaissé', () {
    final a = Avancement.calculer(
      projet: Projet(id: 1, nom: 'P', type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: 5,
          client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)),
      mode: ModeAvancement.quantites,
      proformas: const [],
      engagements: [
        _e('entrant', 3000, DateTime(2026, 6, 1), regs: [_r(3000, DateTime(2026, 4, 1))], projetId: 1),
        _e('sortant', 1800, DateTime(2026, 4, 5), regs: [_r(1800, DateTime(2026, 4, 5))], projetId: 1),
      ],
      now: DateTime(2026, 5, 1),
    );
    expect(a.montantEncaisse, 3000);
    expect(a.montantDepense, 1800);
    expect(a.marge, 1200);
  });

  test('la marge d\'un projet sans flux vaut 0', () {
    final a = Avancement.calculer(
      projet: Projet(id: 1, nom: 'P', type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: 5,
          client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)),
      mode: ModeAvancement.quantites,
      proformas: const [], engagements: const [], now: DateTime(2026, 5, 1),
    );
    expect(a.marge, 0);
  });
}
