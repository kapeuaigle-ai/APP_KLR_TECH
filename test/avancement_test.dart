import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _projet({int id = 1, DateTime? debut, DateTime? fin}) => Projet(
      id: id, nom: 'Fourniture', typeId: 'fourniture', clientId: 5,
      client: 'ACME',
      debut: debut ?? DateTime(2026, 3, 1),
      finPrevue: fin ?? DateTime(2026, 6, 30),
    );

DocumentItem _proforma(int projetId, List<LineItem> lines) => DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 0, statut: 'validee',
      projetId: projetId, lines: lines,
    );

Engagement _entrant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 1, sens: 'entrant', tiers: 'ACME', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Engagement _sortant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 2, sens: 'sortant', tiers: 'Fournisseur', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Reglement _r(double m, DateTime d) => Reglement(id: 1, date: d, montant: m);

void main() {
  group('avancement physique — mode quantites', () {
    test('rien de livré donne 0', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
    });

    test('la pondération se fait par le montant, pas par le nombre d\'articles', () {
      // 20 souris à 5 (=100) toutes livrées, 1 serveur à 900 non livré.
      // Par articles : 20/21 = 95 %. Par montant : 100/1000 = 10 %.
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [
          LineItem(ref: 'SOU', designation: 'Souris', qte: 20, pu: 5, qteLivree: 20),
          LineItem(ref: 'SRV', designation: 'Serveur', qte: 1, pu: 900, qteLivree: 0),
        ])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, closeTo(0.10, 0.0001));
    });

    test('tout livré donne 1', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 1);
    });

    test('sans proforma, l\'avancement vaut 0 et jamais NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });

    test('des lignes à prix nul ne produisent pas de NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'X', designation: 'Offert', qte: 5, pu: 0, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });
  });

  group('avancement financier', () {
    test('règlements ÷ montant attendu', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(400, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, closeTo(0.4, 0.0001));
      expect(a.montantAttendu, 1000);
      expect(a.montantEncaisse, 400);
    });

    test('les engagements sortants ne comptent pas dans le financier', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 1);
      expect(a.montantAttendu, 1000);
    });

    test('sans engagement entrant, le financier vaut 0', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 0);
    });

    test('un engagement annulé est ignoré', () {
      final annule = _entrant(1, 5000, [])..annule = true;
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [annule, _entrant(1, 1000, [_r(500, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.montantAttendu, 1000);
      expect(a.financier, closeTo(0.5, 0.0001));
    });
  });

  group('marge et retard', () {
    test('la marge est entrants réglés moins sortants réglés', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, 400);
    });

    test('en retard si la fin prévue est dépassée et le physique incomplet', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isTrue);
    });

    test('pas de retard si tout est livré, même après la date', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isFalse);
    });
  });

  group('statut déduit', () {
    StatutProjet _statut({
      required double phys, required double fin, bool annule = false,
    }) {
      final projet = _projet();
      projet.annule = annule;
      return Avancement.calculer(
        projet: projet,
        mode: ModeAvancement.manuel,
        proformas: const [],
        engagements: fin == 0
            ? const []
            : [_entrant(1, 1000, [_r(1000 * fin, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
        physiqueForce: phys,
      ).statut;
    }

    test('annulé l\'emporte sur tout', () {
      expect(_statut(phys: 1, fin: 1, annule: true), StatutProjet.annule);
    });
    test('0 et 0 : à démarrer', () {
      expect(_statut(phys: 0, fin: 0), StatutProjet.aDemarrer);
    });
    test('100 et 100 : soldé', () {
      expect(_statut(phys: 1, fin: 1), StatutProjet.solde);
    });
    test('100 livré, 50 encaissé : livré, reste à encaisser', () {
      expect(_statut(phys: 1, fin: 0.5), StatutProjet.livreNonPaye);
    });
    test('50 livré : en cours', () {
      expect(_statut(phys: 0.5, fin: 0.5), StatutProjet.enCours);
    });
    test('0 livré mais déjà encaissé : en cours, pas à démarrer', () {
      expect(_statut(phys: 0, fin: 0.3), StatutProjet.enCours);
    });
  });
}
