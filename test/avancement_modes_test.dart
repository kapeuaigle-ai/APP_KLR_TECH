import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _projet({
  List<Jalon>? jalons,
  double manuel = 0,
  DateTime? debut,
  DateTime? fin,
}) => Projet(
      id: 1, nom: 'P', type: 't', mode: ModeAvancement.quantites, clientId: 5, client: 'ACME',
      debut: debut ?? DateTime(2026, 3, 1),
      finPrevue: fin ?? DateTime(2026, 6, 30),
      jalons: jalons, avancementManuel: manuel);

double _phys(Projet p, ModeAvancement mode, DateTime now) =>
    Avancement.calculer(
      projet: p, mode: mode, proformas: const [], engagements: const [], now: now,
    ).physique;

void main() {
  group('mode jalons', () {
    test('aucun jalon fait donne 0', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), poids: 1),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), poids: 1),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15)), 0);
    });

    test('les poids sont respectés, pas le simple décompte', () {
      // 1 jalon fait sur 2, mais il pèse 3 sur 5 : 60 %, pas 50 %.
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 3),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), poids: 2),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15)), closeTo(0.6, 0.0001));
    });

    test('tous les jalons faits donnent 1', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 3),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), realisee: DateTime(2026, 5, 3), poids: 2),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 6, 1)), 1);
    });

    test('sans jalon, 0 et jamais NaN', () {
      final p = _projet(jalons: []);
      final v = _phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15));
      expect(v, 0);
      expect(v.isNaN, isFalse);
    });

    test('des poids tous nuls ne produisent pas de NaN', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 0),
      ]);
      final v = _phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15));
      expect(v, 0);
      expect(v.isNaN, isFalse);
    });
  });

  group('mode duree', () {
    final p = _projet(debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 11));

    test('avant le début : 0, jamais négatif', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2025, 12, 1)), 0);
    });

    test('au début : 0', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 1)), 0);
    });

    test('à mi-parcours : 0,5', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 6)), closeTo(0.5, 0.0001));
    });

    test('à la fin prévue : 1', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 11)), 1);
    });

    test('après la fin : 1, jamais au-delà', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 3, 1)), 1);
    });

    test('début et fin le même jour ne produisent pas de NaN', () {
      final court = _projet(debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 1));
      final v = _phys(court, ModeAvancement.duree, DateTime(2026, 1, 1));
      expect(v.isNaN, isFalse);
      expect(v, anyOf(0, 1));
    });
  });

  group('mode manuel', () {
    test('rend la valeur saisie', () {
      expect(_phys(_projet(manuel: 0.35), ModeAvancement.manuel, DateTime(2026, 4, 1)),
          closeTo(0.35, 0.0001));
    });

    test('une valeur hors bornes est ramenée dans [0, 1]', () {
      expect(_phys(_projet(manuel: 1.8), ModeAvancement.manuel, DateTime(2026, 4, 1)), 1);
      expect(_phys(_projet(manuel: -0.5), ModeAvancement.manuel, DateTime(2026, 4, 1)), 0);
    });
  });
}
