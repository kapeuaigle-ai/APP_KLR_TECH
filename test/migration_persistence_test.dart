import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Store en mémoire qui trace, en plus des écritures normales, les écritures
/// du filet de sécurité v1 — voir les défauts 2 (la sauvegarde migrée n'est
/// jamais écrite sur le disque) et 3 (le filet `donnees.v1.json` promis par
/// la spec § 8 n'était jamais implémenté) de la revue finale de la Phase 1.
class MemoryStore implements Store {
  String? data;
  int writes = 0;
  String? backup;
  int backupWrites = 0;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async { data = d; writes++; }
  @override
  Future<void> writeBackup(String d) async { backup = d; backupWrites++; }
  @override
  Future<void> clear() async { data = null; }
}

/// Sauvegarde v1 minimale — pas de champ `version`, ce qui signifie v1.
/// `settings` doit être complet : `AppState.loadFromJson` (contrairement à
/// `migrerV1versV2` seul) reconstruit un vrai `AppSettings`, qui exige ses
/// champs obligatoires.
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
  // Le mois courant : celui d'aujourd'hui, pour que `verifierCloture` (appelé
  // par `init()` juste après le chargement) ne trouve rien à clôturer et
  // n'ajoute pas sa propre écriture — ce test porte uniquement sur celle de
  // la migration.
  'moisCourant': Comptabilite.monthKeyFromDate(DateTime.now()),
  'nextActivityId': 1000,
};

void main() {
  group('Défaut 2 — la sauvegarde migrée doit être écrite sur le store', () {
    test('charger une sauvegarde v1 écrit la version migrée exactement une fois', () async {
      final store = MemoryStore()..data = jsonEncode(_v1Minimal());
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 1);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 2);
    });

    test('charger une sauvegarde déjà en v2 n\'écrit rien', () async {
      final seed = AppState(store: const NoopStore());
      final v2Json = jsonEncode(seed.toJson());
      final store = MemoryStore()..data = v2Json;

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 0);
    });
  });

  group('Défaut 3 — filet de sécurité donnees.v1.json', () {
    test('charger une sauvegarde v1 conserve la donnée brute pré-migration, une seule fois', () async {
      final store = MemoryStore()..data = jsonEncode(_v1Minimal());
      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.backupWrites, 1);
      expect(jsonDecode(store.backup!), equals(_v1Minimal()));
    });

    test('charger une sauvegarde déjà en v2 n\'écrit aucun backup', () async {
      final seed = AppState(store: const NoopStore());
      final v2Json = jsonEncode(seed.toJson());
      final store = MemoryStore()..data = v2Json;

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.backupWrites, 0);
    });
  });
}
