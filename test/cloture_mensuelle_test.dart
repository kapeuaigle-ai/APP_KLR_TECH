import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

/// Premier jour du mois suivant `d`.
DateTime moisSuivant(DateTime d) => DateTime(d.year, d.month + 1, 1);

Engagement creance(int id, double montant) => Engagement(
    id: id, sens: 'entrant', tiers: 'Client',
    montant: montant, echeance: DateTime(2030, 1, 1));

Engagement dette(int id, double montant) => Engagement(
    id: id, sens: 'sortant', tiers: 'Fournisseur',
    montant: montant, echeance: DateTime(2030, 1, 1));

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
      // ajouterReglement journalise déjà une entrée : on compte à partir de là.
      s.addEngagement(Engagement(id: 301, sens: 'sortant', tiers: 'Bailleur',
          montant: 150000, echeance: now, categorie: 'Loyer & charges'));
      s.ajouterReglement(301, 150000, now);
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
      s.addEngagement(Engagement(id: 302, sens: 'sortant', tiers: 'Bailleur',
          montant: 150000, echeance: now, categorie: 'Loyer & charges'));
      s.ajouterReglement(302, 150000, now);

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
      s.documents['facture']!.clear();
      s.addEngagement(creance(90, 300000));
      final e = s.engagements.firstWhere((e) => e.id == 90);

      s.ajouterReglement(90, e.reste, DateTime(2026, 3, 15));

      final rows = Comptabilite.bilanMensuel(s.engagements, const {}, const {});
      expect(Comptabilite.ligneMois('2026-03', rows)?.revenuHt, 300000);
    });

    test('valider une dette la fait entrer en dépense', () {
      final s = AppState();
      s.engagements.clear();
      s.documents['facture']!.clear();
      s.addEngagement(dette(91, 80000));
      final e = s.engagements.firstWhere((e) => e.id == 91);

      s.ajouterReglement(91, e.reste, DateTime(2026, 3, 15));

      final rows = Comptabilite.bilanMensuel(s.engagements, const {}, const {});
      expect(Comptabilite.ligneMois('2026-03', rows)?.depenses, 80000);
    });

    test('la validation laisse une trace dans Activités', () {
      final s = AppState();
      final avant = s.activities.length;
      s.addEngagement(creance(92, 500000));
      final e = s.engagements.firstWhere((e) => e.id == 92);

      s.ajouterReglement(92, e.reste, DateTime(2026, 3, 15));

      expect(s.activities.length, avant + 1);
      expect(s.activities.first.type, 'paiement');
      expect(s.activities.first.desc, contains('15/03/2026'));
    });

    test('annuler la validation ressort l\'engagement de la comptabilité', () {
      final s = AppState();
      s.engagements.clear();
      s.documents['facture']!.clear();
      s.addEngagement(creance(93, 200000));
      final e = s.engagements.firstWhere((e) => e.id == 93);
      s.ajouterReglement(93, e.reste, DateTime(2026, 3, 15));

      final dernier = s.engagements.single.reglements.last.id;
      s.supprimerReglement(93, dernier);

      expect(s.engagements.single.regle, 0);
      expect(Comptabilite.totaux(s.engagements).revenuHt, 0);
    });
  });
}
