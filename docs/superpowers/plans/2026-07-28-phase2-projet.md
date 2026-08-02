# Phase 2 — L'entité Projet : Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire du projet une entité réelle, persistée, reliée aux documents et aux engagements, dont l'avancement physique et financier se calcule sans qu'aucun chiffre ne soit stocké.

**Architecture:** `Projet` ne contient que nom, type, client, dates et jalons — jamais un montant. `DocumentItem.projetId` porte le lien vers les proformas ; `Engagement.projetId` vers les flux d'argent. `avancement.dart` calcule tout à la demande. Le Gantt passe à de vraies dates, le Kanban devient une lecture seule.

**Tech Stack:** Flutter/Dart, `provider`, persistance JSON fichier, `flutter_test`.

**Prérequis :** phase 1 terminée et verte. `Engagement` porte déjà `projetId`, la migration a déjà posé `projetId: null` sur les documents et `projets: []` dans la sauvegarde.

**Spec:** [`docs/superpowers/specs/2026-07-28-architecture-projet-flux-design.md`](../specs/2026-07-28-architecture-projet-flux-design.md) — sections 5.2, 5.3, 6.1 à 6.3, 7, 10 (phase 2), 13.

---

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `lib/core/models/projet.dart` | `Projet`, `Jalon`, `ModeAvancement` |
| `lib/core/models/document.dart` | `LineItem.qteLivree`, `DocumentItem.projetId` |
| `lib/core/avancement.dart` | Calculs d'avancement — fonctions pures, sans état |
| `lib/core/app_state.dart` | CRUD des projets, `validateProforma` étendue |
| `lib/screens/document_create_screen.dart` | Sélecteur de projet |
| `lib/screens/gantt_screen.dart` | Vraies dates, deux barres |
| `lib/screens/projets_screen.dart` | Kanban en lecture seule |

En phase 2, `ModeAvancement` est déclaré avec ses quatre valeurs mais **seul `quantites` est implémenté** — les trois autres arrivent en phase 3. Le déclarer maintenant évite de changer la signature de `Projet` plus tard.

---

## Task 1: Le modèle Projet

