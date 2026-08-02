# Phase 1 — Socle financier unifié : Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les quatre mécanismes d'enregistrement de l'argent (`facture.encaissee`, créance, dette, `Expense`) par deux notions uniques — `Engagement` et `Reglement` — sans changer un seul chiffre affiché.

**Architecture:** Un engagement est une promesse de flux (montant attendu, sens, échéance). Un règlement est un mouvement réel (montant, date). La comptabilité ne lit plus que les règlements. Une migration JSON pure convertit les sauvegardes v1 en v2, et le critère de réussite est l'égalité au centime près des bilans avant/après.

**Tech Stack:** Flutter/Dart, `provider` pour l'état, persistance JSON fichier, `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-07-28-architecture-projet-flux-design.md`](../specs/2026-07-28-architecture-projet-flux-design.md) — sections 3, 5.1, 6.5, 8, 9, 10 (phase 1), 13.

---

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `lib/core/models/client.dart` | `Client` |
| `lib/core/models/document.dart` | `DocumentItem`, `LineItem` |
| `lib/core/models/engagement.dart` | `Engagement`, `Reglement`, `kCategoriesDepense` |
| `lib/core/models/divers.dart` | `Task`, `Note`, `ActivityItem`, `DimeEntry`, `Employee`, `Department`, `ProjectCard` |
| `lib/core/models/settings.dart` | `AppSettings`, `kDefaultWarranty` |
| `lib/core/models/commun.dart` | `colorToInt`, `colorFromInt`, `NavScreen` |
| `lib/core/models.dart` | Réexport de tout ce qui précède — aucun import existant ne casse |
| `lib/core/migration.dart` | `migrerV1versV2` — conversion JSON pure, sans dépendance aux modèles |
| `lib/core/comptabilite.dart` | Réécrit : ne lit que les règlements |
| `lib/core/app_state.dart` | API de règlements, migration au chargement |
| `lib/screens/suivi_screen.dart` | Saisie de règlements multiples ; dépenses devenues engagements sortants |

**Ordre imposé :** tâche 1 (découpage) avant tout, car toutes les suivantes éditent des fichiers qui n'existent pas encore. Tâche 3 (migration) avant la tâche 5 (comptabilité), car le test de non-régression de la comptabilité s'appuie sur la migration.

---

## Task 1: Découper models.dart sans changer un octet de comportement

**Files:**
- Create: `lib/core/models/commun.dart`, `lib/core/models/client.dart`, `lib/core/models/document.dart`, `lib/core/models/engagement.dart`, `lib/core/models/divers.dart`, `lib/core/models/settings.dart`
- Modify: `lib/core/models.dart` (devient un réexport)

- [ ] **Step 1: Vérifier l'état de départ — toute la suite doit être verte**

Run: `flutter test`
Expected: PASS, aucun échec. Si un test échoue déjà, arrêter et signaler : le découpage ne doit pas être fait sur une base rouge.

- [ ] **Step 2: Créer `lib/core/models/commun.dart`**

```dart
import 'package:flutter/material.dart';

/// Encodage couleur ⇄ entier ARGB, pour la persistance JSON.
int colorToInt(Color c) => c.toARGB32();
Color colorFromInt(int v) => Color(v);

/// Conversion JSON → double, tolérante aux entiers.
double toDouble(dynamic v) => (v as num).toDouble();

// ── Nav Screen enum ──────────────────────────────────────
enum NavScreen {
  dashboard, documents, clients, projets, suivi, activites, rapports,
  parametres, gantt, documentCreate,
}
```

- [ ] **Step 3: Déplacer les classes dans leurs fichiers**

Découper le contenu actuel de `lib/core/models.dart` **sans en modifier une ligne de logique**, chaque fichier important ce dont il a besoin :

- `client.dart` ← `Client` (importe `commun.dart`, `package:flutter/material.dart`)
- `document.dart` ← `DocumentItem`, `LineItem` (importe `commun.dart`)
- `engagement.dart` ← `Engagement`, `Expense` (importe `commun.dart`)
- `divers.dart` ← `Employee`, `Department`, `DimeEntry`, `Task`, `Note`, `ActivityItem`, `ProjectCard` (importe `commun.dart`, `material.dart`)
- `settings.dart` ← `AppSettings`, `kDefaultWarranty` (importe `../auth.dart`)

`Engagement` utilise aujourd'hui la fonction privée `_toDouble` ; la remplacer par `toDouble` de `commun.dart`. C'est la seule retouche autorisée à cette étape.

- [ ] **Step 4: Transformer `lib/core/models.dart` en réexport**

```dart
/// Réexport des modèles, découpés par couche depuis le 28/07/2026.
/// Les imports existants (`import '../core/models.dart';`) restent valides.
export 'models/commun.dart';
export 'models/client.dart';
export 'models/document.dart';
export 'models/engagement.dart';
export 'models/divers.dart';
export 'models/settings.dart';
```

- [ ] **Step 5: Vérifier qu'absolument rien n'a bougé**

Run: `flutter analyze; flutter test`
Expected: `flutter analyze` sans erreur, `flutter test` PASS avec le **même nombre de tests réussis** qu'à l'étape 1.

- [ ] **Step 6: Commit**

```bash
git add lib/core/models.dart lib/core/models/
git commit -m "refactor: decouper models.dart par couche, models.dart devient un reexport"
```

---

## Task 2: Le modèle Reglement et le nouvel Engagement

**Files:**
- Modify: `lib/core/models/engagement.dart`
- Test: `test/engagement_reglement_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/engagement_reglement_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _eng({
  double montant = 1000,
  String sens = 'entrant',
  List<Reglement>? reglements,
  DateTime? echeance,
  bool annule = false,
}) =>
    Engagement(
      id: 1, sens: sens, tiers: 'ACME', montant: montant,
      echeance: echeance ?? DateTime(2026, 6, 30),
      reglements: reglements, annule: annule,
    );

Reglement _reg(double montant, DateTime date, {int id = 1}) =>
    Reglement(id: id, date: date, montant: montant);

void main() {
  test('sans règlement, tout reste dû', () {
    final e = _eng();
    expect(e.regle, 0);
    expect(e.reste, 1000);
    expect(e.solde, isFalse);
  });

  test('deux règlements partiels s\'additionnent', () {
    final e = _eng(reglements: [
      _reg(300, DateTime(2026, 5, 2), id: 1),
      _reg(200, DateTime(2026, 6, 4), id: 2),
    ]);
    expect(e.regle, 500);
    expect(e.reste, 500);
    expect(e.solde, isFalse);
  });

  test('les règlements couvrant le montant soldent l\'engagement', () {
    final e = _eng(reglements: [_reg(1000, DateTime(2026, 5, 2))]);
    expect(e.reste, 0);
    expect(e.solde, isTrue);
  });

  test('le reste ne devient jamais négatif', () {
    final e = _eng(reglements: [_reg(1500, DateTime(2026, 5, 2))]);
    expect(e.reste, 0);
    expect(e.solde, isTrue);
  });

  test('enRetard compare à la date fournie, pas à aujourd\'hui', () {
    final e = _eng(echeance: DateTime(2026, 6, 30));
    expect(e.enRetard(DateTime(2026, 6, 29)), isFalse);
    expect(e.enRetard(DateTime(2026, 6, 30)), isFalse, reason: 'le jour même n\'est pas un retard');
    expect(e.enRetard(DateTime(2026, 7, 1)), isTrue);
  });

  test('un engagement soldé ou annulé n\'est jamais en retard', () {
    final solde = _eng(reglements: [_reg(1000, DateTime(2026, 5, 2))]);
    expect(solde.enRetard(DateTime(2027, 1, 1)), isFalse);
    final annule = _eng(annule: true);
    expect(annule.enRetard(DateTime(2027, 1, 1)), isFalse);
  });

  test('sens : estEntrant distingue créance et dette', () {
    expect(_eng(sens: 'entrant').estEntrant, isTrue);
    expect(_eng(sens: 'sortant').estEntrant, isFalse);
  });

  test('aller-retour JSON complet, règlements compris', () {
    final e = Engagement(
      id: 7, sens: 'sortant', tiers: 'Fournisseur X', montant: 2500,
      echeance: DateTime(2026, 8, 15), description: 'Switches',
      categorie: 'Achat matériel', projetId: 3, documentNumero: 'KLR-F02-10012026',
      clientId: null,
      reglements: [_reg(1000, DateTime(2026, 7, 20), id: 11)],
    );
    final copie = Engagement.fromJson(e.toJson());
    expect(copie.id, 7);
    expect(copie.sens, 'sortant');
    expect(copie.tiers, 'Fournisseur X');
    expect(copie.montant, 2500);
    expect(copie.echeance, DateTime(2026, 8, 15));
    expect(copie.description, 'Switches');
    expect(copie.categorie, 'Achat matériel');
    expect(copie.projetId, 3);
    expect(copie.documentNumero, 'KLR-F02-10012026');
    expect(copie.reglements.length, 1);
    expect(copie.reglements.first.id, 11);
    expect(copie.reglements.first.montant, 1000);
    expect(copie.reglements.first.date, DateTime(2026, 7, 20));
    expect(copie.regle, 1000);
    expect(copie.reste, 1500);
  });

  test('aller-retour JSON d\'un règlement, moyen compris', () {
    final r = Reglement(id: 3, date: DateTime(2026, 3, 9), montant: 450, moyen: 'virement');
    final copie = Reglement.fromJson(r.toJson());
    expect(copie.id, 3);
    expect(copie.date, DateTime(2026, 3, 9));
    expect(copie.montant, 450);
    expect(copie.moyen, 'virement');
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/engagement_reglement_test.dart`
Expected: FAIL — erreurs de compilation, `Reglement` n'est pas défini et `Engagement` n'a pas ces paramètres.

