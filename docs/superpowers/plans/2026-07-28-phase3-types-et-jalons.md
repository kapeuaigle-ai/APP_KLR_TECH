# Phase 3 — Types de projet, jalons et rentabilité : Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ouvrir le projet à d'autres métiers que la fourniture de matériel, en rendant les types paramétrables et en implémentant les quatre modes d'avancement — puis exploiter le socle pour la rentabilité par projet et la trésorerie prévisionnelle.

**Architecture:** Un `TypeProjet` porte un libellé, une couleur et un mode d'avancement. Le code ne connaît jamais les métiers du manager : il connaît quatre modes. Ajouter « Formation » ou « Infogérance » ne demande aucune ligne de code.

**Tech Stack:** Flutter/Dart, `provider`, persistance JSON fichier, `flutter_test`.

**Prérequis :** phases 1 et 2 terminées et vertes. `ModeAvancement` existe déjà avec ses quatre valeurs ; `Avancement._physique` rend 0 pour `jalons`, `duree` et `manuel`. `Projet` porte déjà `typeId`, `jalons` et `avancementManuel`. `Avancement.marge` est déjà calculé mais n'est affiché nulle part.

**Spec:** [`docs/superpowers/specs/2026-07-28-architecture-projet-flux-design.md`](../specs/2026-07-28-architecture-projet-flux-design.md) — sections 5.4, 6.1, 6.4, 10 (phase 3), 11, 13.

---

## Structure des fichiers

| Fichier | Responsabilité |
|---|---|
| `lib/core/models/projet.dart` | `TypeProjet` rejoint `Projet`, `Jalon`, `ModeAvancement` |
| `lib/core/models/settings.dart` | `AppSettings.typesProjet` |
| `lib/core/avancement.dart` | Les quatre modes ; `tresoreriePrevisionnelle` |
| `lib/core/app_state.dart` | `modeDuProjet` lit le type ; CRUD des types |
| `lib/screens/parametres_screen.dart` | Édition des types de projet |
| `lib/screens/projets_screen.dart` | Édition des jalons, rentabilité en fiche |
| `lib/screens/gantt_screen.dart` | Jalons sur la barre |
| `lib/screens/dashboard_screen.dart` | Rentabilité et trésorerie prévisionnelle |

---

## Task 1: Le modèle TypeProjet

**Files:**
- Modify: `lib/core/models/projet.dart`
- Test: `test/type_projet_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/type_projet_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('aller-retour JSON, mode et couleur compris', () {
    final t = TypeProjet(
      id: 'installation', libelle: 'Installation réseau',
      mode: ModeAvancement.jalons, couleur: const Color(0xFF2563EB));
    final c = TypeProjet.fromJson(t.toJson());
    expect(c.id, 'installation');
    expect(c.libelle, 'Installation réseau');
    expect(c.mode, ModeAvancement.jalons);
    expect(c.couleur, const Color(0xFF2563EB));
  });

  test('un mode inconnu retombe sur quantites plutôt que de planter', () {
    final c = TypeProjet.fromJson({
      'id': 'x', 'libelle': 'X', 'mode': 'mode_qui_nexiste_pas',
      'couleur': 0xFF000000,
    });
    expect(c.mode, ModeAvancement.quantites);
  });

  test('les quatre types par défaut couvrent les quatre modes', () {
    final defauts = TypeProjet.defauts;
    expect(defauts, hasLength(4));
    expect(defauts.map((t) => t.mode).toSet(), ModeAvancement.values.toSet());
    expect(defauts.map((t) => t.id).toSet(), hasLength(4),
        reason: 'les identifiants doivent être distincts');
  });

  test('le type par défaut « fourniture » est en mode quantites', () {
    final f = TypeProjet.defauts.firstWhere((t) => t.id == 'fourniture');
    expect(f.mode, ModeAvancement.quantites);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/type_projet_test.dart`
Expected: FAIL — `TypeProjet` n'est pas défini.

- [ ] **Step 3: Ajouter `TypeProjet` à `lib/core/models/projet.dart`**