**Files:**
- Create: `lib/core/models/projet.dart`
- Modify: `lib/core/models.dart` (ajouter l'export)
- Test: `test/projet_model_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/projet_model_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('un projet neuf n\'a ni jalon ni annulation', () {
    final p = Projet(
      id: 1, nom: 'Fourniture matériel', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );
    expect(p.jalons, isEmpty);
    expect(p.annule, isFalse);
    expect(p.avancementManuel, 0);
  });

  test('aller-retour JSON complet', () {
    final p = Projet(
      id: 7, nom: 'Câblage siège', typeId: 'installation',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      avancementManuel: 0.35, annule: true,
      jalons: [
        Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 10),
              realisee: DateTime(2026, 3, 12), poids: 2),
        Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 20), poids: 3),
      ],
    );
    final c = Projet.fromJson(p.toJson());
    expect(c.id, 7);
    expect(c.nom, 'Câblage siège');
    expect(c.typeId, 'installation');
    expect(c.clientId, 5);
    expect(c.client, 'ACME');
    expect(c.debut, DateTime(2026, 3, 1));
    expect(c.finPrevue, DateTime(2026, 6, 30));
    expect(c.avancementManuel, 0.35);
    expect(c.annule, isTrue);
    expect(c.jalons.length, 2);
    expect(c.jalons[0].nom, 'Étude');
    expect(c.jalons[0].realisee, DateTime(2026, 3, 12));
    expect(c.jalons[0].poids, 2);
    expect(c.jalons[1].realisee, isNull);
  });

  test('un projet interne n\'a pas de client', () {
    final p = Projet(
      id: 2, nom: 'Refonte interne', typeId: 'interne',
      clientId: null, client: '',
      debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 2, 1),
    );
    final c = Projet.fromJson(p.toJson());
    expect(c.clientId, isNull);
    expect(c.client, '');
  });

  test('les quatre modes d\'avancement existent', () {
    expect(ModeAvancement.values, hasLength(4));
    expect(ModeAvancement.values.map((m) => m.name).toSet(),
        {'quantites', 'jalons', 'duree', 'manuel'});
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/projet_model_test.dart`
Expected: FAIL — `Projet`, `Jalon` et `ModeAvancement` ne sont pas définis.

- [ ] **Step 3: Créer `lib/core/models/projet.dart`**

```dart
/// Façon de mesurer l'avancement PHYSIQUE d'un projet. Le suivi financier,
/// lui, est identique pour tous les modes : règlements ÷ montant engagé.
enum ModeAvancement { quantites, jalons, duree, manuel }

/// Une étape datée d'un projet, pondérée dans l'avancement.
class Jalon {
  String nom;
  DateTime prevue;
  DateTime? realisee; // null = pas encore fait
  double poids;

  Jalon({required this.nom, required this.prevue, this.realisee, this.poids = 1});

  bool get fait => realisee != null;

  Map<String, dynamic> toJson() => {
    'nom': nom, 'prevue': prevue.toIso8601String(),
    'realisee': realisee?.toIso8601String(), 'poids': poids,
  };

  factory Jalon.fromJson(Map<String, dynamic> j) => Jalon(
    nom: j['nom'], prevue: DateTime.parse(j['prevue']),
    realisee: j['realisee'] == null ? null : DateTime.parse(j['realisee']),
    poids: (j['poids'] as num).toDouble(),
  );
}

/// Un regroupement de documents et d'engagements sous un même objectif.
///
/// NE STOCKE AUCUN MONTANT ni aucun pourcentage : montant total, encaissé,
/// avancement et statut sont calculés par `avancement.dart` à partir des
/// couches du dessous. C'est cette règle qui empêche toute redondance de
/// réapparaître.
class Projet {
  final int id;
  String nom;
  String typeId;
  int? clientId;      // null = projet interne
  String client;      // nom dénormalisé, comme DocumentItem.client
  DateTime debut;
  DateTime finPrevue;
  List<Jalon> jalons;
  double avancementManuel; // 0..1, utilisé seulement si mode == manuel
  bool annule;

  Projet({
    required this.id, required this.nom, required this.typeId,
    required this.clientId, required this.client,
    required this.debut, required this.finPrevue,
    List<Jalon>? jalons, this.avancementManuel = 0, this.annule = false,
  }) : jalons = jalons ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'nom': nom, 'typeId': typeId,
    'clientId': clientId, 'client': client,
    'debut': debut.toIso8601String(), 'finPrevue': finPrevue.toIso8601String(),
    'jalons': jalons.map((j) => j.toJson()).toList(),
    'avancementManuel': avancementManuel, 'annule': annule,
  };

  factory Projet.fromJson(Map<String, dynamic> j) => Projet(
    id: j['id'], nom: j['nom'], typeId: j['typeId'] ?? 'fourniture',
    clientId: j['clientId'], client: j['client'] ?? '',
    debut: DateTime.parse(j['debut']), finPrevue: DateTime.parse(j['finPrevue']),
    jalons: (j['jalons'] as List? ?? []).map((x) => Jalon.fromJson(x)).toList(),
    avancementManuel: (j['avancementManuel'] as num? ?? 0).toDouble(),
    annule: j['annule'] ?? false,
  );
}
```

- [ ] **Step 4: Exporter depuis `lib/core/models.dart`**

Ajouter la ligne : `export 'models/projet.dart';`

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/projet_model_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/projet.dart lib/core/models.dart test/projet_model_test.dart
git commit -m "feat: modele Projet, Jalon et ModeAvancement"
```

---

## Task 2: qteLivree et projetId sur les documents

**Files:**
- Modify: `lib/core/models/document.dart`
- Test: `test/document_projet_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/document_projet_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('une ligne neuve n\'a rien de livré', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300);
    expect(l.qteLivree, 0);
    expect(l.total, 3000);
    expect(l.totalLivre, 0);
  });

  test('totalLivre pondère par le prix unitaire', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6);
    expect(l.totalLivre, 1800);
  });

  test('aller-retour JSON d\'une ligne, qteLivree comprise', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6);
    final c = LineItem.fromJson(l.toJson());
    expect(c.qteLivree, 6);
    expect(c.qte, 10);
  });

  test('une ligne d\'une sauvegarde antérieure vaut 0 livré', () {
    final c = LineItem.fromJson({'ref': 'PC', 'designation': 'Ordinateur', 'qte': 10, 'pu': 300.0});
    expect(c.qteLivree, 0);
  });

  test('un document neuf est hors projet', () {
    final d = DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
    );
    expect(d.projetId, isNull);
  });

  test('aller-retour JSON d\'un document, projetId compris', () {
    final d = DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      projetId: 42,
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6)],
    );
    final c = DocumentItem.fromJson(d.toJson());
    expect(c.projetId, 42);
    expect(c.lines.first.qteLivree, 6);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/document_projet_test.dart`
Expected: FAIL — `qteLivree`, `totalLivre` et `projetId` n'existent pas.

- [ ] **Step 3: Modifier `lib/core/models/document.dart`**

Dans `LineItem`, ajouter le champ, le calcul et la sérialisation :

```dart
class LineItem {
  String ref;
  String designation;
  int qte;
  double pu;
  /// Quantité réellement livrée. Indicateur d'avancement INTERNE : le BL
  /// imprimé continue d'afficher `qte`. Voir § 12 de la conception.
  int qteLivree;

  LineItem({required this.ref, required this.designation, required this.qte,
      required this.pu, this.qteLivree = 0});

  double get total => qte * pu;
  double get totalLivre => qteLivree * pu;

  Map<String, dynamic> toJson() => {
    'ref': ref, 'designation': designation, 'qte': qte, 'pu': pu,
    'qteLivree': qteLivree,
  };

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    ref: j['ref'], designation: j['designation'], qte: j['qte'],
    pu: toDouble(j['pu']), qteLivree: j['qteLivree'] ?? 0,
  );

  /// Copie indépendante. Indispensable : sans elle, facture et BL
  /// partageraient les objets de la proforma en mémoire mais plus après
  /// rechargement, et `qteLivree` se comporterait différemment avant et
  /// après un redémarrage.
  LineItem copie() => LineItem(
      ref: ref, designation: designation, qte: qte, pu: pu, qteLivree: qteLivree);
}
```

Dans `DocumentItem`, ajouter `int? projetId;` au champ, au constructeur (`this.projetId`), à `toJson` (`'projetId': projetId`) et à `fromJson` (`projetId: j['projetId']`).

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/document_projet_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/document.dart test/document_projet_test.dart
git commit -m "feat: LineItem.qteLivree et DocumentItem.projetId"
```

---

## Task 3: Désamorcer le partage de lignes dans validateProforma

**Files:**
- Modify: `lib/core/app_state.dart:498-517` (`validateProforma`)
- Test: `test/lignes_independantes_test.dart` (créer)