- [ ] **Step 3: Réécrire `lib/core/models/engagement.dart`**

Remplacer intégralement le contenu du fichier :

```dart
import 'commun.dart';

/// Catégories analytiques d'un décaissement. Remplace `Expense.categories`.
const kCategoriesDepense = [
  'Achat matériel', 'Transport', 'Sous-traitance',
  'Loyer & charges', 'Salaires', 'Autres',
];

/// Un mouvement d'argent réel, daté. Partiel ou total.
///
/// C'est le SEUL objet qui fait bouger la comptabilité : un règlement d'un
/// engagement entrant est un encaissement, celui d'un sortant un décaissement.
class Reglement {
  final int id;
  DateTime date;
  double montant;
  String moyen; // 'especes' | 'virement' | 'mobile' | 'cheque'

  Reglement({
    required this.id, required this.date, required this.montant,
    this.moyen = 'especes',
  });

  static const moyens = ['especes', 'virement', 'mobile', 'cheque'];

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(),
    'montant': montant, 'moyen': moyen,
  };

  factory Reglement.fromJson(Map<String, dynamic> j) => Reglement(
    id: j['id'], date: DateTime.parse(j['date']),
    montant: toDouble(j['montant']), moyen: j['moyen'] ?? 'especes',
  );
}

/// Une promesse de flux : un montant attendu, dans un sens, à une échéance.
///
/// Remplace à lui seul les quatre mécanismes d'avant : la créance, la dette,
/// la facture encaissée et la dépense au comptant. Tout ce qui était `statut`,
/// `acompte` ou `dateReglement` se déduit désormais de [reglements].
class Engagement {
  final int id;
  final String sens;        // 'entrant' | 'sortant'
  int? projetId;            // null = hors projet
  String? documentNumero;   // facture d'origine, ou pièce fournisseur
  int? clientId;            // renseigné si entrant
  String tiers;             // fournisseur si sortant, nom du client si entrant
  String description;
  double montant;           // attendu
  DateTime echeance;
  String categorie;         // analytique, surtout pour les sortants
  final List<Reglement> reglements;
  bool annule;

  Engagement({
    required this.id, required this.sens, required this.tiers,
    required this.montant, required this.echeance,
    this.projetId, this.documentNumero, this.clientId,
    this.description = '', this.categorie = 'Autres',
    List<Reglement>? reglements, this.annule = false,
  }) : reglements = reglements ?? [];

  bool get estEntrant => sens == 'entrant';

  /// Somme réellement mouvementée.
  double get regle => reglements.fold(0.0, (s, r) => s + r.montant);

  /// Solde restant dû. Jamais négatif, même en cas de sur-règlement.
  double get reste {
    final r = montant - regle;
    return r < 0 ? 0 : r;
  }

  bool get solde => reste == 0;

  /// En retard à la date `now`. Le jour de l'échéance n'est pas un retard.
  /// `now` est un paramètre, jamais `DateTime.now()` : c'est ce qui rend la
  /// règle testable, comme `AppState.verifierCloture`.
  bool enRetard(DateTime now) {
    if (solde || annule) return false;
    final jour = DateTime(now.year, now.month, now.day);
    final ech = DateTime(echeance.year, echeance.month, echeance.day);
    return jour.isAfter(ech);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'sens': sens, 'projetId': projetId,
    'documentNumero': documentNumero, 'clientId': clientId,
    'tiers': tiers, 'description': description, 'montant': montant,
    'echeance': echeance.toIso8601String(), 'categorie': categorie,
    'reglements': reglements.map((r) => r.toJson()).toList(),
    'annule': annule,
  };

  factory Engagement.fromJson(Map<String, dynamic> j) => Engagement(
    id: j['id'], sens: j['sens'], projetId: j['projetId'],
    documentNumero: j['documentNumero'], clientId: j['clientId'],
    tiers: j['tiers'], description: j['description'] ?? '',
    montant: toDouble(j['montant']),
    echeance: DateTime.parse(j['echeance']),
    categorie: j['categorie'] ?? 'Autres',
    reglements: (j['reglements'] as List? ?? [])
        .map((r) => Reglement.fromJson(r)).toList(),
    annule: j['annule'] ?? false,
  );
}
```

`Expense` disparaît de ce fichier. Le code qui l'utilise ne compile plus — c'est attendu, les tâches 5 à 8 le reprennent.

- [ ] **Step 4: Lancer le test du modèle et vérifier qu'il passe**

Run: `flutter test test/engagement_reglement_test.dart`
Expected: PASS, 9 tests.

