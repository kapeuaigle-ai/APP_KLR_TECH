import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

/// Acomptes sur créances et dettes. Règle : la comptabilité est tenue en base
/// caisse, donc chaque somme compte au mois où elle a circulé — l'acompte à sa
/// date, le solde à la validation. Jamais deux fois.
void main() {
  Engagement creance({
    double montant = 1000000,
    double acompte = 0,
    String? dateAcompte,
    String statut = 'cours',
    String? dateReglement,
  }) =>
      Engagement(
        id: 1, sens: 'creance', num: 'C-1', tiers: 'Advans',
        montant: montant, statut: statut, echeance: '31/08/2026',
        acompte: acompte, dateAcompte: dateAcompte, dateReglement: dateReglement,
      );

  double revenuDuMois(String mois, List<Engagement> engagements) {
    final rows = Comptabilite.bilanMensuel([], [], engagements, const {}, const {});
    return Comptabilite.ligneMois(mois, rows)?.revenuHt ?? 0;
  }

  group('modèle', () {
    test('sans acompte : reste = montant', () {
      final e = creance();
      expect(e.aAcompte, isFalse);
      expect(e.reste, 1000000);
      expect(e.montantAuReglement, 1000000);
    });

    test('avec acompte : reste et part au règlement diminuent d\'autant', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026');
      expect(e.aAcompte, isTrue);
      expect(e.reste, 700000);
      expect(e.montantAuReglement, 700000);
    });

    test('acompte sans date : ignoré (mois de rattachement inconnu)', () {
      final e = creance(acompte: 300000);
      expect(e.aAcompte, isFalse);
      expect(e.montantAuReglement, 1000000);
    });

    test('round-trip JSON, et rétro-compatibilité', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026');
      final r = Engagement.fromJson(e.toJson());
      expect(r.acompte, 300000);
      expect(r.dateAcompte, '10/07/2026');

      final vieux = e.toJson()..remove('acompte')..remove('dateAcompte');
      final v = Engagement.fromJson(vieux);
      expect(v.acompte, 0);
      expect(v.aAcompte, isFalse);
    });
  });

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
        statut: 'paye', dateReglement: '15/08/2026',
      );
      expect(revenuDuMois('2026-07', [e]), 300000); // l'acompte
      expect(revenuDuMois('2026-08', [e]), 700000); // le solde seulement

      final total = Comptabilite.totaux([], [], [e]);
      expect(total.revenuHt, 1000000); // et jamais 1 300 000
    });

    test('acompte et règlement le même mois : total juste', () {
      final e = creance(
        acompte: 300000, dateAcompte: '05/07/2026',
        statut: 'paye', dateReglement: '20/07/2026',
      );
      expect(revenuDuMois('2026-07', [e]), 1000000);
    });

    test('acompte couvrant tout : le règlement n\'ajoute rien', () {
      final e = creance(
        montant: 500000, acompte: 500000, dateAcompte: '10/07/2026',
        statut: 'paye', dateReglement: '15/08/2026',
      );
      expect(e.reste, 0);
      expect(revenuDuMois('2026-08', [e]), 0);
      expect(Comptabilite.totaux([], [], [e]).revenuHt, 500000);
    });

    test('dette avec acompte : même règle côté dépenses', () {
      final d = Engagement(
        id: 2, sens: 'dette', num: 'D-1', tiers: 'Fournisseur',
        montant: 800000, statut: 'paye', echeance: '31/08/2026',
        acompte: 200000, dateAcompte: '10/07/2026', dateReglement: '15/08/2026',
      );
      final rows = Comptabilite.bilanMensuel([], [], [d], const {}, const {});
      expect(Comptabilite.ligneMois('2026-07', rows)!.depenses, 200000);
      expect(Comptabilite.ligneMois('2026-08', rows)!.depenses, 600000);
      expect(Comptabilite.totaux([], [], [d]).depenses, 800000);
    });
  });

  group('AppState.setAcompte', () {
    test('pose un acompte et journalise le reste', () {
      final s = AppState();
      s.addEngagement(creance());
      s.setAcompte(1, 300000, '10/07/2026');

      final e = s.engagements.firstWhere((x) => x.id == 1);
      expect(e.acompte, 300000);
      expect(e.dateAcompte, '10/07/2026');
      expect(s.activities.any((a) => a.titre.contains('Acompte encaissé')), isTrue);
    });

    test('acompte plafonné au montant de l\'engagement', () {
      final s = AppState();
      s.addEngagement(creance(montant: 500000));
      s.setAcompte(1, 900000, '10/07/2026');
      expect(s.engagements.firstWhere((x) => x.id == 1).acompte, 500000);
    });

    test('montant nul : l\'acompte est retiré', () {
      final s = AppState();
      s.addEngagement(creance(acompte: 300000, dateAcompte: '10/07/2026'));
      s.setAcompte(1, 0, '10/07/2026');

      final e = s.engagements.firstWhere((x) => x.id == 1);
      expect(e.acompte, 0);
      expect(e.aAcompte, isFalse);
    });
  });
}
