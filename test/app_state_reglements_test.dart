import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _vide() => AppState()..viderDonnees();

Engagement _eng({double montant = 1000, String sens = 'entrant'}) => Engagement(
      id: 1, sens: sens, tiers: 'ACME', montant: montant,
      echeance: DateTime(2026, 6, 30),
    );

void main() {
  test('ajouterReglement enregistre le mouvement', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.engagements.first.regle, 400);
    expect(s.engagements.first.reste, 600);
  });

  test('un règlement dépassant le reste est écrêté', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 1500, DateTime(2026, 3, 3));
    expect(s.engagements.first.regle, 1000);
    expect(s.engagements.first.solde, isTrue);
  });

  test('deux règlements successifs, le second écrêté au reste', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 700, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 900, DateTime(2026, 4, 3));
    expect(s.engagements.first.regle, 1000);
    expect(s.engagements.first.reglements.length, 2);
    expect(s.engagements.first.reglements[1].montant, 300);
  });

  test('un montant nul ou négatif est refusé', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 0, DateTime(2026, 3, 3));
    s.ajouterReglement(1, -50, DateTime(2026, 3, 3));
    expect(s.engagements.first.reglements, isEmpty);
  });

  test('un engagement annulé n\'accepte plus de règlement', () {
    final s = _vide()..addEngagement(_eng());
    s.annulerEngagement(1);
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.engagements.first.reglements, isEmpty);
    expect(s.engagements.first.annule, isTrue);
  });

  test('un engagement déjà soldé n\'accepte plus de règlement', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 1000, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 100, DateTime(2026, 4, 3));
    expect(s.engagements.first.reglements.length, 1);
  });

  test('supprimerReglement retire le seul mouvement visé', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 300, DateTime(2026, 4, 3));
    final cible = s.engagements.first.reglements.first.id;
    s.supprimerReglement(1, cible);
    expect(s.engagements.first.reglements.length, 1);
    expect(s.engagements.first.regle, 300);
  });

  test('supprimer un engagement emporte ses règlements', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    s.deleteEngagement(1);
    expect(s.engagements, isEmpty);
  });

  test('chaque règlement produit une entrée dans Activités', () {
    final s = _vide()..addEngagement(_eng());
    final avant = s.activities.length;
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.activities.length, avant + 1);
  });

  test('la trace d\'activité porte la date du règlement, pas celle de la saisie', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 400, DateTime(2026, 3, 15));

    final trace = s.activities.first;
    expect(trace.desc, contains('15/03/2026'),
        reason: 'la date d\'imputation doit figurer dans l\'historique');
    expect(trace.desc, contains('600'), reason: 'et le reste dû');
  });

  test('un règlement soldant l\'engagement le dit, avec sa date', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 1000, DateTime(2026, 4, 2));

    final trace = s.activities.first;
    expect(trace.desc, contains('soldé'));
    expect(trace.desc, contains('02/04/2026'));
  });
}