```dart
import 'package:flutter/material.dart';
import 'commun.dart';

/// Un type de projet, défini par le manager dans les Paramètres.
///
/// Le code ne connaît jamais les métiers : il connaît quatre modes
/// d'avancement. Ajouter « Formation » ou « Infogérance » ne demande donc
/// aucune ligne de code.
class TypeProjet {
  final String id;
  String libelle;
  ModeAvancement mode;
  Color couleur;

  TypeProjet({
    required this.id, required this.libelle,
    required this.mode, required this.couleur,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'libelle': libelle, 'mode': mode.name,
    'couleur': colorToInt(couleur),
  };

  factory TypeProjet.fromJson(Map<String, dynamic> j) => TypeProjet(
    id: j['id'], libelle: j['libelle'],
    // Un mode inconnu (type supprimé, sauvegarde d'une version ultérieure)
    // ne doit jamais faire planter le chargement.
    mode: ModeAvancement.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => ModeAvancement.quantites,
    ),
    couleur: colorFromInt(j['couleur']),
  );

  /// Types livrés au premier lancement. Tous modifiables et supprimables.
  static List<TypeProjet> get defauts => [
    TypeProjet(id: 'fourniture', libelle: 'Fourniture de matériel',
        mode: ModeAvancement.quantites, couleur: const Color(0xFF2563EB)),
    TypeProjet(id: 'installation', libelle: 'Installation / déploiement',
        mode: ModeAvancement.jalons, couleur: const Color(0xFFF59E0B)),
    TypeProjet(id: 'maintenance', libelle: 'Maintenance / contrat',
        mode: ModeAvancement.duree, couleur: const Color(0xFF10B981)),
    TypeProjet(id: 'interne', libelle: 'Projet interne',
        mode: ModeAvancement.manuel, couleur: const Color(0xFF8B5CF6)),
  ];
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/type_projet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/projet.dart test/type_projet_test.dart
git commit -m "feat: modele TypeProjet avec ses quatre types par defaut"
```

---

## Task 2: Les types dans AppSettings

**Files:**
- Modify: `lib/core/models/settings.dart`
- Modify: `lib/core/app_state.dart` (`modeDuProjet`, CRUD des types)
- Test: `test/settings_types_projet_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/settings_types_projet_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _p(String typeId) => Projet(
      id: 1, nom: 'P', typeId: typeId, clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30));

void main() {
  test('une sauvegarde sans types reçoit les quatre types par défaut', () {
    final s = AppSettings.fromJson({
      'company': 'KLR', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
      'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
      'tva': 0.0, 'conditions': '',
    });
    expect(s.typesProjet, hasLength(4));
    expect(s.typesProjet.map((t) => t.id), contains('fourniture'));
  });

  test('les types survivent à un aller-retour JSON', () {
    final s = AppSettings.fromJson({
      'company': 'KLR', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
      'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
      'tva': 0.0, 'conditions': '',
    });
    s.typesProjet.add(TypeProjet(id: 'formation', libelle: 'Formation',
        mode: ModeAvancement.jalons, couleur: const Color(0xFF111111)));

    final c = AppSettings.fromJson(s.toJson());
    expect(c.typesProjet, hasLength(5));
    final f = c.typesProjet.firstWhere((t) => t.id == 'formation');
    expect(f.mode, ModeAvancement.jalons);
  });

  test('modeDuProjet lit le mode de son type', () {
    final s = AppState()..viderDonnees();
    expect(s.modeDuProjet(_p('installation')), ModeAvancement.jalons);
    expect(s.modeDuProjet(_p('maintenance')), ModeAvancement.duree);
    expect(s.modeDuProjet(_p('interne')), ModeAvancement.manuel);
    expect(s.modeDuProjet(_p('fourniture')), ModeAvancement.quantites);
  });

  test('un projet dont le type a été supprimé retombe sur quantites', () {
    final s = AppState()..viderDonnees();
    expect(s.modeDuProjet(_p('type_disparu')), ModeAvancement.quantites);
  });

  test('supprimer un type bascule ses projets sur le premier type restant', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p('installation'));
    s.supprimerTypeProjet('installation');

    expect(s.settings.typesProjet.map((t) => t.id), isNot(contains('installation')));
    expect(s.projets.first.typeId, s.settings.typesProjet.first.id,
        reason: 'aucun projet ne doit pointer vers un type disparu');
  });

  test('le dernier type ne peut pas être supprimé', () {
    final s = AppState()..viderDonnees();
    for (final t in List.of(s.settings.typesProjet)) {
      s.supprimerTypeProjet(t.id);
    }
    expect(s.settings.typesProjet, hasLength(1));
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/settings_types_projet_test.dart`
Expected: FAIL — `typesProjet` et `supprimerTypeProjet` n'existent pas.

- [ ] **Step 3: Ajouter `typesProjet` à `AppSettings`**

Dans `lib/core/models/settings.dart` :

```dart
  /// Types de projet définis par le manager. Jamais vide : supprimer le
  /// dernier est refusé, faute de quoi aucun projet ne serait créable.
  List<TypeProjet> typesProjet;
```

