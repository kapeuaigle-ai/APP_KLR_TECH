import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

Client _client({int id = 5}) => Client(
      id: id, initials: 'AC', color: Colors.blue, name: 'ACME',
      contact: 'Jean', email: 'j@acme.cm', phone: '600', totalFacture: 0,
    );

Projet _projet(int id, int? clientId) => Projet(
      id: id, nom: 'Fourniture matériel',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites,
      clientId: clientId, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

Engagement _engagement(int id, int? clientId) => Engagement(
      id: id, sens: 'entrant', tiers: 'ACME', clientId: clientId,
      montant: 1000, echeance: DateTime(2026, 6, 1),
    );

void main() {
  // Défaut 3 : Projet.clientId et Engagement.clientId sont des int? avec la
  // même convention « null = aucun » que Projet.projetId sur les documents
  // et les engagements — déjà nettoyée par deleteProjet. Supprimer un client
  // doit appliquer le même traitement, sinon les deux pointent vers un id
  // qui n'existe plus.
  test('supprimer un client délie les projets et les engagements qui le désignaient', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client());
    s.addProjet(_projet(1, 5));
    s.addEngagement(_engagement(9, 5));

    s.deleteClient(5);

    expect(s.projets.first.clientId, isNull);
    expect(s.engagements.first.clientId, isNull,
        reason: 'un engagement ne doit jamais pointer vers un client disparu');
  });

  test('le nom du client dénormalisé survit à la suppression', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client());
    s.addProjet(_projet(1, 5));

    s.deleteClient(5);

    // `client` (le nom) enregistre qui était la contrepartie : il reste,
    // seul l'id qui ne pointe plus vers rien est nettoyé.
    expect(s.projets.first.client, 'ACME');
  });

  test('supprimer un client n\'affecte pas les projets et engagements d\'un autre client', () {
    final s = AppState()..viderDonnees();
    s.addClient(_client(id: 5));
    s.addClient(_client(id: 6));
    s.addProjet(_projet(1, 5));
    s.addProjet(_projet(2, 6));
    s.addEngagement(_engagement(9, 6));

    s.deleteClient(5);

    expect(s.projets.firstWhere((p) => p.id == 2).clientId, 6);
    expect(s.engagements.first.clientId, 6);
  });
}
