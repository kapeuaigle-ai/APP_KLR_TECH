import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';
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
      // v1 traverse maintenant v1 → v2 → v3 → v4 en un seul chargement : la
      // version persistée est la version courante de l'app (4), pas une
      // étape intermédiaire.
      expect(relu['version'], 4);
    });

    test('charger une sauvegarde déjà à jour n\'écrit rien', () async {
      final seed = AppState(store: const NoopStore());
      final v4Json = jsonEncode(seed.toJson());
      final store = MemoryStore()..data = v4Json;

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

    test('charger une sauvegarde déjà à jour n\'écrit aucun backup', () async {
      final seed = AppState(store: const NoopStore());
      final v4Json = jsonEncode(seed.toJson());
      final store = MemoryStore()..data = v4Json;

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.backupWrites, 0);
    });
  });

  group('v2 → v3 — pas de nouveau filet de sécurité', () {
    // Décision : contrairement à v1 → v2 (qui fond quatre mécanismes d'argent
    // disjoints en Engagement + Reglement — une restructuration qu'on ne peut
    // plus reconstituer depuis la sortie), v2 → v3 ne fait que recalculer un
    // champ DÉRIVÉ (`DocumentItem.montant`) à partir de données qui restent
    // toutes les deux dans la sauvegarde migrée (les `lines`). Rien n'est
    // perdu, donc rien à sauvegarder à part — et le fichier `klr_data.v1.json`
    // du filet existant est nommément celui du v1 brut ; le detourner pour un
    // second usage (v2 brut) sèmerait la confusion sur ce qu'il contient
    // vraiment, pour un cas qui ne le justifie pas.
    test('charger une sauvegarde v2 migre sans écrire de backup', () async {
      final v2 = _v1Minimal();
      v2['version'] = 2;
      v2['projets'] = <Map<String, dynamic>>[];
      final store = MemoryStore()..data = jsonEncode(v2);

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.backupWrites, 0);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 4);
      expect((relu['settings'] as Map).containsKey('tva'), isFalse);
    });
  });

  group('v3 → v4 — pas de nouveau filet de sécurité non plus', () {
    // Même raisonnement que v2 → v3 : le registre `settings.typesProjet` est
    // redistribué (son libellé et son mode copiés sur chaque projet), rien
    // n'est perdu qui ne survive déjà ailleurs dans la sauvegarde migrée.
    test('charger une sauvegarde v3 migre sans écrire de backup', () async {
      final v3 = _v1Minimal();
      v3['version'] = 3;
      v3['projets'] = <Map<String, dynamic>>[
        {
          'id': 1, 'nom': 'Câblage', 'typeId': 'fourniture',
          'clientId': null, 'client': '',
          'debut': DateTime(2026, 1, 1).toIso8601String(),
          'finPrevue': DateTime(2026, 6, 30).toIso8601String(),
          'jalons': [], 'avancementManuel': 0, 'annule': false,
        },
      ];
      (v3['settings'] as Map)['typesProjet'] = [
        {'id': 'fourniture', 'libelle': 'Fourniture de matériel', 'mode': 'quantites', 'couleur': 0xFF2563EB},
      ];
      final store = MemoryStore()..data = jsonEncode(v3);

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.backupWrites, 0);
      final relu = jsonDecode(store.data!) as Map<String, dynamic>;
      expect(relu['version'], 4);
      expect((relu['settings'] as Map).containsKey('typesProjet'), isFalse);
      final projet = (relu['projets'] as List).first as Map<String, dynamic>;
      expect(projet['type'], 'Fourniture de matériel');
      expect(projet['mode'], 'quantites');
    });
  });

  group('v4 — une sauvegarde déjà à jour traverse le chargement sans y toucher', () {
    test('charger une sauvegarde v4 la restitue à l\'identique', () async {
      final seed = AppState(store: const NoopStore())..viderDonnees();
      seed.addProjet(Projet(
        id: 1, nom: 'Câblage', type: 'Fourniture de matériel',
        mode: ModeAvancement.quantites, clientId: null, client: '',
        debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 6, 30),
      ));
      final v4Json = jsonEncode(seed.toJson());
      final store = MemoryStore()..data = v4Json;

      final a = AppState(store: store);
      await a.init();
      await a.flush();

      expect(store.writes, 0);
      expect(store.backupWrites, 0);
      expect(a.projets.first.type, 'Fourniture de matériel');
      expect(a.projets.first.mode, ModeAvancement.quantites);
    });
  });
}