Le reste de la suite ne compile pas encore (`Expense` a disparu) : c'est normal jusqu'à la tâche 8.

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/engagement.dart test/engagement_reglement_test.dart
git commit -m "feat: Engagement porte une liste de Reglement, Expense retiree du modele"
```

---

## Task 3: La migration v1 → v2, en JSON pur

**Files:**
- Create: `lib/core/migration.dart`
- Test: `test/migration_v1_v2_test.dart` (créer)

La migration travaille sur les `Map<String, dynamic>` bruts, **jamais sur les modèles** : les modèles v1 n'existent plus, et une migration qui dépend du code courant se casse à chaque évolution ultérieure.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/migration_v1_v2_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/migration.dart';

/// Sauvegarde v1 minimale couvrant les quatre mécanismes d'origine.
Map<String, dynamic> _v1() => {
  'clients': [],
  'documents': {
    'proforma': [],
    'facture': [
      {
        'id': 1, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
        'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
        'montant': 800.0, 'statut': 'validee',
        'lines': [
          {'ref': 'PC1', 'designation': 'Ordinateur', 'qte': 2, 'pu': 300.0},
          {'ref': 'SW1', 'designation': 'Switch', 'qte': 1, 'pu': 200.0},
        ],
        'encaissee': true, 'dateEncaissement': '15/02/2026', 'dateAffichee': '',
      },
      {
        'id': 2, 'numero': 'KLR-F02-11012026', 'date': '11/01/2026',
        'clientId': 6, 'client': 'BETA', 'clientAddr': '', 'objet': 'Serveur',
        'montant': 5000.0, 'statut': 'cours',
        'lines': [
          {'ref': 'SRV', 'designation': 'Serveur', 'qte': 1, 'pu': 5000.0},
        ],
        'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
      },
    ],
    'bl': [],
  },
  'engagements': [
    {
      'id': 10, 'sens': 'creance', 'num': 'CTR-2026-01', 'tiers': 'GAMMA',
      'description': 'Maintenance', 'montant': 1200.0, 'statut': 'cours',
      'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
      'acompte': 400.0, 'dateAcompte': '03/03/2026',
    },
    {
      'id': 11, 'sens': 'dette', 'num': 'FRN-77', 'tiers': 'Fournisseur X',
      'description': 'Câbles', 'montant': 900.0, 'statut': 'paye',
      'echeance': '10/04/2026', 'dateReglement': '12/04/2026',
      'categorie': 'Achat matériel', 'acompte': 300.0, 'dateAcompte': '01/04/2026',
    },
  ],
  'expenses': [
    {
      'id': 20, 'date': DateTime(2026, 1, 12).toIso8601String(),
      'label': 'Licences', 'amount': 250.0, 'category': 'Achat matériel',
      'factureNumero': 'KLR-F01-10012026',
    },
  ],
  'activities': [], 'tasks': [], 'notes': [],
  'settings': {}, 'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _engs(Map<String, dynamic> v2) =>
    (v2['engagements'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic>? _parTiers(Map<String, dynamic> v2, String tiers) {
  final m = _engs(v2).where((e) => e['tiers'] == tiers);
  return m.isEmpty ? null : m.first;
}

double _regle(Map<String, dynamic> e) => (e['reglements'] as List)
    .fold(0.0, (s, r) => s + (r['montant'] as num).toDouble());

void main() {
  test('une sauvegarde déjà en v2 traverse la migration inchangée', () {
    final v2 = {'version': 2, 'engagements': [], 'documents': {}};
    expect(migrerV1versV2(v2), same(v2));
  });

  test('la sortie porte version 2 et n\'a plus de clé expenses', () {
    final v2 = migrerV1versV2(_v1());
    expect(v2['version'], 2);
    expect(v2.containsKey('expenses'), isFalse);
  });

  test('creance/dette deviennent entrant/sortant', () {
    final v2 = migrerV1versV2(_v1());
    expect(_parTiers(v2, 'GAMMA')!['sens'], 'entrant');
    expect(_parTiers(v2, 'Fournisseur X')!['sens'], 'sortant');
  });

  test('un acompte v1 devient un règlement à sa date', () {
    final gamma = _parTiers(migrerV1versV2(_v1()), 'GAMMA')!;
    final regs = (gamma['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 1);
    expect(regs.first['montant'], 400.0);
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 3, 3));
    expect(gamma['montant'], 1200.0);
  });

  test('un engagement payé avec acompte donne deux règlements, acompte puis solde', () {
    final frn = _parTiers(migrerV1versV2(_v1()), 'Fournisseur X')!;
    final regs = (frn['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 2);
    expect(regs[0]['montant'], 300.0);
    expect(DateTime.parse(regs[0]['date']), DateTime(2026, 4, 1));
    expect(regs[1]['montant'], 600.0, reason: 'le solde, pas le montant entier');
    expect(DateTime.parse(regs[1]['date']), DateTime(2026, 4, 12));
    expect(_regle(frn), 900.0);
  });

  test('une dépense devient un engagement sortant réglé le jour même', () {
    final v2 = migrerV1versV2(_v1());
    final dep = _engs(v2).firstWhere((e) => e['description'] == 'Licences');
    expect(dep['sens'], 'sortant');
    expect(dep['montant'], 250.0);
    expect(dep['categorie'], 'Achat matériel');
    expect(dep['documentNumero'], 'KLR-F01-10012026');
    final regs = (dep['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 1);
    expect(regs.first['montant'], 250.0);
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 1, 12));
  });

  test('une facture encaissée devient un engagement entrant soldé, montant = somme des lignes', () {
    final v2 = migrerV1versV2(_v1());
    final f = _engs(v2).firstWhere((e) => e['documentNumero'] == 'KLR-F01-10012026' && e['sens'] == 'entrant');
    expect(f['montant'], 800.0, reason: '2×300 + 1×200');
    expect(f['clientId'], 5);
    expect(_regle(f), 800.0);
    final regs = (f['reglements'] as List).cast<Map<String, dynamic>>();
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 2, 15));
  });

  test('une facture non encaissée devient un engagement entrant sans règlement', () {
    final v2 = migrerV1versV2(_v1());
    final f = _engs(v2).firstWhere((e) => e['documentNumero'] == 'KLR-F02-11012026');
    expect(f['montant'], 5000.0);
    expect((f['reglements'] as List), isEmpty);
  });

  test('les factures ne portent plus encaissee ni dateEncaissement', () {
    final v2 = migrerV1versV2(_v1());
    final factures = ((v2['documents'] as Map)['facture'] as List).cast<Map<String, dynamic>>();
    for (final f in factures) {
      expect(f.containsKey('encaissee'), isFalse);
      expect(f.containsKey('dateEncaissement'), isFalse);
    }
  });

  test('les identifiants produits sont tous distincts', () {
    final v2 = migrerV1versV2(_v1());
    final ids = _engs(v2).map((e) => e['id']).toList();
    expect(ids.toSet().length, ids.length);
    final regIds = _engs(v2)
        .expand((e) => (e['reglements'] as List).map((r) => r['id'])).toList();
    expect(regIds.toSet().length, regIds.length);
  });

  test('les lignes reçoivent qteLivree = 0', () {
    final v2 = migrerV1versV2(_v1());
    final f = ((v2['documents'] as Map)['facture'] as List).first as Map<String, dynamic>;
    for (final l in (f['lines'] as List).cast<Map<String, dynamic>>()) {
      expect(l['qteLivree'], 0);
    }
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/migration_v1_v2_test.dart`
Expected: FAIL — `lib/core/migration.dart` n'existe pas.

- [ ] **Step 3: Écrire `lib/core/migration.dart`**