Au constructeur : `List<TypeProjet>? typesProjet,` puis `typesProjet = typesProjet ?? TypeProjet.defauts`.

Dans `toJson` : `'typesProjet': typesProjet.map((t) => t.toJson()).toList(),`

Dans `fromJson` :

```dart
    typesProjet: (j['typesProjet'] as List?)
        ?.map((t) => TypeProjet.fromJson(t)).toList(),
```

Passer `null` quand la clé est absente suffit : le constructeur pose alors les défauts. Ajouter l'import de `projet.dart`.

- [ ] **Step 4: Brancher `modeDuProjet` et le CRUD des types**

Dans `lib/core/app_state.dart`, remplacer le `modeDuProjet` provisoire de la phase 2 :

```dart
  TypeProjet? typeProjet(String id) {
    final m = settings.typesProjet.where((t) => t.id == id);
    return m.isEmpty ? null : m.first;
  }

  /// Mode d'avancement d'un projet. Un type disparu retombe sur `quantites`
  /// plutôt que de faire échouer le calcul.
  ModeAvancement modeDuProjet(Projet p) =>
      typeProjet(p.typeId)?.mode ?? ModeAvancement.quantites;

  void ajouterTypeProjet(TypeProjet t) {
    if (typeProjet(t.id) != null) return;
    settings.typesProjet.add(t);
    _emit();
  }

  void majTypeProjet(TypeProjet t) {
    final i = settings.typesProjet.indexWhere((x) => x.id == t.id);
    if (i < 0) return;
    settings.typesProjet[i] = t;
    _emit();
  }

  /// Supprime un type et rebascule ses projets sur le premier type restant.
  /// Le dernier type ne peut pas être supprimé : aucun projet ne serait
  /// créable ensuite.
  void supprimerTypeProjet(String id) {
    if (settings.typesProjet.length <= 1) return;
    settings.typesProjet.removeWhere((t) => t.id == id);
    final repli = settings.typesProjet.first.id;
    for (final p in projets) {
      if (p.typeId == id) p.typeId = repli;
    }
    _emit();
  }
```

- [ ] **Step 5: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/settings_types_projet_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
git add lib/core/models/settings.dart lib/core/app_state.dart test/settings_types_projet_test.dart
git commit -m "feat: types de projet parametrables dans AppSettings"
```

---

## Task 3: Les trois modes d'avancement restants

**Files:**
- Modify: `lib/core/avancement.dart` (`_physique`)
- Test: `test/avancement_modes_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/avancement_modes_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _projet({
  List<Jalon>? jalons,
  double manuel = 0,
  DateTime? debut,
  DateTime? fin,
}) => Projet(
      id: 1, nom: 'P', typeId: 't', clientId: 5, client: 'ACME',
      debut: debut ?? DateTime(2026, 3, 1),
      finPrevue: fin ?? DateTime(2026, 6, 30),
      jalons: jalons, avancementManuel: manuel);

double _phys(Projet p, ModeAvancement mode, DateTime now) =>
    Avancement.calculer(
      projet: p, mode: mode, proformas: const [], engagements: const [], now: now,
    ).physique;

