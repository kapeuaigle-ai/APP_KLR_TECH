import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

/// Défaut 3 (CRITIQUE, revue Lot B) : `Client.totalFacture` était un total
/// stocké, écrit une seule fois par le seed de démonstration et jamais
/// recalculé — figé à 0 pour tout client créé depuis l'écran, quelle que
/// soit l'activité réelle. `AppState.chiffreAffairesClient` le remplace : le
/// chiffre d'affaires d'un client est la somme des règlements
/// (`Engagement.regle`) de ses engagements entrants, jamais un champ stocké.
Client _client(int id, {String name = 'ACME'}) => Client(
      id: id, initials: 'AC', color: Colors.blue, name: name,
      contact: 'Jean', email: 'j@acme.cm', phone: '600',
    );

Engagement _entrant(int id, int? clientId, double montant, List<Reglement> regs,
        {bool annule = false}) =>
    Engagement(
      id: id, sens: 'entrant', tiers: 'Client', clientId: clientId,
      montant: montant, echeance: DateTime(2026, 6, 1), reglements: regs,
      annule: annule,
    );

Engagement _sortant(int id, int? clientId, double montant, List<Reglement> regs) =>
    Engagement(
      id: id, sens: 'sortant', tiers: 'Fournisseur', clientId: clientId,
      montant: montant, echeance: DateTime(2026, 6, 1), reglements: regs,
    );

Reglement _r(double montant, DateTime date) =>
    Reglement(id: date.microsecondsSinceEpoch, date: date, montant: montant);

void main() {
  // Reproduction exacte du défaut : un client créé depuis l'écran (comme
  // `showClientDialog` le fait, `totalFacture: 0` avant ce correctif) reçoit
  // un vrai paiement — le CA affiché doit refléter ce paiement, pas rester
  // bloqué à 0 pour toujours.
  test('un client créé depuis l\'écran, sans historique stocké, affiche '
      'quand même son vrai chiffre d\'affaires', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addEngagement(_entrant(1, 1, 500000, [_r(500000, DateTime(2026, 4, 10))]));

    expect(s.chiffreAffairesClient(1), 500000);
  });

  test('un client sans aucun engagement a un chiffre d\'affaires nul', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));

    expect(s.chiffreAffairesClient(1), 0);
  });

  test('plusieurs engagements sur plusieurs projets s\'additionnent pour le '
      'même client', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addEngagement(_entrant(1, 1, 100000, [_r(100000, DateTime(2026, 1, 5))])
      ..projetId = 10);
    s.addEngagement(_entrant(2, 1, 250000, [_r(250000, DateTime(2026, 2, 5))])
      ..projetId = 20);
    // Un engagement encore en cours (aucun règlement) ne compte pas.
    s.addEngagement(_entrant(3, 1, 999999, const [])..projetId = 30);

    expect(s.chiffreAffairesClient(1), 350000);
  });

  test('un engagement entrant d\'un AUTRE client ne pollue pas le total', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addClient(_client(2, name: 'Autre'));
    s.addEngagement(_entrant(1, 1, 100000, [_r(100000, DateTime(2026, 1, 5))]));
    s.addEngagement(_entrant(2, 2, 999999, [_r(999999, DateTime(2026, 1, 5))]));

    expect(s.chiffreAffairesClient(1), 100000);
  });

  test('un engagement sortant ne compte jamais dans le chiffre d\'affaires '
      'd\'un client', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addEngagement(_sortant(1, 1, 100000, [_r(100000, DateTime(2026, 1, 5))]));

    expect(s.chiffreAffairesClient(1), 0);
  });

  // Cohérence avec Comptabilite (§ `_flux`, défaut 2 de cette même revue) :
  // un engagement annulé après un règlement réel garde ce règlement en base
  // caisse. Le chiffre d'affaires d'un client doit rester d'accord avec ce
  // que `Comptabilite` rapporte pour ses engagements, sans quoi les deux
  // écrans (Clients, Rapports) se contrediraient sur le même client.
  test('un engagement annulé après un règlement réel reste compté, comme '
      'dans Comptabilite', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addEngagement(_entrant(1, 1, 1000, [_r(300, DateTime(2026, 4, 1))],
        annule: true));

    expect(s.chiffreAffairesClient(1), 300);
  });

  // Défaut historique (déjà corrigé) : une proforma créée depuis l'écran
  // avant le correctif pouvait porter `clientId: 0`, propagé tel quel à
  // l'engagement généré à la validation. `0` ne correspond à aucun id de
  // client réel (`nextId()` démarre à 1) : ces engagements ne doivent
  // s'attribuer à AUCUN client, jamais planter la dérivation.
  test('un engagement hérité avec clientId 0 ne s\'attribue à aucun client réel', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(1));
    s.addEngagement(_entrant(1, 0, 100000, [_r(100000, DateTime(2026, 1, 5))]));

    expect(s.chiffreAffairesClient(1), 0);
    expect(s.chiffreAffairesClient(0), 100000);
  });
}
