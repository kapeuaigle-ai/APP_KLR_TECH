import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

/// Premier jour du mois suivant `d`.
DateTime moisSuivant(DateTime d) => DateTime(d.year, d.month + 1, 1);

Engagement creance(int id, double montant) => Engagement(
    id: id, sens: 'creance', num: 'C$id', tiers: 'Client',
    montant: montant, statut: 'cours', echeance: '01/01/2030');

Engagement dette(int id, double montant) => Engagement(
    id: id, sens: 'dette', num: 'D$id', tiers: 'Fournisseur',
    montant: montant, statut: 'cours', echeance: '01/01/2030');

void main() {
  group('clôture mensuelle', () {
    test('sans changement de mois, rien n\'est archivé', () {
      final s = AppState();
      final avant = s.activities.length;
      s.verifierCloture(maintenant: DateTime.now());
      expect(s.activities.length, avant);
    });

    test('au mois suivant, le bilan du mois écoulé part dans Activités', () {
      final s = AppState();
      final now = DateTime.now();
      // Un mouvement sur le mois en cours, sinon il n'y a rien à archiver.
      // addExpense journalise déjà une entrée : on compte à partir de là.
      s.addExpense(Expense(
          id: 1, date: now, label: 'Loyer', amount: 150000, category: 'Loyer & charges'));
      final avant = s.activities.length;

      s.verifierCloture(maintenant: moisSuivant(now));

      expect(s.activities.length, avant + 1);
      final a = s.activities.first;
      expect(a.type, 'comptabilite');
      expect(a.titre, contains(Comptabilite.monthLabel(Comptabilite.monthKeyFromDate(now))));
      expect(a.desc, contains('Dépenses'));
    });

    test('la clôture ne se rejoue pas deux fois pour le même mois', () {
      final s = AppState();
      final now = DateTime.now();
      s.addExpense(Expense(
          id: 1, date: now, label: 'Loyer', amount: 150000, category: 'Loyer & charges'));

      s.verifierCloture(maintenant: moisSuivant(now));
      final apresPremiere = s.activities.length;
      s.verifierCloture(maintenant: moisSuivant(now));

      expect(s.activities.length, apresPremiere);
    });

    test('un mois sans aucun mouvement n\'encombre pas le fil', () {
      final s = AppState();
      // AppState neuf : les données d'exemple sont sur des mois antérieurs,
      // le mois en cours n'a aucun mouvement.
      final avant = s.activities.length;
      s.verifierCloture(maintenant: moisSuivant(DateTime.now()));
      expect(s.activities.length, avant);
    });

    test('la comptabilité bascule sur le nouveau mois', () {
      final s = AppState();
      final suivant = moisSuivant(DateTime.now());
      s.verifierCloture(maintenant: suivant);
      expect(s.moisCourant, Comptabilite.monthKeyFromDate(suivant));
    });
  });

  group('validation d\'un engagement', () {
    test('valider une créance la fait entrer en revenu du mois du règlement', () {
      final s = AppState();
      s.engagements.clear();
      s.expenses.clear();
      s.documents['facture']!.clear();
      s.addEngagement(creance(90, 300000));

      s.validerEngagement(90, '15/03/2026');

      final rows = Comptabilite.bilanMensuel(
          s.documents['facture']!, s.expenses, s.engagements, const {}, const {});
      expect(Comptabilite.ligneMois('2026-03', rows)?.revenuHt, 300000);
    });

    test('valider une dette la fait entrer en dépense', () {
      final s = AppState();
      s.engagements.clear();
      s.expenses.clear();
      s.documents['facture']!.clear();
      s.addEngagement(dette(91, 80000));

      s.validerEngagement(91, '15/03/2026');

      final rows = Comptabilite.bilanMensuel(
          s.documents['facture']!, s.expenses, s.engagements, const {}, const {});
      expect(Comptabilite.ligneMois('2026-03', rows)?.depenses, 80000);
    });

    test('la validation laisse une trace dans Activités', () {
      final s = AppState();
      final avant = s.activities.length;
      s.addEngagement(creance(92, 500000));
      s.validerEngagement(92, '15/03/2026');
      expect(s.activities.length, avant + 1);
      expect(s.activities.first.type, 'paiement');
      expect(s.activities.first.desc, contains('15/03/2026'));
    });

    test('annuler la validation ressort l\'engagement de la comptabilité', () {
      final s = AppState();
      s.engagements.clear();
      s.expenses.clear();
      s.documents['facture']!.clear();
      s.addEngagement(creance(93, 200000));
      s.validerEngagement(93, '15/03/2026');

      s.annulerValidationEngagement(93);

      expect(s.engagements.single.regle, isFalse);
      expect(
          Comptabilite.totaux(s.documents['facture']!, s.expenses, s.engagements).revenuHt,
          0);
    });
  });
}