C'est la mine décrite au § 5.2 de la conception : facture et BL reçoivent aujourd'hui `lines: p.lines`, **la même instance**, mais `fromJson` reconstruit des objets distincts au rechargement.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/lignes_independantes_test.dart` :

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _avecProformaValidee() {
  final s = AppState()..viderDonnees();
  s.saveOrUpdateProforma(DocumentItem(
    id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
    clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
    lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
  ));
  s.validateProforma(1);
  return s;
}

void main() {
  test('modifier la proforma ne touche NI la facture NI le BL, en mémoire', () {
    final s = _avecProformaValidee();
    s.documents['proforma']!.first.lines.first.qteLivree = 6;

    expect(s.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s.documents['bl']!.first.lines.first.qteLivree, 0);
  });

  test('le même comportement APRÈS un cycle de persistance', () {
    final s = _avecProformaValidee();
    final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

    final s2 = AppState()..loadFromJson(json);
    s2.documents['proforma']!.first.lines.first.qteLivree = 6;

    expect(s2.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s2.documents['bl']!.first.lines.first.qteLivree, 0);
    expect(s2.documents['proforma']!.first.lines.first.qteLivree, 6);
  });

  test('les trois documents partent bien des mêmes valeurs', () {
    final s = _avecProformaValidee();
    for (final type in ['proforma', 'facture', 'bl']) {
      final l = s.documents[type]!.first.lines.first;
      expect(l.ref, 'PC');
      expect(l.qte, 10);
      expect(l.pu, 300);
    }
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/lignes_independantes_test.dart`
Expected: FAIL sur le premier test — facture et BL suivent la proforma, `qteLivree` vaut 6 partout.

- [ ] **Step 3: Copier les lignes en profondeur**

Dans `lib/core/app_state.dart`, méthode `validateProforma`, remplacer les deux `lines: p.lines` :

```dart
      documents['facture']!.add(DocumentItem(
        id: now, numero: factureNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: p.montant, statut: 'cours',
        projetId: p.projetId,
        // Copie profonde : chaque document possède ses lignes. Le partage
        // d'instances ne survivrait pas à un rechargement depuis le disque.
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
      documents['bl']!.add(DocumentItem(
        id: now + 1, numero: blNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: 0, statut: 'cours',
        projetId: p.projetId,
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/lignes_independantes_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Vérifier qu'aucun autre test ne dépendait du partage**

Run: `flutter test`
Expected: PASS intégralement.

- [ ] **Step 6: Commit**

```bash
git add lib/core/app_state.dart test/lignes_independantes_test.dart
git commit -m "fix: facture et BL possedent leurs propres lignes, plus de partage d'instance"
```

---

## Task 4: La validation crée l'engagement entrant

**Files:**
- Modify: `lib/core/app_state.dart` (`validateProforma`)
- Test: `test/validate_proforma_test.dart` (compléter)

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter à `test/validate_proforma_test.dart` :

```dart
  test('valider une proforma crée l\'engagement entrant de sa facture', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      projetId: 42,
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);

    expect(s.engagements.length, 1);
    final e = s.engagements.first;
    expect(e.sens, 'entrant');
    expect(e.documentNumero, 'KLR-F01-10012026');
    expect(e.clientId, 5);
    expect(e.tiers, 'ACME');
    expect(e.montant, 3000, reason: 'la somme des lignes, comme factureHt');
    expect(e.projetId, 42);
    expect(e.reglements, isEmpty, reason: 'rien n\'est encore encaissé');
  });

  test('valider deux fois ne crée pas deux engagements', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);
    s.validateProforma(1);
    expect(s.engagements.length, 1);
  });

  test('l\'échéance de l\'engagement est la date de la proforma', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);
    expect(s.engagements.first.echeance, DateTime(2026, 1, 10));
  });
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/validate_proforma_test.dart`
Expected: FAIL — `s.engagements` reste vide.

- [ ] **Step 3: Créer l'engagement dans `validateProforma`**

Dans le bloc `if (!alreadyGenerated) { ... }`, après l'ajout du BL et avant `_logActivity` :

```dart
      // La facture EST une créance sur le client : l'engagement naît du même
      // geste, pour qu'aucune saisie manuelle ne puisse le dédoubler.
      engagements.insert(0, Engagement(
        id: now + 2,
        sens: 'entrant',
        projetId: p.projetId,
        documentNumero: factureNum,
        clientId: p.clientId,
        tiers: p.client,
        description: p.objet,
        montant: p.lines.fold(0.0, (s, l) => s + l.total),
        echeance: Comptabilite.parseJour(p.date) ?? DateTime.now(),
      ));
```

Ajouter l'import `import 'comptabilite.dart';` s'il n'est pas déjà présent.

L'anti-doublon existant (`alreadyGenerated`) protège déjà la double validation : l'engagement est créé dans le même bloc conditionnel.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/validate_proforma_test.dart`
Expected: PASS, tous les tests du fichier.

- [ ] **Step 5: Commit**

```bash
git add lib/core/app_state.dart test/validate_proforma_test.dart
git commit -m "feat: la validation d'une proforma cree l'engagement entrant"
```

---

## Task 5: Le calcul d'avancement, mode quantites