void main() {
  group('mode jalons', () {
    test('aucun jalon fait donne 0', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), poids: 1),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), poids: 1),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15)), 0);
    });

    test('les poids sont respectés, pas le simple décompte', () {
      // 1 jalon fait sur 2, mais il pèse 3 sur 5 : 60 %, pas 50 %.
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 3),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), poids: 2),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15)), closeTo(0.6, 0.0001));
    });

    test('tous les jalons faits donnent 1', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 3),
        Jalon(nom: 'B', prevue: DateTime(2026, 5, 1), realisee: DateTime(2026, 5, 3), poids: 2),
      ]);
      expect(_phys(p, ModeAvancement.jalons, DateTime(2026, 6, 1)), 1);
    });

    test('sans jalon, 0 et jamais NaN', () {
      final p = _projet(jalons: []);
      final v = _phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15));
      expect(v, 0);
      expect(v.isNaN, isFalse);
    });

    test('des poids tous nuls ne produisent pas de NaN', () {
      final p = _projet(jalons: [
        Jalon(nom: 'A', prevue: DateTime(2026, 4, 1), realisee: DateTime(2026, 4, 2), poids: 0),
      ]);
      final v = _phys(p, ModeAvancement.jalons, DateTime(2026, 4, 15));
      expect(v, 0);
      expect(v.isNaN, isFalse);
    });
  });

  group('mode duree', () {
    final p = _projet(debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 11));

    test('avant le début : 0, jamais négatif', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2025, 12, 1)), 0);
    });

    test('au début : 0', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 1)), 0);
    });

    test('à mi-parcours : 0,5', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 6)), closeTo(0.5, 0.0001));
    });

    test('à la fin prévue : 1', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 1, 11)), 1);
    });

    test('après la fin : 1, jamais au-delà', () {
      expect(_phys(p, ModeAvancement.duree, DateTime(2026, 3, 1)), 1);
    });

    test('début et fin le même jour ne produisent pas de NaN', () {
      final court = _projet(debut: DateTime(2026, 1, 1), fin: DateTime(2026, 1, 1));
      final v = _phys(court, ModeAvancement.duree, DateTime(2026, 1, 1));
      expect(v.isNaN, isFalse);
      expect(v, anyOf(0, 1));
    });
  });

  group('mode manuel', () {
    test('rend la valeur saisie', () {
      expect(_phys(_projet(manuel: 0.35), ModeAvancement.manuel, DateTime(2026, 4, 1)),
          closeTo(0.35, 0.0001));
    });

    test('une valeur hors bornes est ramenée dans [0, 1]', () {
      expect(_phys(_projet(manuel: 1.8), ModeAvancement.manuel, DateTime(2026, 4, 1)), 1);
      expect(_phys(_projet(manuel: -0.5), ModeAvancement.manuel, DateTime(2026, 4, 1)), 0);
    });
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/avancement_modes_test.dart`
Expected: FAIL — les trois modes rendent encore 0.

- [ ] **Step 3: Implémenter les trois modes**

Dans `lib/core/avancement.dart`, remplacer le `switch` de `_physique` :

```dart
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
        var total = 0.0, fait = 0.0;
        for (final j in projet.jalons) {
          total += j.poids;
          if (j.fait) fait += j.poids;
        }
        return total == 0 ? 0.0 : (fait / total).clamp(0.0, 1.0);

      case ModeAvancement.duree:
        final debut = DateTime(projet.debut.year, projet.debut.month, projet.debut.day);
        final fin = DateTime(
            projet.finPrevue.year, projet.finPrevue.month, projet.finPrevue.day);
        final jour = DateTime(now.year, now.month, now.day);
        final duree = fin.difference(debut).inDays;
        if (duree <= 0) return jour.isBefore(fin) ? 0.0 : 1.0;
        final ecoule = jour.difference(debut).inDays;
        return (ecoule / duree).clamp(0.0, 1.0);

      case ModeAvancement.manuel:
        return projet.avancementManuel.clamp(0.0, 1.0);
    }
  }
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/avancement_modes_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 5: Vérifier que la phase 2 n'a pas bougé**

Run: `flutter test test/avancement_test.dart`
Expected: PASS — le mode `quantites` est inchangé.

- [ ] **Step 6: Commit**

```bash
git add lib/core/avancement.dart test/avancement_modes_test.dart
git commit -m "feat: modes d'avancement jalons, duree et manuel"
```

---

## Task 4: Éditer les jalons d'un projet

**Files:**
- Modify: `lib/core/app_state.dart`
- Modify: `lib/screens/projets_screen.dart` (fiche projet)
- Test: `test/jalons_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/jalons_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _avecProjetJalons() {
  final s = AppState()..viderDonnees();
  s.addProjet(Projet(
    id: 1, nom: 'Câblage siège', typeId: 'installation', clientId: 5,
    client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
  return s;
}

void main() {
  test('ajouterJalon puis marquerJalon font monter l\'avancement', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.ajouterJalon(1, Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3));

    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique, 0);

    s.marquerJalon(1, 0, DateTime(2026, 3, 16));
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique,
        closeTo(0.25, 0.0001));
  });

  test('démarquer un jalon fait redescendre l\'avancement', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.marquerJalon(1, 0, DateTime(2026, 3, 16));
    s.marquerJalon(1, 0, null);
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique, 0);
  });

  test('supprimerJalon retire l\'étape visée', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.ajouterJalon(1, Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3));
    s.supprimerJalon(1, 0);
    expect(s.projets.first.jalons, hasLength(1));
    expect(s.projets.first.jalons.first.nom, 'Pose');
  });

  test('un index hors bornes ne provoque pas d\'erreur', () {
    final s = _avecProjetJalons();
    s.marquerJalon(1, 9, DateTime(2026, 3, 16));
    s.supprimerJalon(1, 9);
    expect(s.projets.first.jalons, isEmpty);
  });

  test('setAvancementManuel borne la valeur dans [0, 1]', () {
    final s = _avecProjetJalons();
    s.setAvancementManuel(1, 1.5);
    expect(s.projets.first.avancementManuel, 1);
    s.setAvancementManuel(1, -0.2);
    expect(s.projets.first.avancementManuel, 0);
    s.setAvancementManuel(1, 0.4);
    expect(s.projets.first.avancementManuel, closeTo(0.4, 0.0001));
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/jalons_test.dart`
Expected: FAIL — `ajouterJalon`, `marquerJalon`, `supprimerJalon`, `setAvancementManuel` n'existent pas.

