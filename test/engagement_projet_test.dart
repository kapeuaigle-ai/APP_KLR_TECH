import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _p({int id = 1}) => Projet(
      id: id, nom: 'Fourniture matériel',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

void main() {
  group('rattacherProjetEngagement', () {
    test('rattache un engagement existant, créé sans projet, à un projet', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      s.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
        echeance: DateTime(2026, 4, 1),
      ));
      expect(s.engagements.first.projetId, isNull);

      s.rattacherProjetEngagement(1, 1);

      expect(s.engagements.first.projetId, 1);
    });

    test('peut aussi détacher un engagement (projetId nul)', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      s.addEngagement(Engagement(
        id: 1, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
        echeance: DateTime(2026, 4, 1), projetId: 1));

      s.rattacherProjetEngagement(1, null);

      expect(s.engagements.first.projetId, isNull);
    });

    test('un id inconnu ne fait rien', () {
      final s = AppState()..viderDonnees();
      s.addProjet(_p());
      // Ne doit pas lancer d'exception.
      s.rattacherProjetEngagement(999, 1);
      expect(s.engagements, isEmpty);
    });
  });

  // C'est l'assertion qui prouve que la fonctionnalité n'est plus décorative :
  // avant ce correctif, aucun écran n'écrivait jamais Engagement.projetId sur
  // un engagement sortant, donc montantDepense restait bloqué à 0 et la marge
  // valait toujours le montant encaissé en entier.
  test('un engagement sortant rattaché à un projet, une fois soldé, réduit sa marge', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    s.addEngagement(Engagement(
      id: 10, sens: 'entrant', tiers: 'ACME', montant: 3000,
      echeance: DateTime(2026, 4, 1), projetId: 1));
    s.addEngagement(Engagement(
      id: 11, sens: 'sortant', tiers: 'Fournisseur', montant: 1800,
      echeance: DateTime(2026, 4, 5), projetId: 1));

    s.ajouterReglement(10, 3000, DateTime(2026, 4, 1));
    s.ajouterReglement(11, 1800, DateTime(2026, 4, 5));

    final a = s.avancementProjet(1, now: DateTime(2026, 5, 1));
    expect(a.montantEncaisse, 3000);
    expect(a.montantDepense, 1800,
        reason: 'la dépense rattachée doit être comptée, sinon elle reste à 0');
    expect(a.marge, 1200, reason: 'marge = encaissé - décaissé, pas encaissé seul');
  });
}