```dart
/// Migration des sauvegardes : v1 (quatre mécanismes d'argent) → v2
/// (Engagement + Reglement).
///
/// Travaille sur le JSON brut, jamais sur les modèles : les classes v1
/// n'existent plus, et une migration liée au code courant se casserait à
/// chaque évolution ultérieure du modèle.
library;

/// Convertit une sauvegarde v1 en v2. Une sauvegarde déjà en v2 est rendue
/// telle quelle, sans copie.
Map<String, dynamic> migrerV1versV2(Map<String, dynamic> j) {
  if (j['version'] == 2) return j;

  final generateur = _Ids();
  final engagements = <Map<String, dynamic>>[];

  // ── 1. Les engagements v1 (créances et dettes) ──────────
  final v1Engagements = (j['engagements'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  for (final e in v1Engagements) {
    engagements.add(_depuisEngagementV1(e, generateur));
  }

  // ── 2. Les dépenses : sortants réglés le jour même ──────
  for (final d in (j['expenses'] as List? ?? []).cast<Map<String, dynamic>>()) {
    engagements.add(_depuisDepenseV1(d, generateur));
  }

  // ── 3. Les factures, sauf celles déjà couvertes (§ 8.1) ─
  final documents = (j['documents'] as Map? ?? {}).cast<String, dynamic>();
  final factures = (documents['facture'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final creancesAppariees = <int>{};

  for (final f in factures) {
    final apparie = _apparier(f, v1Engagements, engagements, creancesAppariees);
    if (apparie != null) {
      // Fusion : la créance saisie à la main EST cette facture.
      apparie['documentNumero'] = f['numero'];
      apparie['clientId'] = f['clientId'];
      continue;
    }
    engagements.add(_depuisFactureV1(f, generateur));
  }

  // ── 4. Nettoyage des documents ──────────────────────────
  // Chaque document est RECOPIÉ dans une map neuve avant d'être modifié, au
  // lieu d'être muté sur place. Sans cela, un littéral de map ne contenant
  // aucun `null` est inféré `Map<String, Object>` par Dart, et y écrire
  // `projetId = null` lève à l'exécution. Les données réelles viennent de
  // `jsonDecode`, toujours `Map<String, dynamic>` — mais les fixtures de test
  // en souffrent, et la copie rend au passage la fonction non mutante.
  for (final type in ['proforma', 'facture', 'bl']) {
    final liste = (documents[type] as List? ?? []).cast<Map<String, dynamic>>();
    documents[type] = liste.map((d) {
      final dd = Map<String, dynamic>.from(d);
      dd.remove('encaissee');
      dd.remove('dateEncaissement');
      dd['projetId'] = null;
      dd['lines'] = (d['lines'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((l) => Map<String, dynamic>.from(l)..['qteLivree'] = 0)
          .toList();
      return dd;
    }).toList();
  }

  final v2 = Map<String, dynamic>.from(j);
  v2['version'] = 2;
  v2['engagements'] = engagements;
  v2['documents'] = documents;
  v2['projets'] = <Map<String, dynamic>>[];
  v2.remove('expenses');
  return v2;
}

// ── Conversions unitaires ─────────────────────────────────

Map<String, dynamic> _depuisEngagementV1(Map<String, dynamic> e, _Ids ids) {
  final reglements = <Map<String, dynamic>>[];
  final montant = _double(e['montant']);
  final acompte = e['acompte'] == null ? 0.0 : _double(e['acompte']);
  // Une date illisible vaut une date absente : v1 excluait déjà des comptes un
  // acompte sans date. Surtout, la migration s'exécute au chargement de
  // l'application — un enregistrement malformé doit être ignoré, jamais faire
  // échouer l'ouverture de toute la sauvegarde.
  final dAcompte = _jour(e['dateAcompte']);
  final aAcompte = acompte > 0 && dAcompte != null;

  if (aAcompte) {
    reglements.add(_reglement(ids.suivant(), dAcompte, acompte));
  }
  final dReglement = _jour(e['dateReglement']);
  if (e['statut'] == 'paye' && dReglement != null) {
    // Le solde seulement : l'acompte a déjà été porté à sa propre date.
    final solde = aAcompte ? montant - acompte : montant;
    if (solde > 0) {
      reglements.add(_reglement(ids.suivant(), dReglement, solde));
    }
  }

  return {
    'id': ids.suivant(),
    'sens': e['sens'] == 'creance' ? 'entrant' : 'sortant',
    'projetId': null,
    'documentNumero': null,
    'clientId': null,
    'tiers': e['tiers'] ?? '',
    // `num` v1 était une référence libre ; elle rejoint la description pour
    // ne pas être perdue.
    'description': _joindre(e['description'], e['num']),
    'montant': montant,
    'echeance': (_jour(e['echeance']) ?? DateTime(2026)).toIso8601String(),
    'categorie': e['categorie'] ?? 'Autres',
    'reglements': reglements,
    'annule': false,
  };
}

Map<String, dynamic> _depuisDepenseV1(Map<String, dynamic> d, _Ids ids) {
  // Date illisible : on garde la dépense, sans règlement. Perdre la date ne
  // doit pas faire disparaître le montant — le manager verra un engagement
  // non soldé et pourra le corriger.
  final date = _iso(d['date']);
  final montant = _double(d['amount']);
  return {
    'id': ids.suivant(),
    'sens': 'sortant',
    'projetId': null,
    'documentNumero': d['factureNumero'],
    'clientId': null,
    'tiers': '',
    'description': d['label'] ?? '',
    'montant': montant,
    'echeance': (date ?? DateTime(2026)).toIso8601String(),
    'categorie': d['category'] ?? 'Autres',
    'reglements': date == null
        ? <Map<String, dynamic>>[]
        : [_reglement(ids.suivant(), date, montant)],
    'annule': false,
  };
}

Map<String, dynamic> _depuisFactureV1(Map<String, dynamic> f, _Ids ids) {
  // Le montant retenu est la SOMME DES LIGNES, et non `f['montant']` : c'est
  // ce que `Comptabilite.factureHt` utilisait en v1. Prendre l'autre ferait
  // diverger le bilan après migration.
  final montant = (f['lines'] as List? ?? []).fold<double>(
      0.0, (s, l) => s + (l['qte'] as num) * _double(l['pu']));
  final encaissee = f['encaissee'] == true;
  final dateEnc = _jour(f['dateEncaissement']);

  return {
    'id': ids.suivant(),
    'sens': 'entrant',
    'projetId': null,
    'documentNumero': f['numero'],
    'clientId': f['clientId'],
    'tiers': f['client'] ?? '',
    'description': f['objet'] ?? '',
    'montant': montant,
    'echeance': (_jour(f['date']) ?? DateTime(2026)).toIso8601String(),
    'categorie': 'Autres',
    'reglements': encaissee && dateEnc != null
        ? [_reglement(ids.suivant(), dateEnc, montant)]
        : <Map<String, dynamic>>[],
    'annule': false,
  };
}

/// Règle de fusion du § 8.1 : retrouve l'engagement v2 issu d'une créance v1
/// qui désigne déjà cette facture, pour ne pas créer de doublon.
Map<String, dynamic>? _apparier(
  Map<String, dynamic> facture,
  List<Map<String, dynamic>> v1Engagements,
  List<Map<String, dynamic>> v2Engagements,
  Set<int> dejaAppariees,
) {
  final numero = _normaliser(facture['numero'] ?? '');
  if (numero.isEmpty) return null;

  // 1. La référence libre contient le numéro de facture : cas certain.
  for (var i = 0; i < v1Engagements.length; i++) {
    final e = v1Engagements[i];
    if (e['sens'] != 'creance' || dejaAppariees.contains(i)) continue;
    if (_normaliser(e['num'] ?? '').contains(numero)) {
      dejaAppariees.add(i);
      return v2Engagements[i];
    }
  }

  // 2. Même client ET même montant : cas ambigu, fusionné et journalisé.
  //    Jamais sur le seul montant — deux factures de 500 000 F à des clients
  //    différents ne doivent pas fusionner.
  final montant = (facture['lines'] as List? ?? []).fold<double>(
      0.0, (s, l) => s + (l['qte'] as num) * _double(l['pu']));
  final client = _normaliser(facture['client'] ?? '');
  if (client.isEmpty) return null;

  for (var i = 0; i < v1Engagements.length; i++) {
    final e = v1Engagements[i];
    if (e['sens'] != 'creance' || dejaAppariees.contains(i)) continue;
    if (_normaliser(e['tiers'] ?? '') == client && _double(e['montant']) == montant) {
      dejaAppariees.add(i);
      final fusionne = v2Engagements[i];
      fusionne['fusionAmbigue'] = true; // lu par AppState pour journaliser
      return fusionne;
    }
  }
  return null;
}

// ── Outils ────────────────────────────────────────────────

class _Ids {
  int _n = DateTime.now().millisecondsSinceEpoch;
  int suivant() => _n++;
}

Map<String, dynamic> _reglement(int id, DateTime date, double montant) => {
  'id': id, 'date': date.toIso8601String(),
  'montant': montant, 'moyen': 'especes',
};

double _double(dynamic v) => (v as num).toDouble();

/// ISO 8601 → DateTime, ou null si la chaîne est inexploitable.
DateTime? _iso(dynamic s) => s is String ? DateTime.tryParse(s) : null;

/// 'dd/MM/yyyy' → DateTime, ou null si inexploitable.
DateTime? _jour(dynamic s) {
  if (s is! String) return null;
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

String _normaliser(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[\s\-_/]'), '');

String _joindre(dynamic description, dynamic num) {
  final d = (description ?? '').toString().trim();
  final n = (num ?? '').toString().trim();
  if (d.isEmpty) return n;
  if (n.isEmpty) return d;
  return '$d ($n)';
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/migration_v1_v2_test.dart`
Expected: PASS, 11 tests — puis 15 une fois ajoutés les tests de tolérance aux
dates illisibles (voir ci-dessous).

**Tolérance aux dates illisibles.** Une date non nulle mais inexploitable
(`'12-04-2026'`, `''`, `'n/a'`) ne doit jamais interrompre la migration : elle
s'exécute pendant `loadFromJson`, donc au démarrage de l'application. Un seul
enregistrement malformé empêcherait le manager d'ouvrir ses données. Une telle
date vaut une date absente — la règle que v1 appliquait déjà pour un acompte
sans date. Quatre tests couvrent ces cas : acompte illisible, règlement
illisible, dépense à date illisible (le montant est conservé, sans règlement),
et sauvegarde partiellement corrompue dont les enregistrements sains sont bien
migrés.

- [ ] **Step 5: Commit**

```bash
git add lib/core/migration.dart test/migration_v1_v2_test.dart
git commit -m "feat: migration JSON v1 vers v2, engagements et reglements"
```

---

## Task 4: Les cas de fusion du § 8.1, testés un par un

**Files:**
- Test: `test/migration_fusion_test.dart` (créer)
- Modify: `lib/core/migration.dart` si un cas échoue

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/migration_fusion_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/migration.dart';

Map<String, dynamic> _facture({
  required int id, required String numero, required int clientId,
  required String client, required double pu,
}) => {
  'id': id, 'numero': numero, 'date': '10/01/2026', 'clientId': clientId,
  'client': client, 'clientAddr': '', 'objet': 'Fourniture',
  'montant': pu, 'statut': 'validee',
  'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': pu}],
  'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
};

Map<String, dynamic> _creance({
  required int id, required String num, required String tiers,
  required double montant,
}) => {
  'id': id, 'sens': 'creance', 'num': num, 'tiers': tiers,
  'description': '', 'montant': montant, 'statut': 'cours',
  'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
  'acompte': 0.0, 'dateAcompte': null,
};