- [ ] **Step 3: Ajouter les méthodes à `AppState`**

```dart
  Projet? _projet(int id) {
    final m = projets.where((p) => p.id == id);
    return m.isEmpty ? null : m.first;
  }

  void ajouterJalon(int projetId, Jalon j) {
    final p = _projet(projetId);
    if (p == null) return;
    p.jalons.add(j);
    _emit();
  }

  /// Marque un jalon comme réalisé à `date`, ou le démarque si `date` est nul.
  void marquerJalon(int projetId, int index, DateTime? date) {
    final p = _projet(projetId);
    if (p == null || index < 0 || index >= p.jalons.length) return;
    p.jalons[index].realisee = date;
    _emit();
  }

  void supprimerJalon(int projetId, int index) {
    final p = _projet(projetId);
    if (p == null || index < 0 || index >= p.jalons.length) return;
    p.jalons.removeAt(index);
    _emit();
  }

  void setAvancementManuel(int projetId, double valeur) {
    final p = _projet(projetId);
    if (p == null) return;
    p.avancementManuel = valeur.clamp(0.0, 1.0);
    _emit();
  }
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/jalons_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Ajouter l'édition dans la fiche projet**

Dans la fiche, la section d'avancement s'adapte au mode du projet :

- `quantites` → la liste des lignes de proforma avec leur quantité livrée (déjà en place, phase 2) ;
- `jalons` → la liste des jalons, chacun avec une case à cocher appelant `marquerJalon`, un poids, et un bouton de suppression ; un bouton « Ajouter un jalon » ouvrant une boîte nom + date prévue + poids ;
- `duree` → un texte en lecture seule expliquant que l'avancement suit le calendrier ;
- `manuel` → un curseur de 0 à 100 % appelant `setAvancementManuel`.

- [ ] **Step 6: Commit**

```bash
git add lib/core/app_state.dart lib/screens/projets_screen.dart test/jalons_test.dart
git commit -m "feat: edition des jalons et de l'avancement manuel"
```

---

## Task 5: Éditer les types dans les Paramètres

**Files:**
- Modify: `lib/screens/parametres_screen.dart`
- Test: `test/parametres_types_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/parametres_types_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/parametres_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les quatre types par défaut sont listés', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TYPES DE PROJET'), findsOneWidget);
    expect(find.text('Fourniture de matériel'), findsOneWidget);
    expect(find.text('Installation / déploiement'), findsOneWidget);
    expect(find.text('Maintenance / contrat'), findsOneWidget);
    expect(find.text('Projet interne'), findsOneWidget);
  });

  testWidgets('chaque type annonce son mode d\'avancement', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quantités livrées'), findsWidgets);
    expect(find.textContaining('Jalons'), findsWidgets);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/parametres_types_test.dart`
Expected: FAIL — aucune section « TYPES DE PROJET ».

- [ ] **Step 3: Ajouter la section aux Paramètres**

Un `CardBox` titré « TYPES DE PROJET », listant `state.settings.typesProjet` : pastille de couleur, libellé, mode en sous-titre, boutons modifier et supprimer. Un bouton « Ajouter un type » ouvre une boîte : libellé, mode (quatre choix), couleur. L'identifiant se dérive du libellé (minuscules, sans accents ni espaces) avec un suffixe numérique en cas de collision.

Libellés des modes, à mettre dans une extension de `ModeAvancement` pour rester réutilisables :

```dart
extension ModeAvancementLibelle on ModeAvancement {
  String get libelle => switch (this) {
    ModeAvancement.quantites => 'Quantités livrées',
    ModeAvancement.jalons => 'Jalons',
    ModeAvancement.duree => 'Durée écoulée',
    ModeAvancement.manuel => 'Saisie manuelle',
  };

  String get explication => switch (this) {
    ModeAvancement.quantites =>
      'L\'avancement se déduit des quantités livrées, pondérées par le montant.',
    ModeAvancement.jalons =>
      'L\'avancement se déduit des jalons réalisés, selon leur poids.',
    ModeAvancement.duree =>
      'L\'avancement suit le calendrier, du début à la fin prévue.',
    ModeAvancement.manuel =>
      'L\'avancement est saisi à la main. Aucun contrôle possible.',
  };
}
```

Placer cette extension dans `lib/core/models/projet.dart`, à côté de l'enum.

Le bouton « Supprimer » est désactivé quand il ne reste qu'un seul type, et un texte explique pourquoi.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/parametres_types_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/parametres_screen.dart lib/core/models/projet.dart test/parametres_types_test.dart
git commit -m "feat: edition des types de projet dans les Parametres"
```

---

## Task 6: Les jalons sur le Gantt

**Files:**
- Modify: `lib/screens/gantt_screen.dart`
- Test: `test/gantt_jalons_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/gantt_jalons_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les jalons d\'un projet apparaissent en repères sur sa barre', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Câblage siège', typeId: 'installation', clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      jalons: [
        Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 20), realisee: DateTime(2026, 3, 22), poids: 1),
        Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3),
      ]));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: GanttScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('jalon-1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('jalon-1-1')), findsOneWidget);
  });

  testWidgets('un projet en mode quantites n\'affiche aucun repère de jalon', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.addProjet(Projet(
      id: 1, nom: 'Fourniture', typeId: 'fourniture', clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: GanttScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('jalon-1-0')), findsNothing);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/gantt_jalons_test.dart`
Expected: FAIL — aucun widget porteur de ces clés.

- [ ] **Step 3: Poser les repères sur la barre**

Dans `_GanttRow`, à l'intérieur du `Stack` de la barre, après les deux remplissages :

```dart
// Repères de jalons : losange plein si réalisé, creux sinon. La clé permet
// de les cibler en test sans dépendre du rendu graphique.
...projet.jalons.asMap().entries.map((e) {
  final j = e.value;
  final pos = _positionEnMois(j.prevue, axeDebut) * unitW;
  return Positioned(
    key: ValueKey('jalon-${projet.id}-${e.key}'),
    left: pos - 5, top: 1, width: 10, height: 10,
    child: Tooltip(
      message: '${j.nom} — ${j.fait ? 'réalisé' : 'prévu'} '
               'le ${Fmt.jour(j.realisee ?? j.prevue)}',
      child: Transform.rotate(
        angle: 0.785, // 45° : un carré tourné se lit comme un losange
        child: Container(decoration: BoxDecoration(
          color: j.fait ? couleur : Colors.white,
          border: Border.all(color: couleur, width: 1.5),
        )),
      ),
    ),
  );
}),
```

`_positionEnMois(DateTime d, DateTime axeDebut)` rend la position en mois décimaux :

```dart
double _positionEnMois(DateTime d, DateTime axeDebut) {
  final mois = (d.year - axeDebut.year) * 12 + d.month - axeDebut.month;
  final joursDuMois = DateTime(d.year, d.month + 1, 0).day;
  return mois + (d.day - 1) / joursDuMois;
}
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/gantt_jalons_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/gantt_screen.dart test/gantt_jalons_test.dart
git commit -m "feat: reperes de jalons sur les barres du Gantt"
```

---

## Task 7: Rentabilité et trésorerie prévisionnelle

**Files:**
- Modify: `lib/core/avancement.dart` (ajouter `tresoreriePrevisionnelle`)
- Modify: `lib/screens/dashboard_screen.dart`
- Modify: `lib/screens/projets_screen.dart` (marge en fiche)
- Test: `test/rentabilite_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/rentabilite_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Engagement _e(String sens, double montant, DateTime echeance,
        {List<Reglement>? regs, int? projetId, bool annule = false}) =>
    Engagement(
      id: echeance.microsecondsSinceEpoch, sens: sens, tiers: 'T',
      montant: montant, echeance: echeance, projetId: projetId,
      reglements: regs, annule: annule);

Reglement _r(double m, DateTime d) => Reglement(id: 1, date: d, montant: m);

void main() {
  test('la trésorerie prévisionnelle est le reste dû des entrants, par échéance', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('entrant', 1000, DateTime(2026, 5, 31), regs: [_r(400, DateTime(2026, 4, 1))]),
        _e('entrant', 2000, DateTime(2026, 6, 30)),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t, hasLength(2));
    expect(t[0].echeance, DateTime(2026, 5, 31));
    expect(t[0].montant, 600);
    expect(t[1].montant, 2000);
  });

  test('les entrants soldés n\'apparaissent pas', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [_e('entrant', 1000, DateTime(2026, 5, 31), regs: [_r(1000, DateTime(2026, 4, 1))])],
      now: DateTime(2026, 4, 1),
    );
    expect(t, isEmpty);
  });

  test('les sortants et les annulés sont exclus', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('sortant', 900, DateTime(2026, 5, 31)),
        _e('entrant', 700, DateTime(2026, 5, 31), annule: true),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t, isEmpty);
  });

  test('les échéances sortent triées, de la plus proche à la plus lointaine', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [
        _e('entrant', 100, DateTime(2026, 8, 1)),
        _e('entrant', 200, DateTime(2026, 5, 1)),
        _e('entrant', 300, DateTime(2026, 6, 1)),
      ],
      now: DateTime(2026, 4, 1),
    );
    expect(t.map((x) => x.montant).toList(), [200, 300, 100]);
  });

  test('une échéance dépassée est signalée en retard', () {
    final t = Avancement.tresoreriePrevisionnelle(
      [_e('entrant', 500, DateTime(2026, 3, 1))],
      now: DateTime(2026, 4, 1),
    );
    expect(t.single.enRetard, isTrue);
  });

  test('la marge d\'un projet est encaissé moins décaissé', () {
    final a = Avancement.calculer(
      projet: Projet(id: 1, nom: 'P', typeId: 'fourniture', clientId: 5,
          client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)),
      mode: ModeAvancement.quantites,
      proformas: const [],
      engagements: [
        _e('entrant', 3000, DateTime(2026, 6, 1), regs: [_r(3000, DateTime(2026, 4, 1))], projetId: 1),
        _e('sortant', 1800, DateTime(2026, 4, 5), regs: [_r(1800, DateTime(2026, 4, 5))], projetId: 1),
      ],
      now: DateTime(2026, 5, 1),
    );
    expect(a.montantEncaisse, 3000);
    expect(a.montantDepense, 1800);
    expect(a.marge, 1200);
  });

  test('la marge d\'un projet sans flux vaut 0', () {
    final a = Avancement.calculer(
      projet: Projet(id: 1, nom: 'P', typeId: 'fourniture', clientId: 5,
          client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)),
      mode: ModeAvancement.quantites,
      proformas: const [], engagements: const [], now: DateTime(2026, 5, 1),
    );
    expect(a.marge, 0);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/rentabilite_test.dart`
Expected: FAIL — `tresoreriePrevisionnelle` n'existe pas.

- [ ] **Step 3: Ajouter le calcul à `lib/core/avancement.dart`**

```dart
/// Une rentrée attendue, à une échéance.
class EcheanceAttendue {
  final DateTime echeance;
  final double montant;
  final String tiers;
  final String? documentNumero;
  final bool enRetard;

  const EcheanceAttendue({
    required this.echeance, required this.montant, required this.tiers,
    required this.documentNumero, required this.enRetard,
  });
}
```

Et, dans la classe `Avancement` :

```dart
  /// Ce qui doit rentrer, et quand : le reste dû de chaque engagement entrant
  /// non soldé, trié de l'échéance la plus proche à la plus lointaine.
  ///
  /// Ne devient calculable qu'une fois les engagements unifiés : c'est une
  /// retombée directe de la phase 1.
  static List<EcheanceAttendue> tresoreriePrevisionnelle(
      List<Engagement> engagements, {required DateTime now}) {
    final res = engagements
        .where((e) => e.estEntrant && !e.annule && !e.solde)
        .map((e) => EcheanceAttendue(
              echeance: e.echeance,
              montant: e.reste,
              tiers: e.tiers,
              documentNumero: e.documentNumero,
              enRetard: e.enRetard(now),
            ))
        .toList();
    res.sort((a, b) => a.echeance.compareTo(b.echeance));
    return res;
  }
```

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/rentabilite_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Afficher les deux nouveautés**

Dans la fiche projet : une ligne « Marge » sous les deux barres — encaissé, décaissé, marge — en vert si positive, en rouge sinon.

Dans le Dashboard : un `CardBox` « À encaisser » listant les cinq premières `EcheanceAttendue`, celles en retard en rouge, avec le total en pied.

- [ ] **Step 6: Commit**

```bash
git add lib/core/avancement.dart lib/screens/ test/rentabilite_test.dart
git commit -m "feat: rentabilite par projet et tresorerie previsionnelle"
```

---

## Task 8: Choisir le type à la création d'un projet

**Files:**
- Modify: `lib/screens/projets_screen.dart` (boîte « Nouveau projet »)
- Test: `test/creation_projet_type_test.dart` (créer)

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/creation_projet_type_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('la boîte « Nouveau projet » propose les types paramétrés', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('Fourniture de matériel'), findsWidgets);
  });

  testWidgets('le mode du type choisi est expliqué dans la boîte', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pondérées par le montant'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Lancer le test et vérifier qu'il échoue**

Run: `flutter test test/creation_projet_type_test.dart`
Expected: FAIL — pas de champ « TYPE » dans la boîte.

- [ ] **Step 3: Ajouter le sélecteur de type**

Dans la boîte « Nouveau projet » de `projets_screen.dart`, sous le nom et le client : un `DropdownButtonFormField<String>` alimenté par `state.settings.typesProjet`, et sous lui un texte gris affichant `mode.explication` du type sélectionné — pour que le manager sache **comment son avancement sera mesuré** avant de valider.

- [ ] **Step 4: Lancer le test et vérifier qu'il passe**

Run: `flutter test test/creation_projet_type_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Lancer TOUTE la suite**

Run: `flutter analyze; flutter test`
Expected: PASS intégralement.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/projets_screen.dart test/creation_projet_type_test.dart
git commit -m "feat: choix du type et de son mode a la creation d'un projet"
```

---

## Task 9: Vérifier la phase dans l'application réelle

**Files:** aucun.

- [ ] **Step 1: Lancer l'application**

Run: `flutter run -d windows --release`
Expected: la fenêtre s'ouvre sans erreur.

- [ ] **Step 2: Exercer les quatre modes**

1. **Paramètres** — vérifier que les quatre types sont listés avec leur mode. En créer un cinquième, « Formation », en mode jalons. Vérifier qu'il apparaît aussitôt à la création d'un projet.
2. **Mode jalons** — créer un projet « Câblage siège » de type Installation, y ajouter trois jalons de poids 1, 3 et 1. En cocher un de poids 3 : l'avancement doit afficher 60 %, pas 33 %.
3. **Mode durée** — créer un projet de type Maintenance sur douze mois. L'avancement doit correspondre à la fraction de temps écoulée depuis le début.
4. **Mode manuel** — créer un projet interne, déplacer le curseur à 40 %, vérifier que la barre suit.
5. **Mode quantités** — vérifier que le projet de la phase 2 se comporte comme avant.

- [ ] **Step 3: Vérifier les jalons sur le Gantt**

Sur le Gantt, le projet « Câblage siège » doit porter trois losanges aux bonnes dates : plein pour le jalon réalisé, creux pour les deux autres.

- [ ] **Step 4: Vérifier la rentabilité et la trésorerie**

Sur un projet ayant des encaissements et des dépenses rattachées, vérifier que la marge affichée vaut bien encaissé − décaissé. Sur le Dashboard, vérifier que « À encaisser » liste les échéances non soldées, les dépassées en rouge.

- [ ] **Step 5: Vérifier la suppression d'un type**

Supprimer le type « Formation » alors qu'un projet l'utilise : le projet doit basculer sur le premier type restant, sans erreur ni projet orphelin. Vérifier ensuite qu'on ne peut pas supprimer le dernier type restant.

- [ ] **Step 6: Vérifier la persistance**

Fermer et relancer. Types, jalons, avancement manuel et rattachements doivent tous être là.

---

## Auto-revue du plan

**Couverture de la spec (phase 3)** — § 5.4 (`TypeProjet`, `ModeAvancement`, types par défaut) → tâches 1 et 2 ; § 6.1 les quatre modes → tâche 3 ; § 6.4 rentabilité → tâche 7 ; § 10 phase 3 (types, modes, jalons, rentabilité, trésorerie) → tâches 1 à 8 ; § 11 écrans Paramètres et Dashboard → tâches 5 et 7 ; § 13 tests de phase 3 (quatre modes dont bornes de `duree`, pondération des jalons, rentabilité mêlant entrants et sortants) → tâches 3 et 7.

**Cohérence des signatures** — `Avancement.calculer({projet, mode, proformas, engagements, now, physiqueForce})` est inchangée depuis la phase 2 : la tâche 3 ne modifie que le corps de `_physique`, jamais sa signature. `modeDuProjet(Projet)`, défini en phase 2 tâche 6 comme constante provisoire, est remplacé en tâche 2 en gardant exactement le même type de retour, donc `avancementProjet` n'a pas à changer. `ModeAvancementLibelle` est déclarée en tâche 5 et utilisée en tâches 5 et 8. `EcheanceAttendue` est déclarée et consommée dans la seule tâche 7.

**Point de vigilance pour l'exécutant** — la tâche 3 fait passer trois modes de « rend 0 » à « calcule ». Tout projet existant de type `installation`, `maintenance` ou `interne` verra donc son avancement changer d'un coup. C'est voulu, mais à annoncer si des projets réels ont été saisis pendant la phase 2.
