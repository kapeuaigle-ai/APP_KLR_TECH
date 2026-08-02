import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _eng({
  double montant = 1000,
  String sens = 'entrant',
  List<Reglement>? reglements,
  DateTime? echeance,
  bool annule = false,
}) =>
    Engagement(
      id: 1, sens: sens, tiers: 'ACME', montant: montant,
      echeance: echeance ?? DateTime(2026, 6, 30),
      reglements: reglements, annule: annule,
    );

Reglement _reg(double montant, DateTime date, {int id = 1}) =>
    Reglement(id: id, date: date, montant: montant);

void main() {
  test('sans règlement, tout reste dû', () {
    final e = _eng();
    expect(e.regle, 0);
    expect(e.reste, 1000);
    expect(e.solde, isFalse);
  });

  test('deux règlements partiels s\'additionnent', () {
    final e = _eng(reglements: [
      _reg(300, DateTime(2026, 5, 2), id: 1),
      _reg(200, DateTime(2026, 6, 4), id: 2),
    ]);
    expect(e.regle, 500);
    expect(e.reste, 500);
    expect(e.solde, isFalse);
  });

  test('les règlements couvrant le montant soldent l\'engagement', () {
    final e = _eng(reglements: [_reg(1000, DateTime(2026, 5, 2))]);
    expect(e.reste, 0);
    expect(e.solde, isTrue);
  });

  test('le reste ne devient jamais négatif', () {
    final e = _eng(reglements: [_reg(1500, DateTime(2026, 5, 2))]);
    expect(e.reste, 0);
    expect(e.solde, isTrue);
  });

  test('un résidu flottant sous le centime compte comme soldé', () {
    // Trois versements dont le total vaut mathématiquement 1000, mais dont
    // la somme flottante (regle: fold 0.0 + r1 + r2 + r3) retombe sur
    // 999.99999999999988… au lieu de 1000.0 pile — un résidu de l'ordre de
    // 1e-13, représentatif de ce que laisse un enchaînement de règlements
    // en IEEE 754 double, y compris quand le dernier est écrêté au reste.
    final e = _eng(montant: 1000, reglements: [
      _reg(132.81, DateTime(2026, 5, 2), id: 1),
      _reg(711.54, DateTime(2026, 5, 3), id: 2),
      _reg(155.65, DateTime(2026, 5, 4), id: 3),
    ]);
    expect(e.reste, 0);
    expect(e.solde, isTrue);
    expect(e.enRetard(DateTime(2027, 1, 1)), isFalse);
  });

  test('un reste réel d\'un centime ou plus est conservé', () {
    final e = _eng(montant: 1000, reglements: [_reg(999.98, DateTime(2026, 5, 2))]);
    expect(e.reste, closeTo(0.02, 0.0001));
    expect(e.solde, isFalse);
  });

  test('enRetard compare à la date fournie, pas à aujourd\'hui', () {
    final e = _eng(echeance: DateTime(2026, 6, 30));
    expect(e.enRetard(DateTime(2026, 6, 29)), isFalse);
    expect(e.enRetard(DateTime(2026, 6, 30)), isFalse, reason: 'le jour même n\'est pas un retard');
    expect(e.enRetard(DateTime(2026, 7, 1)), isTrue);
  });

  test('un engagement soldé ou annulé n\'est jamais en retard', () {
    final solde = _eng(reglements: [_reg(1000, DateTime(2026, 5, 2))]);
    expect(solde.enRetard(DateTime(2027, 1, 1)), isFalse);
    final annule = _eng(annule: true);
    expect(annule.enRetard(DateTime(2027, 1, 1)), isFalse);
  });

  test('sens : estEntrant distingue créance et dette', () {
    expect(_eng(sens: 'entrant').estEntrant, isTrue);
    expect(_eng(sens: 'sortant').estEntrant, isFalse);
  });

  test('aller-retour JSON complet, règlements compris', () {
    final e = Engagement(
      id: 7, sens: 'sortant', tiers: 'Fournisseur X', montant: 2500,
      echeance: DateTime(2026, 8, 15), description: 'Switches',
      categorie: 'Achat matériel', projetId: 3, documentNumero: 'KLR-F02-10012026',
      clientId: null,
      reglements: [_reg(1000, DateTime(2026, 7, 20), id: 11)],
    );
    final copie = Engagement.fromJson(e.toJson());
    expect(copie.id, 7);
    expect(copie.sens, 'sortant');
    expect(copie.tiers, 'Fournisseur X');
    expect(copie.montant, 2500);
    expect(copie.echeance, DateTime(2026, 8, 15));
    expect(copie.description, 'Switches');
    expect(copie.categorie, 'Achat matériel');
    expect(copie.projetId, 3);
    expect(copie.documentNumero, 'KLR-F02-10012026');
    expect(copie.reglements.length, 1);
    expect(copie.reglements.first.id, 11);
    expect(copie.reglements.first.montant, 1000);
    expect(copie.reglements.first.date, DateTime(2026, 7, 20));
    expect(copie.regle, 1000);
    expect(copie.reste, 1500);
  });

  test('aller-retour JSON d\'un règlement, moyen compris', () {
    final r = Reglement(id: 3, date: DateTime(2026, 3, 9), montant: 450, moyen: 'virement');
    final copie = Reglement.fromJson(r.toJson());
    expect(copie.id, 3);
    expect(copie.date, DateTime(2026, 3, 9));
    expect(copie.montant, 450);
    expect(copie.moyen, 'virement');
  });

  test('un engagement sans clé reglements se relit avec une liste vide', () {
    final copie = Engagement.fromJson(<String, dynamic>{
      'id': 5, 'sens': 'entrant', 'tiers': 'ACME', 'montant': 1000,
      'echeance': DateTime(2026, 6, 30).toIso8601String(),
    });
    expect(copie.reglements, isEmpty);
    expect(copie.reste, 1000);
    expect(copie.description, '');
    expect(copie.categorie, 'Autres');
    expect(copie.annule, isFalse);
  });
}
