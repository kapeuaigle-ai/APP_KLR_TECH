import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('le fil démarre vide (plus de fausses entrées d\'équipe)', () {
    expect(AppState().activities, isEmpty);
  });

  test('créer une proforma journalise une activité', () {
    final s = AppState();
    s.addDocument('proforma', DocumentItem(id: 1, numero: 'KLR-01-240726',
        date: '24/07/2026', clientId: 0, client: 'Advans', objet: 'Réseau',
        montant: 500000, statut: 'cours'));
    expect(s.activities.first.type, 'document');
    expect(s.activities.first.titre, contains('KLR-01-240726'));
    // Auteur = l'entreprise du manager, pas un faux collègue.
    expect(s.activities.first.auteur, s.settings.company);
  });

  test('générer facture+BL par validation journalise une activité', () {
    final s = AppState();
    s.addDocument('proforma', DocumentItem(id: 7, numero: 'KLR-07-240726',
        date: '24/07/2026', clientId: 0, client: 'C', objet: 'O',
        montant: 1000, statut: 'cours'));
    final avant = s.activities.length;
    s.validateProforma(7);
    expect(s.activities.length, avant + 1);
    expect(s.activities.first.type, 'facture');
    expect(s.activities.first.titre, contains('validée'));
  });

  test('ajouter une dépense journalise une activité', () {
    // `Expense`/`addExpense` ont disparu (tâche 2) : une dépense est un
    // engagement sortant créé ET réglé le jour même. C'est `ajouterReglement`
    // qui journalise (type 'paiement', pas 'comptabilite') — `addEngagement`
    // seul ne journalise rien. Le libellé saisi devient le `tiers` de
    // l'engagement, et apparaît donc dans le détail de l'activité, pas son
    // titre (générique : « Décaissement — … »).
    final s = AppState();
    s.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Carburant',
        montant: 45000, echeance: DateTime(2026, 7, 24), categorie: 'Transport'));
    s.ajouterReglement(1, 45000, DateTime(2026, 7, 24));
    expect(s.activities.first.type, 'paiement');
    expect(s.activities.first.desc, contains('Carburant'));
  });

  test('ajouter / supprimer un client journalise une activité', () {
    final s = AppState();
    s.addClient(Client(id: 999, initials: 'NC', color: const Color(0xFF112233),
        name: 'Nouveau Client', contact: 'M. X', email: '', phone: ''));
    expect(s.activities.first.type, 'client');
    expect(s.activities.first.titre, contains('Nouveau Client'));

    s.deleteClient(999);
    expect(s.activities.first.titre, contains('supprimé'));
  });

  // ── Défaut 3 (Lot C) ────────────────────────────────────
  // `deleteEngagement` et `supprimerReglement` mutaient l'état sans jamais
  // appeler `_logActivity`, contrairement à toute autre mutation touchant de
  // l'argent réel : un engagement soldé pouvait disparaître sans laisser de
  // trace dans le fil d'Activités, l'unique piste d'audit de l'app.
  test('supprimer un engagement journalise une activité nommant tiers, montant et réglé', () {
    final s = AppState()..viderDonnees();
    s.addEngagement(Engagement(id: 1, sens: 'sortant', tiers: 'Fournisseur Ancien',
        montant: 100000, echeance: DateTime(2026, 3, 1)));
    s.ajouterReglement(1, 60000, DateTime(2026, 3, 3));
    final avant = s.activities.length;

    s.deleteEngagement(1);

    expect(s.activities.length, avant + 1);
    final a = s.activities.first;
    expect(a.titre, contains('Fournisseur Ancien'));
    expect(a.desc, contains('100'), reason: 'le montant attendu doit être reconstituable');
    expect(a.desc, contains('60'), reason: 'ce qui avait déjà été réglé doit être reconstituable');
  });

  test('supprimer un engagement sans règlement journalise quand même une activité', () {
    final s = AppState()..viderDonnees();
    s.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'Client Vide',
        montant: 5000, echeance: DateTime(2026, 3, 1)));
    final avant = s.activities.length;

    s.deleteEngagement(1);

    expect(s.activities.length, avant + 1);
    expect(s.activities.first.titre, contains('Client Vide'));
  });

  test('supprimer un engagement inexistant ne journalise rien', () {
    final s = AppState()..viderDonnees();
    final avant = s.activities.length;
    s.deleteEngagement(999);
    expect(s.activities.length, avant);
  });

  test('supprimer un règlement journalise une activité nommant sa date et son montant', () {
    final s = AppState()..viderDonnees();
    s.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
        montant: 1000, echeance: DateTime(2026, 6, 30)));
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 200, DateTime(2026, 4, 3));
    final cible = s.engagements.first.reglements.first.id;
    final avant = s.activities.length;

    s.supprimerReglement(1, cible);

    expect(s.activities.length, avant + 1);
    expect(s.activities.first.desc, contains('400'));
  });

  test('supprimer un règlement inexistant ne journalise rien', () {
    final s = AppState()..viderDonnees();
    s.addEngagement(Engagement(id: 1, sens: 'entrant', tiers: 'ACME',
        montant: 1000, echeance: DateTime(2026, 6, 30)));
    final avant = s.activities.length;
    s.supprimerReglement(1, 999);
    expect(s.activities.length, avant);
  });
}
