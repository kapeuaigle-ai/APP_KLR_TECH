import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _p({int id = 1}) => Projet(
      id: id, nom: 'Fourniture matériel', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

void main() {
  test('addProjet, updateProjet et deleteProjet', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    expect(s.projets.length, 1);

    s.updateProjet(_p()..nom = 'Renommé');
    expect(s.projets.first.nom, 'Renommé');

    s.deleteProjet(1);
    expect(s.projets, isEmpty);
  });

  test('les projets survivent à un aller-retour JSON', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    final s2 = AppState()..loadFromJson(json);
    expect(s2.projets.length, 1);
    expect(s2.projets.first.nom, 'Fourniture matériel');
    expect(s2.projets.first.debut, DateTime(2026, 3, 1));
  });

  test('supprimer un projet délie ses documents et ses engagements', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)],
    ));
    s.addEngagement(Engagement(
      id: 9, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
      echeance: DateTime(2026, 4, 1), projetId: 1));

    s.deleteProjet(1);

    expect(s.documents['proforma']!.first.projetId, isNull);
    expect(s.engagements.first.projetId, isNull,
        reason: 'un engagement ne doit jamais pointer vers un projet disparu');
  });

  test('avancementProjet agrège documents et engagements du projet', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 4)],
    ));
    s.validateProforma(1);
    s.ajouterReglement(s.engagements.first.id, 900, DateTime(2026, 4, 1));

    final a = s.avancementProjet(1, now: DateTime(2026, 4, 15));
    expect(a.physique, closeTo(0.4, 0.0001));
    expect(a.financier, closeTo(0.3, 0.0001));
    expect(a.statut, StatutProjet.enCours);
  });

  test('avancementProjet ne mélange pas deux projets', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p(id: 1));
    s.addProjet(_p(id: 2));
    s.addEngagement(Engagement(id: 10, sens: 'entrant', tiers: 'ACME',
        montant: 1000, echeance: DateTime(2026, 6, 1), projetId: 1));
    s.addEngagement(Engagement(id: 11, sens: 'entrant', tiers: 'ACME',
        montant: 7000, echeance: DateTime(2026, 6, 1), projetId: 2));

    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).montantAttendu, 1000);
    expect(s.avancementProjet(2, now: DateTime(2026, 4, 1)).montantAttendu, 7000);
  });
}