**Files:**
- Create: `lib/core/avancement.dart`
- Test: `test/avancement_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/avancement_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _projet({int id = 1, DateTime? debut, DateTime? fin}) => Projet(
      id: id, nom: 'Fourniture', typeId: 'fourniture', clientId: 5,
      client: 'ACME',
      debut: debut ?? DateTime(2026, 3, 1),
      finPrevue: fin ?? DateTime(2026, 6, 30),
    );

DocumentItem _proforma(int projetId, List<LineItem> lines) => DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 0, statut: 'validee',
      projetId: projetId, lines: lines,
    );

Engagement _entrant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 1, sens: 'entrant', tiers: 'ACME', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Engagement _sortant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 2, sens: 'sortant', tiers: 'Fournisseur', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Reglement _r(double m, DateTime d) => Reglement(id: 1, date: d, montant: m);

void main() {
  group('avancement physique — mode quantites', () {
    test('rien de livré donne 0', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
    });

    test('la pondération se fait par le montant, pas par le nombre d\'articles', () {
      // 20 souris à 5 (=100) toutes livrées, 1 serveur à 900 non livré.
      // Par articles : 20/21 = 95 %. Par montant : 100/1000 = 10 %.
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [
          LineItem(ref: 'SOU', designation: 'Souris', qte: 20, pu: 5, qteLivree: 20),
          LineItem(ref: 'SRV', designation: 'Serveur', qte: 1, pu: 900, qteLivree: 0),
        ])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, closeTo(0.10, 0.0001));
    });

    test('tout livré donne 1', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 1);
    });

    test('sans proforma, l\'avancement vaut 0 et jamais NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });

    test('des lignes à prix nul ne produisent pas de NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'X', designation: 'Offert', qte: 5, pu: 0, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });
  });

  group('avancement financier', () {
    test('règlements ÷ montant attendu', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(400, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, closeTo(0.4, 0.0001));
      expect(a.montantAttendu, 1000);
      expect(a.montantEncaisse, 400);
    });

    test('les engagements sortants ne comptent pas dans le financier', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 1);
      expect(a.montantAttendu, 1000);
    });

    test('sans engagement entrant, le financier vaut 0', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 0);
    });

    test('un engagement annulé est ignoré', () {
      final annule = _entrant(1, 5000, [])..annule = true;
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [annule, _entrant(1, 1000, [_r(500, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.montantAttendu, 1000);
      expect(a.financier, closeTo(0.5, 0.0001));
    });
  });

  group('marge et retard', () {
    test('la marge est entrants réglés moins sortants réglés', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, 400);
    });

    test('en retard si la fin prévue est dépassée et le physique incomplet', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isTrue);
    });

    test('pas de retard si tout est livré, même après la date', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isFalse);
    });
  });

  group('statut déduit', () {
    StatutProjet _statut({
      required double phys, required double fin, bool annule = false,
    }) {
      final projet = _projet();
      projet.annule = annule;
      return Avancement.calculer(
        projet: projet,
        mode: ModeAvancement.manuel,
        proformas: const [],
        engagements: fin == 0
            ? const []
            : [_entrant(1, 1000, [_r(1000 * fin, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
        physiqueForce: phys,
      ).statut;
    }

    test('annulé l\'emporte sur tout', () {
      expect(_statut(phys: 1, fin: 1, annule: true), StatutProjet.annule);
    });
    test('0 et 0 : à démarrer', () {
      expect(_statut(phys: 0, fin: 0), StatutProjet.aDemarrer);
    });
    test('100 et 100 : soldé', () {
      expect(_statut(phys: 1, fin: 1), StatutProjet.solde);
    });
    test('100 livré, 50 encaissé : livré, reste à encaisser', () {
      expect(_statut(phys: 1, fin: 0.5), StatutProjet.livreNonPaye);
    });
    test('50 livré : en cours', () {
      expect(_statut(phys: 0.5, fin: 0.5), StatutProjet.enCours);
    });
    test('0 livré mais déjà encaissé : en cours, pas à démarrer', () {
      expect(_statut(phys: 0, fin: 0.3), StatutProjet.enCours);
    });
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/avancement_test.dart`
Expected: FAIL — `lib/core/avancement.dart` n'existe pas.

- [ ] **Step 3: Créer `lib/core/avancement.dart`**

