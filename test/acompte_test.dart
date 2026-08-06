import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

/// Acomptes sur créances et dettes. Règle : la comptabilité est tenue en base
/// caisse, donc chaque somme compte au mois où elle a circulé — l'acompte à sa
/// date, le solde à son propre règlement. Jamais deux fois.
///
/// Le modèle Engagement/Reglement lui-même (reste, solde, JSON) est couvert
/// par `engagement_reglement_test.dart` ; ce fichier ne teste plus que la
/// lecture de ces règlements par Comptabilite.
void main() {
  Reglement reg(double montant, DateTime date) =>
      Reglement(id: date.microsecondsSinceEpoch, date: date, montant: montant);

  /// Une créance avec acompte et/ou solde, chacun devenu son propre
  /// règlement. Sans acompte ni solde couvrant tout le montant, seul le
  /// versement effectivement daté compte — comme en v1.
  Engagement creance({
    double montant = 1000000,
    double acompte = 0,
    String? dateAcompte,
    String? dateReglement,
  }) {
    final regs = <Reglement>[];
    if (acompte > 0 && dateAcompte != null) {
      regs.add(reg(acompte, Comptabilite.parseJour(dateAcompte)!));
    }
    if (dateReglement != null) {
      final solde = montant - acompte;
      if (solde > 0) regs.add(reg(solde, Comptabilite.parseJour(dateReglement)!));
    }
    return Engagement(id: 1, sens: 'entrant', tiers: 'Advans',
        montant: montant, echeance: DateTime(2026, 8, 31), reglements: regs);
  }

  double revenuDuMois(String mois, List<Engagement> engagements) {
    final rows = Comptabilite.bilanMensuel(engagements, const {}, const {});
    return Comptabilite.ligneMois(mois, rows)?.revenu ?? 0;
  }

  group('comptabilité', () {
    test('acompte seul : compté au mois de son versement', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026');
      expect(revenuDuMois('2026-07', [e]), 300000);
    });

    test('créance non réglée sans acompte : rien en comptabilité', () {
      expect(revenuDuMois('2026-07', [creance()]), 0);
    });

    test('acompte puis règlement : chaque part à son mois, aucun doublon', () {
      final e = creance(
        acompte: 300000, dateAcompte: '10/07/2026',
        dateReglement: '15/08/2026',
      );
      expect(revenuDuMois('2026-07', [e]), 300000); // l'acompte
      expect(revenuDuMois('2026-08', [e]), 700000); // le solde seulement

      final total = Comptabilite.totaux([e]);
      expect(total.revenu, 1000000); // et jamais 1 300 000
    });

    test('acompte et règlement le même mois : total juste', () {
      final e = creance(
        acompte: 300000, dateAcompte: '05/07/2026',
        dateReglement: '20/07/2026',
      );
      expect(revenuDuMois('2026-07', [e]), 1000000);
    });

    test('acompte couvrant tout : le règlement n\'ajoute rien', () {
      final e = creance(
        montant: 500000, acompte: 500000, dateAcompte: '10/07/2026',
        dateReglement: '15/08/2026',
      );
      expect(e.reste, 0);
      expect(revenuDuMois('2026-08', [e]), 0);
      expect(Comptabilite.totaux([e]).revenu, 500000);
    });

    test('dette avec acompte : même règle côté dépenses', () {
      final d = Engagement(
        id: 2, sens: 'sortant', tiers: 'Fournisseur',
        montant: 800000, echeance: DateTime(2026, 8, 31),
        reglements: [
          reg(200000, DateTime(2026, 7, 10)),
          reg(600000, DateTime(2026, 8, 15)),
        ],
      );
      final rows = Comptabilite.bilanMensuel([d], const {}, const {});
      expect(Comptabilite.ligneMois('2026-07', rows)!.depenses, 200000);
      expect(Comptabilite.ligneMois('2026-08', rows)!.depenses, 600000);
      expect(Comptabilite.totaux([d]).depenses, 800000);
    });
  });
}