Map<String, dynamic> _save({
  List<Map<String, dynamic>> factures = const [],
  List<Map<String, dynamic>> engagements = const [],
}) => {
  'clients': [],
  'documents': {'proforma': [], 'facture': factures, 'bl': []},
  'engagements': engagements,
  'expenses': [],
  'activities': [], 'tasks': [], 'notes': [], 'settings': {},
  'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _engs(Map<String, dynamic> v2) =>
    (v2['engagements'] as List).cast<Map<String, dynamic>>();

void main() {
  test('branche 1 : le numéro de facture figure dans la référence libre', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1, reason: 'fusion : un seul engagement');
    expect(_engs(v2).first['documentNumero'], 'KLR-F01-10012026');
    expect(_engs(v2).first['clientId'], 5);
  });

  test('branche 1 : la normalisation ignore tirets, espaces et casse', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'klr f01 10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1);
  });

  test('branche 2 : même client et même montant fusionnent, et sont marqués ambigus', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Bon de commande 42', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1);
    expect(_engs(v2).first['fusionAmbigue'], isTrue);
    expect(_engs(v2).first['documentNumero'], 'KLR-F01-10012026');
  });

  test('même montant mais clients différents : AUCUNE fusion', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 500000)],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'BETA', montant: 500000)],
    ));
    expect(_engs(v2).length, 2, reason: 'deux tiers distincts, deux engagements');
  });

  test('même client mais montants différents : AUCUNE fusion', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'ACME', montant: 900)],
    ));
    expect(_engs(v2).length, 2);
  });

  test('une créance n\'est appariée qu\'une fois, même si deux factures correspondent', () {
    final v2 = migrerV1versV2(_save(
      factures: [
        _facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800),
        _facture(id: 2, numero: 'KLR-F02-11012026', clientId: 5, client: 'ACME', pu: 800),
      ],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 2, reason: '1 créance fusionnée + 1 facture restante');
    final numeros = _engs(v2).map((e) => e['documentNumero']).toSet();
    expect(numeros, {'KLR-F01-10012026', 'KLR-F02-11012026'});
  });

  test('une dette n\'est jamais appariée à une facture', () {
    final dette = _creance(id: 10, num: 'KLR-F01-10012026', tiers: 'ACME', montant: 800);
    dette['sens'] = 'dette';
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [dette],
    ));
    expect(_engs(v2).length, 2);
  });
}
```

- [ ] **Step 2: Lancer le test**

Run: `flutter test test/migration_fusion_test.dart`
Expected: PASS si la tâche 3 est correcte. En cas d'échec, corriger `_apparier` dans `lib/core/migration.dart` — le test fait foi, pas l'implémentation.

- [ ] **Step 3: Commit**

```bash
git add test/migration_fusion_test.dart lib/core/migration.dart
git commit -m "test: les sept cas de fusion du doublon herite"
```

---

## Task 5: Réécrire Comptabilite sur les règlements

**Files:**
- Modify: `lib/core/comptabilite.dart`
- Test: `test/comptabilite_test.dart`, `test/rapport_periode_test.dart` (adapter la construction des données, **pas les assertions**)

- [ ] **Step 1: Écrire le test de non-régression qui échoue**

Créer `test/compta_reglements_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _entrant(double montant, List<Reglement> regs, {String tiers = 'ACME'}) =>
    Engagement(id: DateTime.now().microsecondsSinceEpoch, sens: 'entrant',
        tiers: tiers, montant: montant, echeance: DateTime(2026, 12, 31),
        reglements: regs);

Engagement _sortant(double montant, List<Reglement> regs, {String categorie = 'Transport'}) =>
    Engagement(id: DateTime.now().microsecondsSinceEpoch + 1, sens: 'sortant',
        tiers: 'Fournisseur', montant: montant, echeance: DateTime(2026, 12, 31),
        categorie: categorie, reglements: regs);

Reglement _r(double m, DateTime d) =>
    Reglement(id: d.microsecondsSinceEpoch, date: d, montant: m);

