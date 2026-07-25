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
    final s = AppState();
    s.addExpense(Expense(id: 1, date: DateTime(2026, 7, 24), label: 'Carburant',
        amount: 45000, category: 'Transport'));
    expect(s.activities.first.type, 'comptabilite');
    expect(s.activities.first.titre, contains('Carburant'));
  });

  test('ajouter / supprimer un client journalise une activité', () {
    final s = AppState();
    s.addClient(Client(id: 999, initials: 'NC', color: const Color(0xFF112233),
        name: 'Nouveau Client', contact: 'M. X', email: '', phone: '', totalFacture: 0));
    expect(s.activities.first.type, 'client');
    expect(s.activities.first.titre, contains('Nouveau Client'));

    s.deleteClient(999);
    expect(s.activities.first.titre, contains('supprimé'));
  });
}