```dart
import 'models.dart';

/// Statut d'un projet. Déduit, jamais saisi — sauf l'annulation, seul état
/// qu'aucune donnée ne permet de deviner.
enum StatutProjet { annule, aDemarrer, solde, livreNonPaye, enCours }

extension StatutProjetLibelle on StatutProjet {
  String get libelle => switch (this) {
    StatutProjet.annule => 'Annulé',
    StatutProjet.aDemarrer => 'À démarrer',
    StatutProjet.solde => 'Soldé',
    StatutProjet.livreNonPaye => 'Livré — reste à encaisser',
    StatutProjet.enCours => 'En cours',
  };
}

/// Résultat complet du calcul d'un projet. Aucun de ces chiffres n'est stocké.
class Avancement {
  final double physique;   // 0..1
  final double financier;  // 0..1
  final double montantAttendu;
  final double montantEncaisse;
  final double montantDepense;
  final StatutProjet statut;
  final bool enRetardLivraison;
  final bool enRetardPaiement;

  const Avancement({
    required this.physique, required this.financier,
    required this.montantAttendu, required this.montantEncaisse,
    required this.montantDepense, required this.statut,
    required this.enRetardLivraison, required this.enRetardPaiement,
  });

  double get marge => montantEncaisse - montantDepense;

  /// Calcule tout l'état d'un projet à la date `now`.
  ///
  /// `now` est un paramètre obligatoire, jamais `DateTime.now()` : c'est ce
  /// qui rend les retards et le mode `duree` testables.
  ///
  /// `physiqueForce` court-circuite le calcul physique — réservé aux tests du
  /// statut, qui doivent pouvoir poser un pourcentage arbitraire.
  static Avancement calculer({
    required Projet projet,
    required ModeAvancement mode,
    required List<DocumentItem> proformas,
    required List<Engagement> engagements,
    required DateTime now,
    double? physiqueForce,
  }) {
    final actifs = engagements.where((e) => !e.annule).toList();
    final entrants = actifs.where((e) => e.estEntrant).toList();
    final sortants = actifs.where((e) => !e.estEntrant).toList();

    final attendu = entrants.fold(0.0, (s, e) => s + e.montant);
    final encaisse = entrants.fold(0.0, (s, e) => s + e.regle);
    final depense = sortants.fold(0.0, (s, e) => s + e.regle);

    final physique = physiqueForce ?? _physique(projet, mode, proformas, now);
    final financier = attendu == 0 ? 0.0 : encaisse / attendu;

    final finDepassee = now.isAfter(DateTime(
        projet.finPrevue.year, projet.finPrevue.month, projet.finPrevue.day));

    return Avancement(
      physique: physique,
      financier: financier,
      montantAttendu: attendu,
      montantEncaisse: encaisse,
      montantDepense: depense,
      statut: _statut(projet, physique, financier),
      enRetardLivraison: !projet.annule && finDepassee && physique < 1,
      enRetardPaiement: entrants.any((e) => e.enRetard(now)),
    );
  }

  /// Avancement physique selon le mode. En phase 2, seul `quantites` est
  /// implémenté ; les trois autres arrivent en phase 3 et rendent 0 d'ici là.
  static double _physique(Projet projet, ModeAvancement mode,
      List<DocumentItem> proformas, DateTime now) {
    switch (mode) {
      case ModeAvancement.quantites:
        var total = 0.0, livre = 0.0;
        for (final p in proformas) {
          for (final l in p.lines) {
            total += l.total;
            livre += l.totalLivre;
          }
        }
        return total == 0 ? 0.0 : (livre / total).clamp(0.0, 1.0);
      case ModeAvancement.jalons:
      case ModeAvancement.duree:
      case ModeAvancement.manuel:
        return 0.0; // phase 3
    }
  }

  /// Les règles sont évaluées dans l'ordre : la première qui correspond
  /// l'emporte (§ 6.3 de la conception).
  static StatutProjet _statut(Projet projet, double physique, double financier) {
    if (projet.annule) return StatutProjet.annule;
    if (physique == 0 && financier == 0) return StatutProjet.aDemarrer;
    if (physique >= 1 && financier >= 1) return StatutProjet.solde;
    if (physique >= 1) return StatutProjet.livreNonPaye;
    return StatutProjet.enCours;
  }
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/avancement_test.dart`
Expected: PASS, 18 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/avancement.dart test/avancement_test.dart
git commit -m "feat: avancement.dart, mode quantites et statut deduit"
```

---

## Task 6: Les projets dans AppState

**Files:**
- Modify: `lib/core/app_state.dart` (champ, `_seed`, `_clearData`, `toJson`, `loadFromJson`, CRUD)
- Test: `test/app_state_projets_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/app_state_projets_test.dart` :

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _p({int id = 1}) => Projet(
      id: id, nom: 'Fourniture matériel', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );

void main() {
  test('addProjet, updateProjet et deleteProjet', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    expect(s.projets.length, 1);

    s.updateProjet(_p()..nom = 'Renommé');
    expect(s.projets.first.nom, 'Renommé');

    s.deleteProjet(1);
    expect(s.projets, isEmpty);
  });

  test('les projets survivent à un aller-retour JSON', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    final s2 = AppState()..loadFromJson(json);
    expect(s2.projets.length, 1);
    expect(s2.projets.first.nom, 'Fourniture matériel');
    expect(s2.projets.first.debut, DateTime(2026, 3, 1));
  });

  test('supprimer un projet délie ses documents et ses engagements', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)],
    ));
    s.addEngagement(Engagement(
      id: 9, sens: 'sortant', tiers: 'Fournisseur', montant: 500,
      echeance: DateTime(2026, 4, 1), projetId: 1));

    s.deleteProjet(1);

    expect(s.documents['proforma']!.first.projetId, isNull);
    expect(s.engagements.first.projetId, isNull,
        reason: 'un engagement ne doit jamais pointer vers un projet disparu');
  });

  test('avancementProjet agrège documents et engagements du projet', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p());
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 4)],
    ));
    s.validateProforma(1);
    s.ajouterReglement(s.engagements.first.id, 900, DateTime(2026, 4, 1));

    final a = s.avancementProjet(1, now: DateTime(2026, 4, 15));
    expect(a.physique, closeTo(0.4, 0.0001));
    expect(a.financier, closeTo(0.3, 0.0001));
    expect(a.statut, StatutProjet.enCours);
  });

  test('avancementProjet ne mélange pas deux projets', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p(id: 1));
    s.addProjet(_p(id: 2));
    s.addEngagement(Engagement(id: 10, sens: 'entrant', tiers: 'ACME',
        montant: 1000, echeance: DateTime(2026, 6, 1), projetId: 1));
    s.addEngagement(Engagement(id: 11, sens: 'entrant', tiers: 'ACME',
        montant: 7000, echeance: DateTime(2026, 6, 1), projetId: 2));

    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).montantAttendu, 1000);
    expect(s.avancementProjet(2, now: DateTime(2026, 4, 1)).montantAttendu, 7000);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/app_state_projets_test.dart`
Expected: FAIL — `projets`, `addProjet`, `avancementProjet` n'existent pas.

- [ ] **Step 3: Ajouter les projets à `AppState`**

Déclarer le champ à côté des autres listes : `late List<Projet> projets;`

Dans `_seed` : `projets = [];`
Dans `_clearData` : `projets = [];`
Dans `toJson` : `'projets': projets.map((p) => p.toJson()).toList(),`
Dans `loadFromJson` : `projets = (j['projets'] as List? ?? []).map((e) => Projet.fromJson(e)).toList();`

Ajouter le CRUD et l'accès au calcul :