void main() {
  test('le revenu est la somme des règlements entrants, pas des montants attendus', () {
    final t = Comptabilite.totaux([
      _entrant(1000, [_r(400, DateTime(2026, 3, 3))]),
      _entrant(2000, []),
    ]);
    expect(t.revenuHt, 400);
    expect(t.depenses, 0);
    expect(t.benefice, 400);
  });

  test('les dépenses sont la somme des règlements sortants', () {
    final t = Comptabilite.totaux([
      _entrant(1000, [_r(1000, DateTime(2026, 3, 3))]),
      _sortant(600, [_r(600, DateTime(2026, 3, 5))]),
    ]);
    expect(t.revenuHt, 1000);
    expect(t.depenses, 600);
    expect(t.benefice, 400);
  });

  test('chaque règlement compte au mois de SA date', () {
    final rows = Comptabilite.bilanMensuel([
      _entrant(1000, [
        _r(400, DateTime(2026, 3, 3)),
        _r(600, DateTime(2026, 5, 9)),
      ]),
    ], const {}, const {});
    expect(Comptabilite.ligneMois('2026-03', rows)!.revenuHt, 400);
    expect(Comptabilite.ligneMois('2026-05', rows)!.revenuHt, 600);
    expect(Comptabilite.ligneMois('2026-04', rows), isNull);
  });

  test('la dîme vaut 10 % du bénéfice mensuel, et rien si le mois est déficitaire', () {
    final rows = Comptabilite.bilanMensuel([
      _entrant(1000, [_r(1000, DateTime(2026, 3, 3))]),
      _sortant(400, [_r(400, DateTime(2026, 3, 4))]),
      _sortant(500, [_r(500, DateTime(2026, 4, 4))]),
    ], const {}, const {});
    expect(Comptabilite.ligneMois('2026-03', rows)!.dime, closeTo(60, 0.001));
    expect(Comptabilite.ligneMois('2026-04', rows)!.dime, 0);
  });

  test('le rapport de période ne retient que les règlements dans les bornes', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 3, 1), fin: DateTime(2026, 3, 31),
      engagements: [
        _entrant(1000, [
          _r(400, DateTime(2026, 3, 3)),
          _r(600, DateTime(2026, 5, 9)),
        ]),
        _sortant(200, [_r(200, DateTime(2026, 3, 15))]),
      ],
    );
    expect(r.revenu, 400);
    expect(r.depenses, 200);
    expect(r.mouvements.length, 2);
    expect(r.depensesParCategorie['Transport'], 200);
  });

  test('les bornes du rapport sont incluses', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 3, 1), fin: DateTime(2026, 3, 31),
      engagements: [
        _entrant(300, [_r(100, DateTime(2026, 3, 1))]),
        _entrant(300, [_r(200, DateTime(2026, 3, 31))]),
      ],
    );
    expect(r.revenu, 300);
  });

  test('creancesEnCours est le reste dû des entrants non soldés', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [
        _entrant(1000, [_r(400, DateTime(2026, 3, 3))]),
        _entrant(500, [_r(500, DateTime(2026, 3, 3))]),
      ],
    );
    expect(r.creancesEnCours, 600);
  });

  test('un engagement annulé ne compte ni en attendu ni en flux', () {
    final annule = _entrant(1000, [])..annule = true;
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [annule],
    );
    expect(r.revenu, 0);
    expect(r.creancesEnCours, 0);
  });

  test('les mouvements sortent triés du plus ancien au plus récent', () {
    final r = Comptabilite.rapport(
      debut: DateTime(2026, 1, 1), fin: DateTime(2026, 12, 31),
      engagements: [
        _entrant(900, [
          _r(300, DateTime(2026, 6, 1)),
          _r(300, DateTime(2026, 2, 1)),
          _r(300, DateTime(2026, 4, 1)),
        ]),
      ],
    );
    expect(r.mouvements.map((m) => m.date.month).toList(), [2, 4, 6]);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/compta_reglements_test.dart`
Expected: FAIL — `Comptabilite.totaux` attend encore trois listes.

- [ ] **Step 3: Réécrire les méthodes de `lib/core/comptabilite.dart`**

Conserver inchangés : `ComptaTotaux`, `MonthlyRow`, `MouvementRapport`, `RapportPeriode`, `monthKeyFromDdMmYyyy`, `monthKeyFromDate`, `monthLabel`, `parseJour`, `dansPeriode`, `ligneMois`, `moisAClore`.

Remplacer `factureHt`, `depensesFacture`, `beneficeFacture`, `totaux`, `bilanMensuel` et `rapport` par :

```dart
  static double factureHt(DocumentItem f) =>
      f.lines.fold(0.0, (s, l) => s + l.total);

  /// Décaissements rattachés à une facture — sert au bénéfice par facture.
  static double depensesFacture(String numero, List<Engagement> engagements) =>
      engagements
          .where((e) => !e.estEntrant && !e.annule && e.documentNumero == numero)
          .fold(0.0, (s, e) => s + e.regle);

  static double beneficeFacture(DocumentItem f, List<Engagement> engagements) =>
      factureHt(f) - depensesFacture(f.numero, engagements);

  /// Tous les règlements d'une liste d'engagements non annulés, avec leur sens.
  static Iterable<({Engagement engagement, Reglement reglement})> _flux(
      List<Engagement> engagements) sync* {
    for (final e in engagements) {
      if (e.annule) continue;
      for (final r in e.reglements) {
        yield (engagement: e, reglement: r);
      }
    }
  }

  static ComptaTotaux totaux(List<Engagement> engagements) {
    var revenu = 0.0, dep = 0.0;
    for (final f in _flux(engagements)) {
      if (f.engagement.estEntrant) {
        revenu += f.reglement.montant;
      } else {
        dep += f.reglement.montant;
      }
    }
    final dime = bilanMensuel(engagements, const {}, const {})
        .fold(0.0, (s, r) => s + r.dime);
    return ComptaTotaux(
      revenuHt: revenu, depenses: dep, benefice: revenu - dep, dime: dime,
    );
  }

  static List<MonthlyRow> bilanMensuel(
    List<Engagement> engagements,
    Set<String> dimePaidMonths,
    Map<String, String> dimePaidDates,
  ) {
    final rev = <String, double>{};
    final dep = <String, double>{};

    // Base caisse : chaque règlement est porté au mois de sa propre date.
    for (final f in _flux(engagements)) {
      if (f.reglement.montant <= 0) continue;
      final k = monthKeyFromDate(f.reglement.date);
      if (f.engagement.estEntrant) {
        rev[k] = (rev[k] ?? 0) + f.reglement.montant;
      } else {
        dep[k] = (dep[k] ?? 0) + f.reglement.montant;
      }
    }

    final keys = <String>{...rev.keys, ...dep.keys}.toList()..sort();
    return keys.map((k) {
      final r = rev[k] ?? 0, d = dep[k] ?? 0;
      final b = r - d;
      return MonthlyRow(
        monthKey: k, label: monthLabel(k), revenuHt: r, depenses: d,
        benefice: b, dime: b > 0 ? b * 0.10 : 0.0,
        dimePaid: dimePaidMonths.contains(k), dimeDate: dimePaidDates[k],
      );
    }).toList();
  }

  static RapportPeriode rapport({
    required DateTime debut,
    required DateTime fin,
    required List<Engagement> engagements,
  }) {
    final mouvements = <MouvementRapport>[];
    final parCategorie = <String, double>{};

    for (final f in _flux(engagements)) {
      final r = f.reglement, e = f.engagement;
      if (r.montant <= 0 || !dansPeriode(r.date, debut, fin)) continue;
      final entree = e.estEntrant;
      mouvements.add(MouvementRapport(
        date: r.date,
        libelle: e.documentNumero != null
            ? '${entree ? 'Facture' : 'Achat'} ${e.documentNumero}'
            : (e.description.isEmpty ? (entree ? 'Encaissement' : 'Décaissement') : e.description),
        detail: e.tiers,
        montant: r.montant,
        entree: entree,
      ));
      if (!entree) {
        parCategorie[e.categorie] = (parCategorie[e.categorie] ?? 0) + r.montant;
      }
    }

    mouvements.sort((a, b) => a.date.compareTo(b.date));

    final revenu = mouvements.where((m) => m.entree).fold(0.0, (s, m) => s + m.montant);
    final depenses = mouvements.where((m) => !m.entree).fold(0.0, (s, m) => s + m.montant);
    final benefice = revenu - depenses;

    final tousMois = bilanMensuel(engagements, const {}, const {});
    final mois = tousMois.where((r) {
      final p = r.monthKey.split('-');
      final debutMois = DateTime(int.parse(p[0]), int.parse(p[1]));
      final finMois = DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0);
      return !finMois.isBefore(DateTime(debut.year, debut.month, debut.day)) &&
             !debutMois.isAfter(DateTime(fin.year, fin.month, fin.day));
    }).toList();

    final creancesEnCours = engagements
        .where((e) => e.estEntrant && !e.annule && !e.solde)
        .fold(0.0, (s, e) => s + e.reste);

    return RapportPeriode(
      debut: debut, fin: fin,
      revenu: revenu, depenses: depenses, benefice: benefice,
      dime: benefice > 0 ? benefice * 0.10 : 0,
      mois: mois, mouvements: mouvements,
      depensesParCategorie: parCategorie,
      creancesEnCours: creancesEnCours,
    );
  }
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/compta_reglements_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Adapter les tests existants — construction seulement**

Dans `test/comptabilite_test.dart`, `test/acompte_test.dart` et
`test/rapport_periode_test.dart` : remplacer la construction des données
(`Expense(...)`, `Engagement(acompte: ...)`, `facture.encaissee = true`) par des
engagements porteurs de règlements.

**Règle absolue : ne toucher à aucune assertion.** Si un `expect` doit changer de valeur attendue, c'est une régression de la réécriture, pas un test obsolète — arrêter et corriger `comptabilite.dart`.

**`test/cloture_mensuelle_test.dart` n'est PAS adaptable ici** — il appartient à
la tâche 6. Chacun de ses tests construit un `AppState` et appelle `addExpense`,
`validerEngagement` ou `annulerValidationEngagement`, méthodes que la tâche 6
n'a pas encore remplacées. Aucune modification « construction seulement » ne
répare du code appelant des méthodes inexistantes, et `AppState` lui-même ne
compile pas à ce stade.

Deux groupes de `test/acompte_test.dart` disparaissent, sans perte de
couverture : le groupe `modèle` testait `aAcompte` et `montantAuReglement`,
champs supprimés dont l'équivalent est couvert par
`test/engagement_reglement_test.dart` ; le groupe `AppState.setAcompte` teste
une méthode que la tâche 6 remplace par `ajouterReglement`, et dont
`test/app_state_reglements_test.dart` reprend les cas.

- [ ] **Step 6: Lancer la suite de comptabilité**

Run: `flutter test test/comptabilite_test.dart test/acompte_test.dart test/rapport_periode_test.dart test/compta_reglements_test.dart`
Expected: PASS, aucune assertion modifiée. `cloture_mensuelle_test.dart` reste
rouge jusqu'à la tâche 6.

- [ ] **Step 7: Commit**

```bash
git add lib/core/comptabilite.dart test/
git commit -m "refactor: Comptabilite ne lit plus que les reglements"
```

---

## Task 6: L'API de règlements dans AppState

**Files:**
- Modify: `lib/core/app_state.dart:21` (champ `expenses`), `:45-77` (`_seed`), `:97-110` (`_clearData`), `:124-165` (sérialisation), `:256-325` (engagements), `:335-360` (`verifierCloture`), `:523-543` (dépenses et encaissement)
- Modify: `lib/core/data.dart:78-84` (`initialExpenses`)
- Test: `test/app_state_reglements_test.dart` (créer)
- Test: `test/cloture_mensuelle_test.dart` (adapter — hérité de la tâche 5)

**Héritage de la tâche 5.** `cloture_mensuelle_test.dart` n'a pas pu être adapté
plus tôt : chacun de ses tests appelle `addExpense`, `validerEngagement` ou
`annulerValidationEngagement`, que cette tâche-ci remplace. Une fois l'API de
règlements en place, l'adapter — construction seulement, **sans toucher à une
seule assertion**, même règle qu'à la tâche 5. `addExpense(e)` devient un
engagement sortant plus un `ajouterReglement` du même montant à la même date ;
`validerEngagement(id, date)` devient `ajouterReglement(id, e.reste, date)` ;
`annulerValidationEngagement(id)` devient la suppression du dernier règlement.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/app_state_reglements_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _vide() => AppState()..viderDonnees();

Engagement _eng({double montant = 1000, String sens = 'entrant'}) => Engagement(
      id: 1, sens: sens, tiers: 'ACME', montant: montant,
      echeance: DateTime(2026, 6, 30),
    );

void main() {
  test('ajouterReglement enregistre le mouvement', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.engagements.first.regle, 400);
    expect(s.engagements.first.reste, 600);
  });

  test('un règlement dépassant le reste est écrêté', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 1500, DateTime(2026, 3, 3));
    expect(s.engagements.first.regle, 1000);
    expect(s.engagements.first.solde, isTrue);
  });

  test('deux règlements successifs, le second écrêté au reste', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 700, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 900, DateTime(2026, 4, 3));
    expect(s.engagements.first.regle, 1000);
    expect(s.engagements.first.reglements.length, 2);
    expect(s.engagements.first.reglements[1].montant, 300);
  });

  test('un montant nul ou négatif est refusé', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 0, DateTime(2026, 3, 3));
    s.ajouterReglement(1, -50, DateTime(2026, 3, 3));
    expect(s.engagements.first.reglements, isEmpty);
  });

  test('un engagement annulé n\'accepte plus de règlement', () {
    final s = _vide()..addEngagement(_eng());
    s.annulerEngagement(1);
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.engagements.first.reglements, isEmpty);
    expect(s.engagements.first.annule, isTrue);
  });

  test('un engagement déjà soldé n\'accepte plus de règlement', () {
    final s = _vide()..addEngagement(_eng(montant: 1000));
    s.ajouterReglement(1, 1000, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 100, DateTime(2026, 4, 3));
    expect(s.engagements.first.reglements.length, 1);
  });

  test('supprimerReglement retire le seul mouvement visé', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    s.ajouterReglement(1, 300, DateTime(2026, 4, 3));
    final cible = s.engagements.first.reglements.first.id;
    s.supprimerReglement(1, cible);
    expect(s.engagements.first.reglements.length, 1);
    expect(s.engagements.first.regle, 300);
  });

  test('supprimer un engagement emporte ses règlements', () {
    final s = _vide()..addEngagement(_eng());
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    s.deleteEngagement(1);
    expect(s.engagements, isEmpty);
  });

  test('chaque règlement produit une entrée dans Activités', () {
    final s = _vide()..addEngagement(_eng());
    final avant = s.activities.length;
    s.ajouterReglement(1, 400, DateTime(2026, 3, 3));
    expect(s.activities.length, avant + 1);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/app_state_reglements_test.dart`
Expected: FAIL — `ajouterReglement`, `supprimerReglement`, `annulerEngagement`, `viderDonnees` n'existent pas.

- [ ] **Step 3: Remplacer la section engagements d'`app_state.dart`**

Supprimer `validerEngagement`, `setAcompte`, `annulerValidationEngagement`, `addExpense`, `deleteExpense`, `setFactureEncaissee`, le champ `late List<Expense> expenses` et ses trois usages dans `_seed`, `_clearData` et la sérialisation. Ajouter :

```dart
  /// Vide toutes les données. Exposé pour les tests, qui ont besoin d'un état
  /// nu sans passer par le jeu de démonstration.
  void viderDonnees() {
    _clearData();
    notifyListeners();
  }

  /// Compteur monotone, amorcé une fois. Appeler `DateTime.now()` à chaque
  /// identifiant produit des collisions réelles : la granularité d'horloge de
  /// Windows fait que deux règlements enregistrés coup sur coup obtiennent la
  /// même valeur, et `supprimerReglement` en efface alors deux. Même motif que
  /// `_nextActivityId` ci-dessus et que `_Ids` dans `migration.dart`.
  int _nextReglementId = DateTime.now().microsecondsSinceEpoch;
  int _prochainId() => _nextReglementId++;

  Engagement? _engagement(int id) {
    final m = engagements.where((e) => e.id == id);
    return m.isEmpty ? null : m.first;
  }

  /// Enregistre un mouvement d'argent réel sur un engagement.
  ///
  /// C'est le SEUL geste qui fait entrer une somme en comptabilité, au mois de
  /// `date`. Un montant nul, un engagement annulé ou déjà soldé sont refusés
  /// en silence ; un montant supérieur au reste dû est écrêté.
  void ajouterReglement(int engagementId, double montant, DateTime date,
      {String moyen = 'especes'}) {
    final e = _engagement(engagementId);
    if (e == null || e.annule || montant <= 0 || e.reste <= 0) return;

    final effectif = montant > e.reste ? e.reste : montant;
    e.reglements.add(Reglement(
      id: _prochainId(), date: date, montant: effectif, moyen: moyen));

    _logActivity(
      'paiement',
      e.estEntrant
          ? 'Encaissement — ${Fmt.money(effectif)}'
          : 'Décaissement — ${Fmt.money(effectif)}',
      // La date du règlement, et non celle de la saisie : c'est elle qui décide
      // du mois d'imputation en comptabilité de caisse. L'horodatage porté par
      // l'activité est celui du jour où l'on saisit, et ne répond donc pas à la
      // question « quel mois cette somme a-t-elle touché ? ».
      e.solde
          ? '${e.tiers} — soldé le ${Fmt.jour(date)}'
          : '${e.tiers} — ${Fmt.money(effectif)} le ${Fmt.jour(date)}, '
            'reste ${Fmt.money(e.reste)}',
      e.estEntrant ? AppColors.green : AppColors.orange,
    );
    _emit();
  }

  /// Retire un règlement : la somme ressort de la comptabilité.
  void supprimerReglement(int engagementId, int reglementId) {
    final e = _engagement(engagementId);
    if (e == null) return;
    e.reglements.removeWhere((r) => r.id == reglementId);
    _emit();
  }

  /// Annule un engagement : il sort des montants attendus, et n'accepte plus
  /// de règlement. Les règlements déjà passés restent en comptabilité — ils
  /// ont réellement eu lieu.
  void annulerEngagement(int id) {
    final e = _engagement(id);
    if (e == null) return;
    e.annule = true;
    _emit();
  }

  void reactiverEngagement(int id) {
    final e = _engagement(id);
    if (e == null) return;
    e.annule = false;
    _emit();
  }
```

`deleteEngagement` reste inchangé : supprimer l'engagement emporte ses règlements, puisqu'ils vivent dans sa liste.

- [ ] **Step 4: Adapter la sérialisation et le chargement**

Dans `toJson` : retirer la ligne `'expenses'`, ajouter `'version': 2`.

Dans `loadFromJson`, en toute première instruction :

```dart
  void loadFromJson(Map<String, dynamic> brut) {
    final j = migrerV1versV2(brut);
    _restoring = true;
    // ... suite inchangée, moins la ligne expenses
```

Retirer `expenses = (j['expenses'] as List)...`.

Ajouter l'import : `import 'migration.dart';`

Dans `verifierCloture` (`app_state.dart:340`), remplacer l'appel :

```dart
    final rows = Comptabilite.bilanMensuel(
        engagements, _dimePaidMonths, _dimePaidDates);
```

- [ ] **Step 5: Adapter `lib/core/data.dart`**

Remplacer `initialExpenses` par `initialEngagementsSortants`, de même contenu, exprimé en engagements :

```dart
  static List<Engagement> get initialEngagementsSortants => [
    Engagement(id: 201, sens: 'sortant', tiers: 'Fournisseur logiciels',
        description: 'Licences de développement', montant: 250000,
        echeance: DateTime(2026, 1, 12), categorie: 'Achat matériel',
        documentNumero: 'KLR-F02-10012026',
        reglements: [Reglement(id: 2011, date: DateTime(2026, 1, 12), montant: 250000)]),
    Engagement(id: 202, sens: 'sortant', tiers: 'Intégrateur',
        description: 'Sous-traitance intégration', montant: 180000,
        echeance: DateTime(2026, 1, 20), categorie: 'Sous-traitance',
        documentNumero: 'KLR-F02-10012026',
        reglements: [Reglement(id: 2021, date: DateTime(2026, 1, 20), montant: 180000)]),
    Engagement(id: 203, sens: 'sortant', tiers: 'Grossiste réseau',
        description: 'Achat switches et bornes Wi-Fi', montant: 1650000,
        echeance: DateTime(2026, 4, 26), categorie: 'Achat matériel',
        documentNumero: 'KLR-F04-24042026',
        reglements: [Reglement(id: 2031, date: DateTime(2026, 4, 26), montant: 1650000)]),
    Engagement(id: 204, sens: 'sortant', tiers: 'Bailleur',
        description: 'Loyer atelier — avril', montant: 150000,
        echeance: DateTime(2026, 4, 10), categorie: 'Loyer & charges',
        reglements: [Reglement(id: 2041, date: DateTime(2026, 4, 10), montant: 150000)]),
    Engagement(id: 205, sens: 'sortant', tiers: 'Transporteur',
        description: 'Transport livraisons', montant: 60000,
        echeance: DateTime(2026, 1, 5), categorie: 'Transport',
        reglements: [Reglement(id: 2051, date: DateTime(2026, 1, 5), montant: 60000)]),
  ];
```

Dans `_seed`, remplacer `expenses = List.from(SampleData.initialExpenses);` par l'ajout de ces engagements à la liste `engagements`, et convertir de même les créances/dettes de démonstration existantes.

- [ ] **Step 6: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/app_state_reglements_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/core/app_state.dart lib/core/data.dart test/app_state_reglements_test.dart
git commit -m "feat: AppState expose ajouterReglement, supprimerReglement, annulerEngagement"
```

---

## Task 7: Journaliser les fusions ambiguës de la migration

**Files:**
- Modify: `lib/core/app_state.dart` (`loadFromJson`)
- Test: `test/migration_journal_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/migration_journal_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';

void main() {
  test('une fusion ambiguë laisse une trace dans Activités', () {
    final v1 = {
      'clients': [],
      'documents': {
        'proforma': [], 'bl': [],
        'facture': [
          {
            'id': 1, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
            'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
            'montant': 800.0, 'statut': 'validee',
            'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': 800.0}],
            'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
          },
        ],
      },
      'engagements': [
        {
          'id': 10, 'sens': 'creance', 'num': 'Bon de commande 42',
          'tiers': 'ACME', 'description': '', 'montant': 800.0,
          'statut': 'cours', 'echeance': '30/06/2026', 'dateReglement': null,
          'categorie': 'Autres', 'acompte': 0.0, 'dateAcompte': null,
        },
      ],
      'expenses': [],
      'activities': [], 'tasks': [], 'notes': [],
      'settings': _settings(), 'dimePaidMonths': [], 'dimePaidDates': {},
      'moisCourant': '2026-07', 'nextActivityId': 1000,
    };

    final s = AppState()..loadFromJson(v1);

    expect(s.engagements.length, 1, reason: 'les deux ont fusionné');
    expect(
      s.activities.any((a) => a.titre.contains('Rapprochement')),
      isTrue,
      reason: 'la fusion ambiguë doit être signalée au manager',
    );
    expect(s.engagements.first.toJson().containsKey('fusionAmbigue'), isFalse,
        reason: 'le marqueur de migration ne doit pas être persisté');
  });
}

Map<String, dynamic> _settings() => {
  'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
  'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01', 'tva': 0.0,
  'conditions': '',
};
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/migration_journal_test.dart`
Expected: FAIL — aucune activité « Rapprochement » n'est produite.

- [ ] **Step 3: Consommer le marqueur dans `loadFromJson`**

Dans `lib/core/app_state.dart`, juste après `final j = migrerV1versV2(brut);` :

```dart
    // La migration marque les rapprochements incertains (§ 8.1 de la spec) :
    // on les retire du JSON — ils ne doivent pas être persistés — et on les
    // journalise pour que le manager puisse les vérifier.
    final ambigus = <String>[];
    for (final e in (j['engagements'] as List).cast<Map<String, dynamic>>()) {
      if (e.remove('fusionAmbigue') == true) {
        ambigus.add('${e['tiers']} · ${e['documentNumero']}');
      }
    }
```

Puis, après `_restoring = false;` en fin de méthode :

```dart
    for (final a in ambigus) {
      _logActivity(
        'comptabilite',
        'Rapprochement à vérifier',
        '$a — une créance saisie à la main a été rattachée à cette facture '
        'sur la seule concordance du client et du montant.',
        AppColors.orange,
      );
    }
```

`_logActivity` appelle `_emit()`, donc la sauvegarde v2 est écrite dans la foulée : la migration ne se rejoue pas au démarrage suivant.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/migration_journal_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/app_state.dart test/migration_journal_test.dart
git commit -m "feat: journaliser les rapprochements ambigus de la migration"
```

---

## Task 8: Adapter l'écran Suivi aux règlements multiples

**Files:**
- Modify: `lib/screens/suivi_screen.dart` (1828 lignes — onglets Engagements, Comptabilité, Dîme)
- Modify: `lib/screens/rapports_screen.dart:32`
- Modify: `lib/screens/documents_list_screen.dart:495` (bouton d'encaissement de facture)
- Test: `test/suivi_compta_test.dart` (adapter), `test/suivi_reglements_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/suivi_reglements_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('un engagement partiellement réglé affiche son reste', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addEngagement(Engagement(
      id: 1, sens: 'entrant', tiers: 'ACME', montant: 1000,
      echeance: DateTime(2026, 6, 30), description: 'Fourniture',
    ));
    state.ajouterReglement(1, 400, DateTime(2026, 3, 3));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('600'), findsWidgets, reason: 'le reste dû');
  });

  testWidgets('l\'onglet Comptabilité s\'affiche sans Expense', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bénéfice par facture'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/suivi_reglements_test.dart`
Expected: FAIL — `suivi_screen.dart` ne compile pas (`Expense`, `setAcompte`, `validerEngagement` ont disparu).

- [ ] **Step 3: Adapter `suivi_screen.dart`**

Trois remplacements, en gardant l'ergonomie et le vocabulaire actuels :

1. **La boîte « Nouvelle Dépense »** crée désormais un engagement sortant réglé le jour même :

```dart
final id = DateTime.now().microsecondsSinceEpoch;
state.addEngagement(Engagement(
  id: id, sens: 'sortant', tiers: _tiersCtrl.text.trim(),
  description: _labelCtrl.text.trim(), montant: montant,
  echeance: date, categorie: _categorie,
));
state.ajouterReglement(id, montant, date);
```

2. **Le bouton « Valider »** d'un engagement appelle `ajouterReglement(id, e.reste, date)` au lieu de `validerEngagement(id, date)`.

3. **Le champ « Acompte »** devient une **liste de règlements** : chaque ligne affiche date, montant et moyen, avec un bouton de suppression appelant `supprimerReglement`, et un bouton « Ajouter un règlement » ouvrant une boîte montant + date + moyen.

Dans `rapports_screen.dart:32`, retirer `expenses: state.expenses,` de l'appel à `Comptabilite.rapport`.

Dans `documents_list_screen.dart:495`, remplacer l'action d'encaissement par la navigation vers l'engagement entrant de la facture (`engagements.where((e) => e.documentNumero == doc.numero)`).

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/suivi_reglements_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Lancer TOUTE la suite**

Run: `flutter analyze; flutter test`
Expected: `flutter analyze` sans erreur ; `flutter test` PASS intégralement. Aucune référence à `Expense`, `encaissee`, `acompte` ou `setAcompte` ne subsiste :

Run: `grep -rn "Expense\|\.encaissee\|setAcompte\|validerEngagement\|addExpense" lib/`
Expected: aucune sortie.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/ test/
git commit -m "feat: ecran Suivi sur les reglements multiples, Expense supprimee"
```

---

## Task 9: Vérifier la phase dans l'application réelle

**Files:** aucun — vérification manuelle assistée.

- [ ] **Step 1: Sauvegarder une v1 de référence**

```bash
cp "$APPDATA/../Local/klr_tech_app/klr_data.json" /tmp/klr_v1_reference.json
```

Si le fichier n'existe pas, lancer l'app une fois avant pour qu'elle écrive son jeu de démonstration.

- [ ] **Step 2: Lancer l'application**

Run: `flutter run -d windows --release`
Expected: la fenêtre « KLR TECH - Gestion » s'ouvre sans erreur.

- [ ] **Step 3: Comparer les chiffres**

Ouvrir Suivi → Comptabilité, et vérifier que **revenu, dépenses, bénéfice et dîme du mois affiché sont identiques** à ce qu'ils étaient avant la migration. Ouvrir Rapports, choisir la même période qu'auparavant, comparer le total.

Tout écart est une régression : arrêter, et diagnostiquer avec `test/compta_reglements_test.dart` comme point de départ.

- [ ] **Step 4: Vérifier que la migration ne se rejoue pas**

Fermer l'application, la relancer. Le fichier `klr_data.json` doit maintenant porter `"version": 2` et ne plus contenir la clé `expenses`.

Run: `grep -c '"version":2\|"version": 2' "$APPDATA/../Local/klr_tech_app/klr_data.json"`
Expected: `1`

- [ ] **Step 5: Commit du rapport de vérification**

Aucun code à commiter. Consigner l'écart constaté (ou son absence) dans le message de la PR ou du commit de clôture de phase.

---

## Auto-revue du plan

**Couverture de la spec (phase 1)** — § 3 (deux notions) → tâches 2 et 6 ; § 5.1 (modèle et invariants) → tâches 2 et 6 ; § 6.5 (comptabilité) → tâche 5 ; § 8 et 8.1 (migration et fusion) → tâches 3, 4 et 7 ; § 9 (découpage des fichiers) → tâche 1 ; § 13 (tests de phase 1) → tâches 2, 3, 4, 6.

**Écrans** — Suivi et Rapports → tâche 8. Comptabilité sans changement visible → vérifié en tâche 9.

**Cohérence des signatures** — `Comptabilite.totaux(List<Engagement>)`, `bilanMensuel(List<Engagement>, Set<String>, Map<String,String>)` et `rapport({debut, fin, engagements})` sont employées avec la même signature en tâches 5, 6 et 8. `ajouterReglement(int, double, DateTime, {String moyen})` est identique en tâches 6 et 8.
