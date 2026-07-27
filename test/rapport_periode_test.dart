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

  DocumentItem facture(String numero, double pu, {String? encaissementLe}) =>
      DocumentItem(
        id: numero.hashCode, numero: numero, date: '01/07/2026', clientId: 0,
        client: 'Client', objet: 'O', montant: pu, statut: 'validee',
        lines: [LineItem(ref: '01', designation: 'x', qte: 1, pu: pu)],
        encaissee: encaissementLe != null, dateEncaissement: encaissementLe,
      );

  RapportPeriode rapport(DateTime debut, DateTime fin, {
    List<DocumentItem> factures = const [],
    List<Expense> expenses = const [],
    List<Engagement> engagements = const [],
  }) =>
      Comptabilite.rapport(debut: debut, fin: fin, factures: factures,
          expenses: expenses, engagements: engagements);

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
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), factures: [
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
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), expenses: [
        Expense(id: 1, date: DateTime(2026, 7, 5), label: 'Carburant',
            amount: 15000, category: 'Transport'),
        Expense(id: 2, date: DateTime(2026, 7, 20), label: 'Taxi',
            amount: 5000, category: 'Transport'),
        Expense(id: 3, date: DateTime(2026, 8, 2), label: 'Hors période',
            amount: 99000, category: 'Transport'),
      ]);
      expect(r.depenses, 20000);
      expect(r.depensesParCategorie['Transport'], 20000);
    });
  });

  group('engagements', () {
    Engagement creance({double acompte = 0, String? dateAcompte,
            String statut = 'cours', String? dateReglement}) =>
        Engagement(id: 1, sens: 'creance', num: 'C-1', tiers: 'Advans',
            montant: 1000000, statut: statut, echeance: '31/08/2026',
            acompte: acompte, dateAcompte: dateAcompte, dateReglement: dateReglement);

    test('acompte compté dans le mois de son versement seulement', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026');
      expect(rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31), engagements: [e]).revenu, 300000);
      expect(rapport(DateTime(2026, 8, 1), DateTime(2026, 8, 31), engagements: [e]).revenu, 0);
    });

    test('règlement : le solde seulement, jamais l\'acompte une 2e fois', () {
      final e = creance(acompte: 300000, dateAcompte: '10/07/2026',
          statut: 'paye', dateReglement: '15/08/2026');
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
        factures: [facture('F1', 1000000, encaissementLe: '10/07/2026')],
        expenses: [Expense(id: 1, date: DateTime(2026, 7, 12), label: 'Achat',
            amount: 400000, category: 'Achat matériel')],
      );
      expect(r.revenu, 1000000);
      expect(r.depenses, 400000);
      expect(r.benefice, 600000);
      expect(r.dime, 60000); // 10 % du bénéfice
    });

    test('bénéfice négatif : pas de dîme', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        expenses: [Expense(id: 1, date: DateTime(2026, 7, 12), label: 'Achat',
            amount: 400000, category: 'Achat matériel')],
      );
      expect(r.benefice, -400000);
      expect(r.dime, 0);
    });

    test('mouvements triés du plus ancien au plus récent', () {
      final r = rapport(DateTime(2026, 7, 1), DateTime(2026, 7, 31),
        factures: [facture('F1', 100000, encaissementLe: '25/07/2026')],
        expenses: [Expense(id: 1, date: DateTime(2026, 7, 3), label: 'Achat',
            amount: 5000, category: 'Transport')],
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
        factures: [facture('F1', 1000000, encaissementLe: '10/07/2026')],
        expenses: [Expense(id: 1, date: DateTime(2026, 7, 12), label: 'Achat',
            amount: 400000, category: 'Achat matériel')],
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