```dart
  // ── Projets ────────────────────────────────────────────
  void addProjet(Projet p) {
    projets.insert(0, p);
    _logActivity('projet', 'Projet créé — ${p.nom}',
        p.client.isEmpty ? 'Projet interne' : p.client, AppColors.primary);
    _emit();
  }

  void updateProjet(Projet p) {
    final i = projets.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    projets[i] = p;
    _emit();
  }

  /// Supprime un projet et délie tout ce qui le désignait : un document ou un
  /// engagement pointant vers un projet disparu produirait un calcul faux.
  void deleteProjet(int id) {
    projets.removeWhere((p) => p.id == id);
    for (final liste in documents.values) {
      for (final d in liste) {
        if (d.projetId == id) d.projetId = null;
      }
    }
    for (final e in engagements) {
      if (e.projetId == id) e.projetId = null;
    }
    _emit();
  }

  List<DocumentItem> proformasDuProjet(int projetId) =>
      documents['proforma']!.where((d) => d.projetId == projetId).toList();

  List<Engagement> engagementsDuProjet(int projetId) =>
      engagements.where((e) => e.projetId == projetId).toList();

  /// Mode d'avancement du projet. En phase 2, tous les projets sont en
  /// `quantites` ; la phase 3 le lira depuis `AppSettings.typesProjet`.
  ModeAvancement modeDuProjet(Projet p) => ModeAvancement.quantites;

  Avancement avancementProjet(int projetId, {DateTime? now}) {
    final p = projets.firstWhere((x) => x.id == projetId);
    return Avancement.calculer(
      projet: p,
      mode: modeDuProjet(p),
      proformas: proformasDuProjet(projetId),
      engagements: engagementsDuProjet(projetId),
      now: now ?? DateTime.now(),
    );
  }
```

Ajouter l'import `import 'avancement.dart';`

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/app_state_projets_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/app_state.dart test/app_state_projets_test.dart
git commit -m "feat: CRUD des projets et avancementProjet dans AppState"
```

---

## Task 7: Rattacher une proforma à un projet

**Files:**
- Modify: `lib/screens/document_create_screen.dart`
- Test: `test/document_create_projet_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/document_create_projet_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('le sélecteur de projet propose les projets du client', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addClient(const Client(
      id: 5, initials: 'AC', color: Colors.blue, name: 'ACME',
      contact: 'Jean', email: 'j@acme.cm', phone: '600', totalFacture: 0));
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture matériel', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    state.setDocType('proforma');

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('PROJET'), findsOneWidget);
  });

  testWidgets('sans projet enregistré, le sélecteur reste absent', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.setDocType('proforma');

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('PROJET'), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/document_create_projet_test.dart`
Expected: FAIL — aucun libellé « PROJET » dans l'écran.

- [ ] **Step 3: Ajouter le sélecteur**

Dans `document_create_screen.dart`, à côté du sélecteur de client, quand `state.projets.isNotEmpty` :

```dart
if (state.projets.isNotEmpty) ...[
  Text('PROJET', style: AppTheme.label),
  const SizedBox(height: 6),
  DropdownButtonFormField<int?>(
    initialValue: _projetId,
    decoration: deco('Aucun projet'),
    items: [
      const DropdownMenuItem<int?>(value: null, child: Text('Aucun projet')),
      // Les projets du client sélectionné d'abord, puis les autres : une
      // proforma se rattache presque toujours à un projet du même client.
      ...state.projets
          .where((p) => !p.annule)
          .where((p) => _clientId == null || p.clientId == _clientId)
          .map((p) => DropdownMenuItem<int?>(value: p.id, child: Text(p.nom))),
    ],
    onChanged: (v) => setState(() => _projetId = v),
  ),
  const SizedBox(height: 12),
],
```

Déclarer `int? _projetId;` dans le `State`, l'initialiser depuis `editingProforma?.projetId` en édition, et le passer à `DocumentItem(... projetId: _projetId ...)` à l'enregistrement.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/document_create_projet_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/document_create_screen.dart test/document_create_projet_test.dart
git commit -m "feat: rattacher une proforma a un projet a la creation"
```

---

## Task 8: Le Gantt sur de vraies dates

**Files:**
- Modify: `lib/screens/gantt_screen.dart` (remplacer les 5 projets codés en dur des lignes 15-21)
- Test: `test/gantt_reel_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/gantt_reel_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: GanttScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('sans projet, le Gantt affiche un état vide, pas des données factices', (tester) async {
    await _pump(tester, AppState()..viderDonnees());
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Aucun projet'), findsOneWidget);
    expect(find.text('Migration cloud AWS'), findsNothing,
        reason: 'les projets codes en dur doivent avoir disparu');
  });

  testWidgets('un projet enregistré apparaît avec son nom', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture matériel ACME', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await _pump(tester, state);
    expect(tester.takeException(), isNull);
    expect(find.text('Fourniture matériel ACME'), findsOneWidget);
  });

  testWidgets('les deux barres sont distinctes : livré et encaissé', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    state.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 8)]));
    state.validateProforma(1);
    state.ajouterReglement(state.engagements.first.id, 900, DateTime(2026, 4, 1));

    await _pump(tester, state);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('80'), findsWidgets, reason: '80 % livré');
    expect(find.textContaining('30'), findsWidgets, reason: '30 % encaissé');
  });

  testWidgets('un projet annulé n\'apparaît pas', (tester) async {
    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Abandonné', typeId: 'fourniture', clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30), annule: true));

    await _pump(tester, state);
    expect(find.text('Abandonné'), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/gantt_reel_test.dart`
Expected: FAIL — le Gantt affiche encore « Migration cloud AWS ».

- [ ] **Step 3: Réécrire `gantt_screen.dart`**

Supprimer `static const _months`, `static final _projects` et la classe `_GanttProject`. L'axe se calcule désormais depuis les projets réels :

```dart
class GanttScreen extends StatelessWidget {
  const GanttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final projets = state.projets.where((p) => !p.annule).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));

    if (projets.isEmpty) {
      return Padding(
        padding: pagePadding(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(title: 'Gantt',
              subtitle: 'Vue chronologique des projets.'),
          const SizedBox(height: 24),
          CardBox(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text(
              'Aucun projet enregistré.',
              style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3),
            )),
          ),
        ]),
      );
    }

    // Axe : du premier début au dernier fin prévue, arrondi au mois.
    final debut = DateTime(projets.first.debut.year, projets.first.debut.month);
    var finMax = projets.first.finPrevue;
    for (final p in projets) {
      if (p.finPrevue.isAfter(finMax)) finMax = p.finPrevue;
    }
    final fin = DateTime(finMax.year, finMax.month + 1, 0);
    final nbMois = (fin.year - debut.year) * 12 + fin.month - debut.month + 1;

    return SingleChildScrollView(
      padding: pagePadding(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
            title: 'Gantt',
            subtitle: 'Vue chronologique des projets. '
                'Barre pleine = livré, barre claire = encaissé.',
            actions: [
              if (!isPhone(context))
                SecondaryBtn(label: 'Kanban', icon: Icons.view_kanban_outlined,
                    onTap: () => context.read<AppState>().navigate(NavScreen.projets)),
            ],
          ),
          const SizedBox(height: 24),
          CardBox(
            padding: const EdgeInsets.all(20),
            child: HScrollTable(
              minWidth: 700,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const SizedBox(width: 220),
                  ...List.generate(nbMois, (i) {
                    final m = DateTime(debut.year, debut.month + i);
                    return Expanded(child: Text(
                      _moisCourt(m),
                      style: GoogleFonts.dmSans(fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.text3),
                      textAlign: TextAlign.center));
                  }),
                ]),
                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                ...projets.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _GanttRow(
                    projet: p,
                    avancement: state.avancementProjet(p.id, now: now),
                    axeDebut: debut, nbMois: nbMois),
                )),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  static const _moisAbrev = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

  static String _moisCourt(DateTime d) => '${_moisAbrev[d.month]} ${d.year % 100}';
}
```

`_GanttRow` reçoit `Projet` et `Avancement`, calcule la position de la barre en mois décimaux depuis `axeDebut`, et empile deux remplissages : le physique en couleur pleine, le financier en teinte claire dessous. Le nom du projet passe en rouge quand `avancement.enRetardLivraison`, et une pastille orange s'affiche quand `avancement.enRetardPaiement`.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/gantt_reel_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gantt_screen.dart test/gantt_reel_test.dart
git commit -m "feat: Gantt sur de vraies dates, deux barres livre et encaisse"
```

---

## Task 9: Le Kanban en lecture seule

**Files:**
- Modify: `lib/screens/projets_screen.dart` (remplacer les 400 lignes de Kanban factice)
- Modify: `lib/core/models/divers.dart` (supprimer `ProjectCard`)
- Test: `test/projets_kanban_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/projets_kanban_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
  ));
  await tester.pumpAndSettle();
}

