import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Store en mémoire : simule le disque sans plugin path_provider.
class MemoryStore implements Store {
  String? data;
  int writes = 0;
  /// Nombre de prochains appels à `write` qui doivent échouer, avant de
  /// revenir à un comportement normal — simule une panne transitoire
  /// (verrou antivirus, disque plein) pour les tests du défaut 1.
  int failNextWrites = 0;
  @override
  Future<String?> read() async => data;
  @override
  void write(String d) {
    if (failNextWrites > 0) {
      failNextWrites--;
      throw Exception('échec d\'écriture simulé');
    }
    data = d; writes++;
  }
  @override
  Future<void> writeBackup(String d) async {}
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
        phone: '0700', address: 'Abidjan'));
    // `Expense` a disparu (tâche 2) : une dépense est un engagement sortant
    // créé ET réglé le jour même — voir `AppState.ajouterReglement`.
    a.addEngagement(Engagement(id: 901, sens: 'sortant', tiers: 'Carburant',
        montant: 15000, echeance: DateTime(2026, 7, 24), categorie: 'Transport'));
    a.ajouterReglement(901, 15000, DateTime(2026, 7, 24));
    // `Engagement.num`/`statut`/`echeance` (String) ont disparu avec l'ancien
    // modèle (tâche 2) : la référence libre rejoint `documentNumero`, `sens`
    // devient 'entrant'/'sortant', `echeance` est un DateTime.
    a.addEngagement(Engagement(id: 902, sens: 'sortant', documentNumero: 'D-1', tiers: 'Fournisseur',
        description: 'Test', montant: 30000, echeance: DateTime(2026, 7, 31),
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
    expect(b.engagements.any((e) => e.id == 901 && e.regle == 15000), isTrue);
    expect(b.engagements.firstWhere((e) => e.id == 901).reglements.single.date, DateTime(2026, 7, 24));
    expect(b.engagements.any((e) => e.id == 902 && e.sens == 'sortant'), isTrue);
    final doc = b.documents['proforma']!.firstWhere((d) => d.id == 903);
    expect(doc.lines.single.pu, 500);
    // Les activités générées par les mutations sont aussi persistées.
    expect(b.activities, isNotEmpty);
    expect(b.activities.length, a.activities.length);
  });

  test('les activités du fil sont persistées et rechargées', () async {
    final store = MemoryStore();
    final a = AppState(store: store);
    a.addEngagement(Engagement(id: 1, sens: 'entrant', documentNumero: 'C1', tiers: 'X',
        montant: 1000, echeance: DateTime(2026, 12, 31)));
    a.ajouterReglement(1, 1000, DateTime(2026, 7, 24));
    await a.flush();

    final b = AppState(store: store);
    await b.init();
    expect(b.activities.any((x) => x.type == 'paiement'), isTrue);
  });

  test('réinitialiser vide toutes les données métier', () async {
    final store = MemoryStore();
    final a = AppState(store: store);
    a.addClient(Client(id: 900, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'À effacer', contact: '', email: '', phone: ''));
    await a.flush();

    await a.resetData();
    expect(a.clients, isEmpty);                    // y compris les clients de démo
    expect(a.documents['proforma'], isEmpty);
    expect(a.documents['facture'], isEmpty);
    expect(a.documents['bl'], isEmpty);
    // `expenses` a disparu (tâche 2) : les dépenses sont des engagements,
    // déjà couverts par `a.engagements` ci-dessus.
    expect(a.engagements, isEmpty);
    expect(a.activities, isEmpty);
    expect(a.tasks, isEmpty);
    expect(a.notes, isEmpty);
  });

  test('réinitialiser conserve les réglages (accès, entreprise, signature)', () async {
    final a = AppState(store: MemoryStore());
    a.settings.company = 'MON ENTREPRISE';
    a.settings.signatureLabel = 'La Direction';
    a.changeCredentials(currentPassword: 'admin', newPassword: 'Secret#2026');

    await a.resetData();

    expect(a.settings.company, 'MON ENTREPRISE');
    expect(a.settings.signatureLabel, 'La Direction');
    expect(a.settings.checkPassword('Secret#2026'), isTrue); // pas de retour à admin
  });

  test('l\'application reste vide après redémarrage (pas de retour des démos)', () async {
    final store = MemoryStore();
    final a = AppState(store: store);
    await a.resetData();

    // Piège corrigé : le constructeur sème les données d'exemple, donc l'état
    // vide doit être ÉCRIT, sinon init() ne trouve rien et les démos reviennent.
    final b = AppState(store: store);
    await b.init();
    expect(b.clients, isEmpty);
    expect(b.documents['proforma'], isEmpty);
    expect(b.engagements, isEmpty);
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

  // ── Défaut 1 (revue finitions) : écriture qui échoue rendue visible ──
  //
  // `AppState._persist` avalait toute erreur d'écriture (`catchError((_) {})`
  // sans rien d'autre) : un disque plein ou un verrou antivirus disparaissait
  // en silence, alors que `notifyListeners()` avait déjà dit à l'interface
  // que la mutation avait réussi. Le manager continuait de travailler en
  // croyant, à tort, que tout était sauvegardé.
  group('échec d\'écriture rendu visible (défaut 1, revue finitions)', () {
    Client client(int id) => Client(id: id, initials: 'ZZ',
        color: const Color(0xFF123456), name: 'Client $id', contact: '',
        email: '', phone: '');

    test('l\'app reste utilisable après un échec, et le signal passe à vrai', () async {
      final store = MemoryStore()..failNextWrites = 1;
      final a = AppState(store: store);
      expect(a.derniereEcritureEnEchec, isFalse);

      a.addClient(client(900));
      await a.flush();

      expect(a.derniereEcritureEnEchec, isTrue);
      // La mutation en mémoire a bien eu lieu : l'app reste utilisable, ce
      // n'est que la sauvegarde sur disque qui a échoué.
      expect(a.clients.any((c) => c.id == 900), isTrue);
    });

    test('l\'échec déclenche notifyListeners (c\'est ce qui fait apparaître la bannière)', () async {
      final store = MemoryStore()..failNextWrites = 1;
      final a = AppState(store: store);
      var notifs = 0;
      a.addListener(() => notifs++);

      a.addClient(client(900));
      await a.flush();

      expect(notifs, greaterThan(0));
    });

    test('une écriture réussie qui suit efface le signal (panne transitoire)', () async {
      final store = MemoryStore()..failNextWrites = 1;
      final a = AppState(store: store);
      a.addClient(client(900));
      await a.flush();
      expect(a.derniereEcritureEnEchec, isTrue);

      // Nouvelle mutation, cette fois sans panne : le signal doit disparaître
      // de lui-même — une bannière qui reste affichée après que tout est
      // rentré dans l'ordre ferait plus peur qu'elle n'informe.
      a.addClient(client(901));
      await a.flush();

      expect(a.derniereEcritureEnEchec, isFalse);
    });

    test('retryPersist relance l\'écriture et efface le signal si elle réussit', () async {
      final store = MemoryStore()..failNextWrites = 1;
      final a = AppState(store: store);
      a.addClient(client(900));
      await a.flush();
      expect(a.derniereEcritureEnEchec, isTrue);
      final ecrituresAvant = store.writes;

      a.retryPersist();
      await a.flush();

      expect(a.derniereEcritureEnEchec, isFalse);
      expect(store.writes, ecrituresAvant + 1);
    });

    test('deux échecs consécutifs laissent le signal à vrai jusqu\'au succès', () async {
      final store = MemoryStore()..failNextWrites = 2;
      final a = AppState(store: store);
      a.addClient(client(900));
      await a.flush();
      expect(a.derniereEcritureEnEchec, isTrue);

      a.retryPersist(); // deuxième échec programmé
      await a.flush();
      expect(a.derniereEcritureEnEchec, isTrue);

      a.retryPersist(); // plus d'échec programmé : réussit
      await a.flush();
      expect(a.derniereEcritureEnEchec, isFalse);
    });
  });

  // ── Écriture synchrone (lot G, défaut 1) ────────────────────────────
  //
  // `AppState._persist` écrivait auparavant en fire-and-forget via une file
  // chaînée (`_writeChain`) : rien ne garantissait qu'une mutation avait
  // atteint le disque au moment où l'appel qui l'a déclenchée rendait la
  // main — un risque réel de perte si la fenêtre se fermait juste après (le
  // hook `AppExitFlusher` censé combler ça ne se déclenchait jamais sur
  // Windows). `Store.write` est maintenant synchrone : ces tests vérifient
  // qu'il n'y a plus jamais rien « en attente » — sans le moindre `await`.
  group('écriture synchrone : rien en attente après une mutation (lot G, défaut 1)', () {
    Client client(int id) => Client(id: id, initials: 'ZZ',
        color: const Color(0xFF123456), name: 'Client $id', contact: '',
        email: '', phone: '');

    test('une mutation est déjà sur le store juste après l\'appel, sans await ni flush', () {
      final store = MemoryStore();
      final a = AppState(store: store);

      a.addClient(client(900)); // synchrone, aucun `await` ici

      // Si l'écriture était encore fire-and-forget, `store.data` serait
      // encore celui d'avant la mutation (ou null) à cet instant précis.
      expect(store.data, isNotNull);
      expect(store.data!.contains('Client 900'), isTrue);
      expect(store.writes, 1);
    });

    test('plusieurs mutations synchrones successives sont toutes déjà sur le store', () {
      final store = MemoryStore();
      final a = AppState(store: store);

      a.addClient(client(900));
      a.addClient(client(901));
      a.addClient(client(902));

      expect(store.writes, 3);
      expect(store.data!.contains('Client 900'), isTrue);
      expect(store.data!.contains('Client 901'), isTrue);
      expect(store.data!.contains('Client 902'), isTrue);
    });

    test('une écriture qui échoue lève synchronement et la bannière est signalée sans await', () {
      final store = MemoryStore()..failNextWrites = 1;
      final a = AppState(store: store);

      a.addClient(client(900)); // l'exception de `write` est déjà avalée par `_persist`

      expect(a.derniereEcritureEnEchec, isTrue);
      // La mutation en mémoire n'en dépend pas : l'app reste utilisable.
      expect(a.clients.any((c) => c.id == 900), isTrue);
    });
  });
}
