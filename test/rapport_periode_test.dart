import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/pdf_generator.dart';
import 'support/test_fonts.dart';

/// Rapport sur une période bornée : seuls les mouvements réellement datés
/// dans l'intervalle comptent, bornes incluses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  Reglement reg(double montant, DateTime date) =>
      Reglement(id: date.microsecondsSinceEpoch, date: date, montant: montant);

  /// Une facture encaissée : engagement entrant rattaché à son numéro,
  /// soldé par un unique règlement à la date d'encaissement. Sans date
  /// d'encaissement, l'engagement reste sans règlement — non encaissée.
  Engagement facture(String numero, double pu, {String? encaissementLe}) =>
      Engagement(
        id: numero.hashCode, sens: 'entrant', tiers: 'Client',
        montant: pu, echeance: DateTime(2026, 7, 1), documentNumero: numero,
        reglements: encaissementLe == null
            ? []
            : [reg(pu, Comptabilite.parseJour(encaissementLe)!)],
      );

  /// Une dépense au comptant : engagement sortant réglé le jour même.
  Engagement depense(double amount, DateTime date, String category, String label) =>
      Engagement(
        id: date.microsecondsSinceEpoch, sens: 'sortant', tiers: label,
        montant: amount, echeance: date, categorie: category,
        reglements: [reg(amount, date)],
      );

  RapportPeriode rapport(DateTime debut, DateTime fin, {
    List<Engagement> engagements = const [],
  }) =>
      Comptabilite.rapport(debut: debut, fin: fin, engagements: engagements);

  group('bornes', () {
    test('parseJour lit dd/MM/yyyy, rejette le reste', () {
      expect(Comptabilite.parseJour('15/08/2026'), DateTime(2026, 8, 15));
      expect(Comptabilite.parseJour(null), isNull);
      expect(Comptabilite.parseJour('n\'importe quoi'), isNull);
    });

    test('dansPeriode inclut les deux bornes', () {
      final d = DateTime(2026, 7, 1), f = DateTime(2026, 7, 31);
      expect(Comptabilite.dansPeriode(DateTime(2026, 7, 1), d, f), isTrue);
      expect(Comptabilite.dansPeriode(DateTime(2026, 7, 31), d, f), isTrue);
      expect(Comptabilite.dansPeriode(DateTime(2026, 6, 30), d, f), isFalse);
      expect(Comptabilite.dansPeriode(DateTime(2026, 8, 1), d, f), isFalse);
    });
  });

  group('revenus', () {
    test('seules les factures encaissées DANS la période comptent', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), engagements: [
        facture('F1', 100000, encaissementLe: '10/07/2026'), // dedans
        facture('F2', 200000, encaissementLe: '10/08/2026'), // hors période
        facture('F3', 400000),                               // non encaissée
      ]);
      expect(r.revenu, 100000);
      expect(r.mouvements.length, 1);
    });

    test('période vide : rapport vide, pas de plantage', () {
      final r = rapport(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      expect(r.estVide, isTrue);
      expect(r.revenu, 0);
      expect(r.benefice, 0);
      expect(r.dime, 0);
    });
  });

  group('dépenses', () {
    test('dépenses de la période, regroupées par catégorie', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), engagements: [
        depense(15000, DateTime(2026, 7, 5), 'Transport', 'Carburant'),
        depense(5000, DateTime(2026, 7, 20), 'Transport', 'Taxi'),
        depense(99000, DateTime(2026, 8, 2), 'Transport', 'Hors période'),
      ]);
      expect(r.depenses, 20000);
      expect(r.depensesParCategorie['Transport'], 20000);
    });
  });

  group('engagements', () {
    /// Créance avec acompte + solde : deux règlements — l'acompte à sa date,
    /// le solde (montant - acompte) à la date de règlement.
    Engagement creance({double acompte = 0, String? dateAcompte,
            String? dateReglement}) {
      final montant = 1000000.0;
      final regs = <Reglement>[];
      if (acompte > 0 && dateAcompte != null) {
        regs.add(reg(acompte, Comptabilite.parseJour(dateAcompte)!));
      }
      if (dateReglement != null) {
        regs.add(reg(montant - acompte, Comptabilite.parseJour(dateReglement)!));
      }
      return Engagement(id: 1, sens: 'entrant', tiers: 'Advans',
          montant: montant, echeance: DateTime(2026, 8, 31), reglements: regs);
    }

    test('acompte compté dans le mois de son versement seulement', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026');
      expect(rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), engagements: [e]).revenu, 300000);
      expect(rapport(DateTime(2026, 8, 1), DateTime(2026, 8, 31), engagements: [e]).revenu, 0);
    });

    test('règlement : le solde seulement, jamais l\'acompte une 2e fois', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026',
          dateReglement: '15/08/2026');
      expect(rapport(DateTime(2026, 8, 1), DateTime(2026, 8, 31), engagements: [e]).revenu, 700000);
      // Sur les deux mois réunis : le montant total, pas davantage.
      expect(rapport(DateTime(2026, 7, 1), DateTime(2026, 8, 31), engagements: [e]).revenu, 1000000);
    });

    test('créances en cours : reste dû, acompte déduit', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
          engagements: [creance(acompte: 300000, dateAcompte: '10/07/2026')]);
      expect(r.creancesEnCours, 700000);
    });
  });

  group('synthèse', () {
    test('bénéfice et dîme calculés sur la période', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        engagements: [
          facture('F1', 1000000, encaissementLe: '10/07/2026'),
          depense(400000, DateTime(2026, 7, 12), 'Achat matériel', 'Achat'),
        ],
      );
      expect(r.revenu, 1000000);
      expect(r.depenses, 400000);
      expect(r.benefice, 600000);
      expect(r.dime, 60000); // 10 % du bénéfice
    });

    test('bénéfice négatif : pas de dîme', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        engagements: [depense(400000, DateTime(2026, 7, 12), 'Achat matériel', 'Achat')],
      );
      expect(r.benefice, -400000);
      expect(r.dime, 0);
    });

    test('mouvements triés du plus ancien au plus récent', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        engagements: [
          facture('F1', 100000, encaissementLe: '25/07/2026'),
          depense(5000, DateTime(2026, 7, 3), 'Transport', 'Achat'),
        ],
      );
      expect(r.mouvements.first.date, DateTime(2026, 7, 3));
      expect(r.mouvements.last.date, DateTime(2026, 7, 25));
    });
  });

  group('PDF du rapport', () {
    AppSettings settings() => AppSettings(
          company: 'KLR TECH SARL', address: 'Abidjan', bp: 'BP 1', rccm: 'R',
          regime: 'TEE', tel: '07', email: 'a@b.ci', prefix: 'KLR',
          startNum: '01', tva: 5, conditions: 'x',
        );

    testWidgets('rapport garni : PDF valide', (tester) async {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        engagements: [
          facture('F1', 1000000, encaissementLe: '10/07/2026'),
          depense(400000, DateTime(2026, 7, 12), 'Achat matériel', 'Achat'),
        ],
      );
      final bytes = await PdfGenerator.generateRapport(settings: settings(), rapport: r);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    testWidgets('période sans aucun mouvement : PDF valide malgré tout', (tester) async {
      // Cas d'une application fraîchement réinitialisée : le rapport doit
      // rester téléchargeable au lieu de planter.
      final r = rapport(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
      final bytes = await PdfGenerator.generateRapport(settings: settings(), rapport: r);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