AppState _avecProjet({int qteLivree = 0, double encaisse = 0}) {
  final s = AppState()..viderDonnees();
  s.addProjet(Projet(
    id: 1, nom: 'Fourniture ACME', typeId: 'fourniture', clientId: 5,
    client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
  s.saveOrUpdateProforma(DocumentItem(
    id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
    client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
    lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: qteLivree)]));
  s.validateProforma(1);
  if (encaisse > 0) s.ajouterReglement(s.engagements.first.id, encaisse, DateTime(2026, 4, 1));
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les cartes factices ont disparu', (tester) async {
    await _pump(tester, AppState()..viderDonnees());
    expect(find.text('Refonte interface mobile'), findsNothing);
    expect(find.text('Migration cloud AWS'), findsNothing);
  });

  testWidgets('un projet sans rien livré ni encaissé va dans « À démarrer »', (tester) async {
    await _pump(tester, _avecProjet());
    expect(tester.takeException(), isNull);
    expect(find.text('À démarrer'), findsOneWidget);
    expect(find.text('Fourniture ACME'), findsOneWidget);
  });

  testWidgets('tout livré, rien encaissé : colonne « Livré — reste à encaisser »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10));
    expect(find.textContaining('reste à encaisser'), findsWidgets);
  });

  testWidgets('tout livré et tout encaissé : colonne « Soldé »', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 10, encaisse: 3000));
    expect(find.text('Soldé'), findsWidgets);
  });

  testWidgets('les cartes ne sont plus déplaçables', (tester) async {
    await _pump(tester, _avecProjet(qteLivree: 5));
    expect(find.byType(Draggable), findsNothing,
        reason: 'la colonne est deduite : la deplacer a la main n\'aurait aucun sens');
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/projets_kanban_test.dart`
Expected: FAIL — les cartes factices sont là, et `Draggable` aussi.

- [ ] **Step 3: Réécrire `projets_screen.dart`**

Supprimer `_DragData`, `_KanbanCol`, `_KanbanColumnWidget`, `_DraggableCard` et `_showAddProjectDialog` dans sa forme actuelle. Le nouvel écran :

- une colonne par valeur de `StatutProjet` sauf `annule`, dans l'ordre `aDemarrer`, `enCours`, `livreNonPaye`, `solde`, titrée par `statut.libelle` ;
- chaque projet non annulé est rangé dans la colonne de `state.avancementProjet(p.id).statut` ;
- la carte affiche nom, client, deux barres (livré, encaissé), montant attendu et reste dû ;
- un `InkWell` ouvre la fiche d'édition ; **aucun `Draggable`** ;
- le bouton « Nouveau projet » ouvre une boîte : nom, client, type, date de début, date de fin prévue.

Supprimer `ProjectCard` de `lib/core/models/divers.dart` — plus aucun code ne l'utilise.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/projets_kanban_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Lancer TOUTE la suite**

Run: `flutter analyze; flutter test`
Expected: PASS intégralement.

Run: `grep -rn "ProjectCard" lib/`
Expected: aucune sortie.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/projets_screen.dart lib/core/models/divers.dart test/projets_kanban_test.dart
git commit -m "feat: Kanban en lecture seule alimente par les vrais projets"
```

---

## Task 10: Saisir les quantités livrées

**Files:**
- Modify: `lib/screens/projets_screen.dart` (fiche projet)
- Test: `test/saisie_livraison_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/saisie_livraison_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  AppState avecProjet() {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME', typeId: 'fourniture', clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)]));
    return s;
  }

  test('setQuantiteLivree met à jour la ligne de la proforma', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 6);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 6);
  });

  test('la quantité livrée est bornée à la quantité commandée', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 25);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 10);
  });

  test('une quantité négative est ramenée à zéro', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, -3);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 0);
  });

  test('un index de ligne hors bornes ne provoque pas d\'erreur', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 9, 5);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 0);
  });

  test('la saisie modifie l\'avancement physique du projet', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 4);
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique,
        closeTo(0.4, 0.0001));
  });

  test('la facture et le BL ne bougent pas', () {
    final s = avecProjet();
    s.validateProforma(1);
    s.setQuantiteLivree(1, 0, 6);
    expect(s.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s.documents['bl']!.first.lines.first.qteLivree, 0);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/saisie_livraison_test.dart`
Expected: FAIL — `setQuantiteLivree` n'existe pas.

- [ ] **Step 3: Ajouter la méthode à `AppState`**

```dart
  /// Enregistre la quantité livrée d'une ligne de proforma.
  ///
  /// La proforma est la SOURCE DE VÉRITÉ du livré : la facture et le BL,
  /// figés à la validation, ne bougent pas. Le BL imprimé continue d'afficher
  /// les quantités commandées (§ 12 de la conception).
  void setQuantiteLivree(int proformaId, int indexLigne, int quantite) {
    final m = documents['proforma']!.where((d) => d.id == proformaId);
    if (m.isEmpty) return;
    final lignes = m.first.lines;
    if (indexLigne < 0 || indexLigne >= lignes.length) return;

    final l = lignes[indexLigne];
    l.qteLivree = quantite < 0 ? 0 : (quantite > l.qte ? l.qte : quantite);
    _emit();
  }
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/saisie_livraison_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Ajouter la saisie dans la fiche projet**

Dans la fiche d'un projet, sous les deux barres : la liste de ses proformas, et pour chaque ligne `désignation — livré [champ] / qte`, appelant `setQuantiteLivree` à la validation du champ.

- [ ] **Step 6: Commit**

```bash
git add lib/core/app_state.dart lib/screens/projets_screen.dart test/saisie_livraison_test.dart
git commit -m "feat: saisie des quantites livrees depuis la fiche projet"
```

---

## Task 11: Vérifier la phase dans l'application réelle

**Files:** aucun.

- [ ] **Step 1: Lancer l'application**

Run: `flutter run -d windows --release`
Expected: la fenêtre s'ouvre sans erreur.

- [ ] **Step 2: Parcourir le flux complet**

1. Créer un projet « Fourniture matériel — ACME », début et fin prévue à un mois d'écart.
2. Créer une proforma pour ACME, la rattacher au projet, deux lignes de prix très différents.
3. Valider la proforma. Vérifier dans Suivi qu'un engagement entrant est apparu, du montant de la facture, sans règlement.
4. Dans la fiche projet, saisir une quantité livrée partielle sur la ligne la moins chère. Vérifier que la barre « livré » reste basse — c'est la pondération par le montant qui fonctionne.
5. Dans Suivi, enregistrer un règlement partiel. Vérifier que la barre « encaissé » bouge, et que la Comptabilité du mois augmente d'autant.
6. Sur le Gantt, vérifier que le projet apparaît aux bonnes dates avec ses deux barres.
7. Sur le Kanban, vérifier que la carte est dans « En cours » et qu'elle ne se déplace pas à la souris.

- [ ] **Step 3: Vérifier la persistance**

Fermer l'application, la relancer. Le projet, son rattachement, les quantités livrées et le règlement doivent tous être là.

- [ ] **Step 4: Consigner le résultat**

Aucun code à commiter. Noter tout écart dans le message de clôture de phase.

---

## Auto-revue du plan

**Couverture de la spec (phase 2)** — § 5.2 (`qteLivree`, `projetId`, copie des lignes) → tâches 2 et 3 ; § 5.3 (`Projet`, `Jalon`) → tâche 1 ; § 6.1 mode `quantites` → tâche 5 ; § 6.2 financier → tâche 5 ; § 6.3 statut déduit et Kanban non déplaçable → tâches 5 et 9 ; § 6.4 marge → tâche 5 (`Avancement.marge`, exploitée en phase 3) ; § 7 flux complet → tâche 4 ; § 13 tests de phase 2 → tâches 3, 5, 6.

**Écrans** — Documents → tâche 7 ; Projets → tâches 9 et 10 ; Gantt → tâche 8.

**Cohérence des signatures** — `Avancement.calculer({projet, mode, proformas, engagements, now, physiqueForce})` est appelée à l'identique en tâches 5 et 6. `avancementProjet(int, {DateTime? now})` est employée de la même façon en tâches 6, 8, 9 et 10. `LineItem.copie()`, défini en tâche 2, est utilisé en tâche 3. `viderDonnees()` vient de la phase 1, tâche 6.
