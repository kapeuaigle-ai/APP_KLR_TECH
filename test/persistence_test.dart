import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Store en mémoire : simule le disque sans plugin path_provider.
class MemoryStore implements Store {
  String? data;
  int writes = 0;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async { data = d; writes++; }
  @override
  Future<void> clear() async { data = null; }
}

void main() {
  test('premier lancement : données d\'exemple présentes, activités vides', () {
    final s = AppState(store: MemoryStore());
    expect(s.clients, isNotEmpty);           // clients de démo conservés
    expect(s.documents['proforma'], isNotEmpty);
    expect(s.engagements, isNotEmpty);
    expect(s.activities, isEmpty);           // fil vidé des fausses entrées
  });

  test('round-trip : tout l\'état survit à une sauvegarde puis un rechargement', () async {
    final store = MemoryStore();
    final a = AppState(store: store);

    // Mutations variées.
    a.addClient(Client(id: 900, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'Client Persistant', contact: 'M. Test', email: 't@x.ci',
        phone: '0700', totalFacture: 42000, address: 'Abidjan'));
    a.addExpense(Expense(id: 901, date: DateTime(2026, 7, 24), label: 'Carburant',
        amount: 15000, category: 'Transport'));
    a.addEngagement(Engagement(id: 902, sens: 'dette', num: 'D-1', tiers: 'Fournisseur',
        description: 'Test', montant: 30000, statut: 'cours', echeance: '31/07/2026',
        categorie: 'Autres'));
    a.addDocument('proforma', DocumentItem(id: 903, numero: 'KLR-09-240726',
        date: '24/07/2026', clientId: 0, client: 'C', objet: 'O', montant: 1000,
        statut: 'cours', lines: [LineItem(ref: '01', designation: 'x', qte: 2, pu: 500)]));
    await a.flush();

    // Rechargement depuis le même store.
    final b = AppState(store: store);
    await b.init();

    expect(b.clients.any((c) => c.id == 900 && c.name == 'Client Persistant'), isTrue);
    expect(b.clients.firstWhere((c) => c.id == 900).color, const Color(0xFF123456));
    expect(b.expenses.any((e) => e.id == 901 && e.amount == 15000), isTrue);
    expect(b.expenses.firstWhere((e) => e.id == 901).date, DateTime(2026, 7, 24));
    expect(b.engagements.any((e) => e.id == 902 && e.sens == 'dette'), isTrue);
    final doc = b.documents['proforma']!.firstWhere((d) => d.id == 903);
    expect(doc.lines.single.pu, 500);
    // Les activités générées par les mutations sont aussi persistées.
    expect(b.activities, isNotEmpty);
    expect(b.activities.length, a.activities.length);
  });

  test('les activités du fil sont persistées et rechargées', () async {
    final store = MemoryStore();
    final a = AppState(store: store);
    a.addEngagement(Engagement(id: 1, sens: 'creance', num: 'C1', tiers: 'X',
        montant: 1000, statut: 'cours', echeance: '31/12/2026'));
    a.validerEngagement(1, '24/07/2026');
    await a.flush();

    final b = AppState(store: store);
    await b.init();
    expect(b.activities.any((x) => x.type == 'paiement'), isTrue);
  });

  test('réinitialiser efface la sauvegarde et repart du premier lancement', () async {
    final store = MemoryStore();
    final a = AppState(store: store);
    a.addClient(Client(id: 900, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'À effacer', contact: '', email: '', phone: '', totalFacture: 0));
    await a.flush();

    await a.resetData();
    expect(a.clients.any((c) => c.id == 900), isFalse); // client de test parti
    expect(a.clients, isNotEmpty);                      // seed de démo revenu
    expect(a.activities, isEmpty);

    // Le store est vidé : un rechargement redonne le premier lancement.
    final b = AppState(store: store);
    await b.init();
    expect(b.clients.any((c) => c.id == 900), isFalse);
  });

  test('init sans sauvegarde : garde le seed, ne plante pas', () async {
    final store = MemoryStore(); // vide
    final a = AppState(store: store);
    final avant = a.clients.length;
    await a.init();
    expect(a.clients.length, avant);
  });

  test('saveOrUpdateProforma : régénérer met à jour sans dupliquer ni re-journaliser', () {
    final a = AppState(store: MemoryStore());
    final avant = a.documents['proforma']!.length;

    a.saveOrUpdateProforma(DocumentItem(id: 999, numero: 'KLR-P01-25072026',
        date: '25/07/2026', clientId: 0, client: 'Client', objet: 'O',
        montant: 1000, statut: 'cours'));
    expect(a.documents['proforma']!.length, avant + 1);            // ajout
    expect(a.activities.where((x) => x.titre.contains('KLR-P01-25072026')).length, 1);

    // Même id (re-téléchargement après édition) : mise à jour du contenu.
    a.saveOrUpdateProforma(DocumentItem(id: 999, numero: 'KLR-P01-25072026',
        date: '25/07/2026', clientId: 0, client: 'Client modifié', objet: 'O2',
        montant: 2000, statut: 'cours'));
    expect(a.documents['proforma']!.length, avant + 1);            // pas de doublon
    expect(a.documents['proforma']!.firstWhere((d) => d.id == 999).client, 'Client modifié');
    expect(a.activities.where((x) => x.titre.contains('KLR-P01-25072026')).length, 1); // pas re-journalisé
  });
}
