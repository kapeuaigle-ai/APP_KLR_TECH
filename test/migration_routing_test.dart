import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/migration.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Store en mémoire qui trace les écritures — voir migration_persistence_test.dart
/// pour le même patron. Ce fichier couvre le ROUTAGE des versions, pas le
/// contenu des migrations individuelles : § « Défaut 1 » de la revue Lot A —
/// un routage par égalité exacte prend toute version inconnue (5, "4", une
/// valeur corrompue) pour une sauvegarde v1 et la détruit, puis écrit la
/// destruction sur le disque.
class MemoryStore implements Store {
  String? data;
  int writes = 0;
  String? backup;
  int backupWrites = 0;
  @override
  Future<String?> read() async => data;
  @override
  void write(String d) { data = d; writes++; }
  @override
  Future<void> writeBackup(String d) async { backup = d; backupWrites++; }
}

Map<String, dynamic> _v1Minimal() => {
  'clients': [],
  'documents': {'proforma': [], 'facture': [], 'bl': []},
  'engagements': [],
  'expenses': [],
  'activities': [], 'tasks': [], 'notes': [],
  'settings': {
    'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
    'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01', 'tva': 0.0,
    'conditions': '',
  },
  'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': Comptabilite.monthKeyFromDate(DateTime.now()),
  'nextActivityId': 1000,
};

/// Sauvegarde v4 bien formée portant un engagement entrant à un seul
/// règlement — c'est l'état que le défaut 1 corrompait (sens inversé,
/// règlements perdus) dès que la clé `version` ne valait exactement 4.
Map<String, dynamic> _v4AvecEngagement({required dynamic version}) {
  final j = _v1Minimal();
  j['version'] = version;
  j['projets'] = <Map<String, dynamic>>[];
  j['engagements'] = [
    {
      'id': 501,
      'sens': 'entrant',
      'projetId': null,
      'documentNumero': 'F-01',
      'clientId': null,
      'tiers': 'Client Test',
      'description': 'Vente matériel',
      'montant': 100000.0,
      'echeance': DateTime(2026, 12, 31).toIso8601String(),
      'categorie': 'Autres',
      'reglements': [
        {
          'id': 5011,
          'date': DateTime(2026, 6, 1).toIso8601String(),
          'montant': 100000.0,
          'moyen': 'especes',
        },
      ],
      'annule': false,
    },
  ];
  return j;
}

void main() {
  group('Routage par seuil — versions reconnues', () {
    test('version absente : chaîne complète v1 → v4 (le seul inconnu sûr)',
        () async {
      final store = MemoryStore()..data = jsonEncode(_v1Minimal());
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 1);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 4);
      expect(store.backupWrites, 1, reason: 'v1 brut sauvegardé (filet § 8)');
    });

    test('version 2 : migre v2 → v3 → v4, sans repasser par v1 → v2',
        () async {
      final j = _v4AvecEngagement(version: 2);
      final store = MemoryStore()..data = jsonEncode(j);
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(a.engagements.single.sens, 'entrant');
      expect(a.engagements.single.reglements.single.montant, 100000.0);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 4);
    });

    test('version 3 : migre v3 → v4 seulement', () async {
      final j = _v4AvecEngagement(version: 3);
      final store = MemoryStore()..data = jsonEncode(j);
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(a.engagements.single.sens, 'entrant');
      expect(a.engagements.single.reglements.single.montant, 100000.0);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 4);
    });

    test('version 4 : rechargée à l\'identique, ZÉRO écriture', () async {
      final j = _v4AvecEngagement(version: 4);
      final store = MemoryStore()..data = jsonEncode(j);
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(a.engagements.single.sens, 'entrant');
      expect(a.engagements.single.reglements.single.montant, 100000.0);
      expect(store.writes, 0, reason: 'sauvegarde déjà à jour : rien à réécrire');
      expect(store.backupWrites, 0);
    });
  });

  group('Défaut 1 — une version inconnue doit être REFUSÉE, jamais devinée', () {
    test('version 5 (future) : refusée — données intactes, ZÉRO écriture',
        () async {
      final j = _v4AvecEngagement(version: 5);
      final brutAvant = jsonEncode(j);
      final store = MemoryStore()..data = brutAvant;
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      // Preuve par le store, pas par la lecture du code : aucune écriture
      // n'a eu lieu, ni sur le fichier principal ni sur le backup.
      expect(store.writes, 0,
          reason: 'un fichier plus récent que l\'app ne doit jamais être '
              'réécrit — la donnée réelle serait perdue');
      expect(store.data, brutAvant, reason: 'le disque reste inchangé au bit près');

      // Le chargement a été refusé avant même de commencer à peupler l'état :
      // l'engagement du fichier refusé (id 501) — corrompu ou non — ne doit
      // apparaître nulle part en mémoire. L'app reste sur son seed de
      // démarrage (qui, lui, contient légitimement des engagements
      // 'sortant' — ce n'est pas ce qu'on vérifie ici).
      expect(a.engagements.any((e) => e.id == 501), isFalse);

      // La situation est surfacée, pas juste avalée en silence : l'UI peut
      // lire ce drapeau pour avertir le manager.
      expect(a.sauvegardeRefusee, isTrue);
      expect(a.versionSauvegardeRefusee, 5);
    });

    test('loadFromJson lève SauvegardeVersionRefuseeException pour une '
        'version supérieure à la version courante', () {
      final a = AppState(store: const NoopStore());
      expect(
        () => a.loadFromJson(_v4AvecEngagement(version: 42)),
        throwsA(isA<SauvegardeVersionRefuseeException>()),
      );
    });

    test('version "4" (chaîne) : traitée comme inconnue, pas comme v1',
        () async {
      final j = _v4AvecEngagement(version: '4');
      final brutAvant = jsonEncode(j);
      final store = MemoryStore()..data = brutAvant;
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 0);
      expect(store.data, brutAvant);
    });

    test('version corrompue (garbage) : traitée comme inconnue, pas comme v1',
        () async {
      final j = _v4AvecEngagement(version: {'oops': true});
      final brutAvant = jsonEncode(j);
      final store = MemoryStore()..data = brutAvant;
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 0);
      expect(store.data, brutAvant);
    });
  });
}
