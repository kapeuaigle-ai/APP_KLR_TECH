# Architecture unifiée : documents, flux financiers, projets — Conception

**Date** : 28/07/2026
**Portée** : refondre la chaîne document → engagement → règlement → comptabilité,
puis bâtir dessus un vrai suivi de projet, ouvert à plusieurs types de projets.

---

## 1. Objectif et cadrage

La page Projets et le Gantt sont aujourd'hui décoratifs. Leurs données sont
codées en dur dans les widgets : quatre colonnes Kanban dont les cartes vivent
dans le `State` ([`projets_screen.dart:32`](../../../lib/screens/projets_screen.dart)),
cinq lignes de Gantt dont les dates sont des index de mois sur un axe « Jan → Juin »
figé ([`gantt_screen.dart:14`](../../../lib/screens/gantt_screen.dart)). Le modèle
`ProjectCard` n'a ni `id`, ni `toJson`, ni `fromJson`, et n'apparaît pas dans
`AppState` : rien n'est persisté.

Brancher ces écrans sur les vraies données a révélé un problème plus profond,
qui les précède : **l'application enregistre un même mouvement d'argent de quatre
façons qui s'ignorent**. Tant que ce socle n'est pas unifié, tout pourcentage
affiché sur un projet repose sur des chiffres invérifiables.

Cette refonte livre donc, dans l'ordre :

1. un socle financier unique — `Engagement` + `Règlement` ;
2. l'entité `Projet`, reliée aux documents et aux engagements ;
3. des types de projet paramétrables, avec quatre modes d'avancement.

**Hors périmètre** : le multi-utilisateur, les bons de livraison partiels
(voir § 12), toute modification de la numérotation des documents, la refonte
visuelle des écrans existants.

---

## 2. Diagnostic : quatre chemins pour un même mouvement d'argent

| Mécanisme | Sens | Partiel ? | Entre en comptabilité par |
|---|---|---|---|
| `DocumentItem.encaissee` | entrant | non — booléen | `documents['facture']` |
| `Engagement` créance | entrant | oui (`acompte`) | `engagements` |
| `Engagement` dette | sortant | oui (`acompte`) | `engagements` |
| `Expense` | sortant | non | `expenses` |

Ce sont deux fois le même doublon :

- `facture.encaissee` est une créance dégénérée, incapable de compter jusqu'à 50 % ;
- `Expense` est une dette dégénérée, réglée le jour de sa création.

`Comptabilite.periode` additionne les factures encaissées **et** les créances
([`comptabilite.dart:108`](../../../lib/core/comptabilite.dart)) sans qu'aucun
lien n'existe entre les deux. `Engagement.num` est un texte libre — le commentaire
du modèle dit lui-même « référence libre (n° de facture, de contrat…) »
([`models.dart:155`](../../../lib/core/models.dart)). Encaisser une facture de
5 M et valider la créance correspondante produit donc 10 M de revenu, sans le
moindre avertissement.

Le précédent d'un lien correct existe pourtant déjà dans le code :
`Expense.factureNumero` rattache une dépense à une facture
([`models.dart:433`](../../../lib/core/models.dart)).

---

## 3. Décision structurante : deux notions, et deux seulement

> **Un engagement** est une promesse de flux : un montant attendu, dans un sens,
> à une échéance.
> **Un règlement** est un mouvement réel : un montant, une date. Partiel ou total.

Tout le reste devient une lecture de ces deux objets :

| Ce qu'on nomme aujourd'hui | Ce que c'est |
|---|---|
| Créance | Engagement entrant |
| Facture encaissée | Engagement entrant intégralement réglé |
| Acompte | Un règlement parmi d'autres |
| Dette | Engagement sortant non soldé |
| Dépense au comptant | Engagement sortant créé et réglé le même jour |
| Comptabilité de caisse | La somme des règlements d'une période |

`DocumentItem.encaissee`, `DocumentItem.dateEncaissement`, `Engagement.acompte`,
`Engagement.dateAcompte`, `Engagement.dateReglement`, `Engagement.statut` et la
classe `Expense` **disparaissent**. Tous sont déductibles des règlements.

La comptabilité reste en base caisse et mensualisée — cette décision, prise dans
la conception du 23/07, ne change pas. Ce qui change, c'est qu'elle n'a plus
qu'une seule liste à parcourir.

---

## 4. Architecture en cinq couches

```
┌─ 5. LECTURES ──────────────────────────────────────────────┐
│  Comptabilité · Rapports · Gantt · Dashboard · Activités   │
│  Ne stockent rien. Calculent tout.                         │
└────────────────────────────────────────────────────────────┘
        ▲ règlements                ▲ avancement
┌─ 4. PROJET ────────────────────────────────────────────────┐
│  Projet (type, dates) · Jalon · TypeProjet                  │
│  Regroupe documents ET engagements. Aucun montant stocké.   │
└────────────────────────────────────────────────────────────┘
        ▲ projetId
┌─ 3. FLUX ──────────────────────────────────────────────────┐
│  Engagement (sens, montant, échéance) · Règlement (date)    │
│  ★ SOURCE UNIQUE de tout mouvement d'argent                 │
└────────────────────────────────────────────────────────────┘
        ▲ documentNumero
┌─ 2. PIÈCES ────────────────────────────────────────────────┐
│  Proforma · Facture · BL · LineItem                         │
│  Décrivent le promis, le livré, le facturé. Pas l'argent.   │
└────────────────────────────────────────────────────────────┘
        ▲ clientId
┌─ 1. RÉFÉRENTIEL ───────────────────────────────────────────┐
│  Client · AppSettings (dont la liste des TypeProjet)        │
└────────────────────────────────────────────────────────────┘
```

**Règle unique, non négociable** : chaque couche ne lit que celles du dessous, et
ne stocke jamais ce qu'elle peut calculer.

C'est cette règle qui garantit qu'aucune redondance ne pourra réapparaître. Un
projet qui stockerait son montant encaissé serait immédiatement en infraction.

---

## 5. Modèle de données

### 5.1 Couche 3 — le cœur financier

```dart
class Reglement {
  final int id;
  DateTime date;
  double montant;
  String moyen;   // 'especes' | 'virement' | 'mobile' | 'cheque'
}

class Engagement {
  final int id;
  final String sens;         // 'entrant' | 'sortant'
  int? projetId;             // null = hors projet
  String? documentNumero;    // facture d'origine (entrant), pièce fournisseur (sortant)
  int? clientId;             // renseigné si entrant
  String tiers;              // fournisseur si sortant ; nom du client si entrant
  String description;
  double montant;            // attendu
  DateTime echeance;
  String categorie;          // analytique — surtout pour les sortants
  List<Reglement> reglements;
  bool annule;

  double get regle    => reglements.fold(0.0, (s, r) => s + r.montant);
  double get reste    => (montant - regle).clamp(0.0, montant);
  bool   get solde    => reste == 0;
  bool   get estEntrant => sens == 'entrant';
  bool   enRetard(DateTime now) => !solde && !annule && echeance.isBefore(now);
}
```

`enRetard` prend `now` en paramètre plutôt que d'appeler `DateTime.now()` :
c'est ce qui rend la règle testable, sur le modèle de `verifierCloture({DateTime? maintenant})`
qui suit déjà cette convention.

**Invariants à faire respecter par `AppState`** :

- un règlement a un montant strictement positif ;
- la somme des règlements ne dépasse jamais `montant` (le dernier est écrêté) ;
- un engagement annulé n'accepte plus de règlement ;
- supprimer un engagement supprime ses règlements (composition, pas association).

### 5.2 Couche 2 — les pièces

```dart
class DocumentItem {
  // ... champs existants, moins encaissee et dateEncaissement
  int? projetId;   // null = vente hors projet
}

class LineItem {
  String ref, designation;
  int qte;
  double pu;
  int qteLivree;   // 0 par défaut
}
```

`DocumentItem.statut` (`'cours' | 'validee' | 'annulee'`) est conservé : c'est un
statut de **workflow documentaire**, sans rapport avec l'argent.

**Correction d'une mine existante.** À la validation d'une proforma, la facture et
le BL reçoivent `lines: p.lines` — la *même instance de liste*, pas une copie
([`app_state.dart:505`](../../../lib/core/app_state.dart) et `:513`). Les trois
documents partagent donc leurs `LineItem`, dont tous les champs sont mutables.
Mais `DocumentItem.fromJson` reconstruit des objets neufs pour chaque document :
**le partage disparaît au rechargement**. Écrire `qteLivree` aurait un effet avant
redémarrage et un autre après.

`validateProforma` doit donc copier les lignes en profondeur, et la **proforma
est la source de vérité du livré**.

### 5.3 Couche 4 — le projet

```dart
class Projet {
  final int id;
  String nom;
  String typeId;             // référence un TypeProjet
  int? clientId;             // null = projet interne
  String client;             // nom dénormalisé, comme DocumentItem.client
  DateTime debut, finPrevue;
  List<Jalon> jalons;
  double avancementManuel;   // 0..1, utilisé seulement si mode == manuel
  bool annule;
  // aucun montant, aucun pourcentage financier
}

class Jalon {
  String nom;
  DateTime prevue;
  DateTime? realisee;   // null = pas encore fait
  double poids;         // pondération dans l'avancement physique
}
```

### 5.4 Couche 1 — les types de projet

```dart
enum ModeAvancement { quantites, jalons, duree, manuel }

class TypeProjet {
  final String id;
  String libelle;         // « Fourniture matériel informatique »
  ModeAvancement mode;
  Color couleur;          // Gantt et Kanban
}
```

La liste vit dans `AppSettings.typesProjet`, éditable dans les Paramètres. Le code
ne connaît jamais les métiers — il connaît quatre modes. Ajouter « Formation » ou
« Infogérance » ne demande aucune ligne de code.

Types livrés par défaut, modifiables :

| Libellé | Mode |
|---|---|
| Fourniture de matériel | `quantites` |
| Installation / déploiement | `jalons` |
| Maintenance / contrat | `duree` |
| Projet interne | `manuel` |

---

## 6. Les calculs dérivés

Un fichier neuf, `lib/core/avancement.dart`, sans état, testable isolément.

### 6.1 Avancement physique — selon le mode

| Mode | Formule |
|---|---|
| `quantites` | `Σ(qteLivree × pu) ÷ Σ(qte × pu)` sur les proformas du projet |
| `jalons` | `Σ poids des jalons réalisés ÷ Σ poids` |
| `duree` | `(now − debut) ÷ (finPrevue − debut)`, borné à [0, 1] |
| `manuel` | `projet.avancementManuel` |

La pondération de `quantites` se fait **par le montant**, non par le nombre
d'articles : livrer 20 souris sur un projet qui comprend aussi un serveur, c'est
95 % des articles mais 15 % de la valeur. Les deux barres parlent ainsi la même
langue — francs livrés d'un côté, francs encaissés de l'autre.

Le mode `duree` reçoit `now` en paramètre, comme `Engagement.enRetard` : aucun
calcul d'avancement n'appelle `DateTime.now()` lui-même, faute de quoi il
deviendrait intestable.

Cas limites : dénominateur nul (projet sans ligne, sans jalon, ou `debut == finPrevue`)
→ avancement 0, jamais `NaN`.

### 6.2 Avancement financier — identique pour tous les modes

```
% financier = Σ regle(engagements entrants du projet) ÷ Σ montant(engagements entrants du projet)
```

### 6.3 Statut du projet — déduit, jamais saisi

Les règles sont évaluées **dans l'ordre**, la première qui correspond l'emporte :

| # | Physique | Financier | Statut |
|---|---|---|---|
| 1 | — | — | Annulé (si `annule`) |
| 2 | 0 % | 0 % | À démarrer |
| 3 | 100 % | 100 % | Soldé |
| 4 | 100 % | < 100 % | **Livré — reste à encaisser** |
| 5 | < 100 % | — | En cours |

`annule` est le seul état stocké : rien dans les données ne permet de deviner
qu'un projet a été abandonné.

**Conséquence assumée** : le Kanban ne peut plus être en glisser-déposer. Si la
colonne est déduite, déplacer une carte à la main ne veut rien dire. Le tableau
devient une vue en lecture seule où les cartes se rangent d'elles-mêmes.

### 6.4 Rentabilité par projet

```
marge = Σ regle(entrants du projet) − Σ regle(sortants du projet)
```

Impossible avant cette refonte, immédiate après : c'est le lien `projetId` sur
l'engagement qui la rend calculable.

### 6.5 Comptabilité

`Comptabilite` ne lit plus que les règlements :

```
revenu(période)   = Σ montant des règlements d'engagements ENTRANTS dans la période
dépenses(période) = Σ montant des règlements d'engagements SORTANTS dans la période
```

Chaque règlement porte sa propre date : la mensualisation et la clôture
fonctionnent sans changement conceptuel. La dîme, les catégories de dépenses et
le rapport de période se calculent sur la même liste.

---

## 7. Le flux complet, de bout en bout

```
Client
  └─ Projet (type → mode d'avancement, debut, finPrevue)
       ├─ Proforma(s)            projetId
       │    └─ validation ──────────────────────────────┐
       │         ├─ Facture                             │
       │         ├─ BL                                  │
       │         └─ Engagement ENTRANT ◄────────────────┘
       │              (montant = facture, documentNumero = n° facture)
       │              └─ Règlement(s)  ──► Comptabilité (revenu)
       │
       └─ Engagement(s) SORTANT(s)   projetId
            (achats, sous-traitance, transport du projet)
            └─ Règlement(s)  ──► Comptabilité (dépense)
```

`validateProforma` produit désormais **trois** objets au lieu de deux : facture,
BL, et l'engagement entrant. Un seul geste, un état cohérent.

---

## 8. Migration des sauvegardes

Le JSON n'a pas de champ de version aujourd'hui
([`app_state.dart:124`](../../../lib/core/app_state.dart)). On en ajoute un ;
son absence signifie v1.

Conversion v1 → v2, au chargement :

| Donnée v1 | Devient |
|---|---|
| `facture.encaissee == true` | Engagement entrant, `montant = facture.montant`, un règlement de ce montant à `dateEncaissement` |
| `facture.encaissee == false` | Engagement entrant, `montant = facture.montant`, aucun règlement |
| `Engagement.acompte > 0` | Un règlement de `acompte` à `dateAcompte` |
| `Engagement.statut == 'paye'` | Un règlement du solde à `dateReglement` |
| `Engagement.sens == 'creance'` | `sens = 'entrant'` |
| `Engagement.sens == 'dette'` | `sens = 'sortant'` |
| `Expense` | Engagement sortant, `montant = amount`, un règlement du même montant à `date`, `documentNumero = factureNumero` |
| `LineItem` sans `qteLivree` | `qteLivree = 0` |

### 8.1 Le doublon hérité

Convertir *chaque* facture en engagement crée un piège : si le manager avait déjà
saisi à la main, dans Suivi, la créance correspondant à une facture, la
conversion produit **deux** engagements pour la même somme attendue.

Le bilan comptable, lui, reste juste — une facture non encaissée n'apporte aucun
règlement, donc aucun revenu. Mais le montant *attendu* serait doublé, faussant
le pourcentage financier du projet et la trésorerie prévisionnelle.

Règle de fusion, appliquée avant toute création :

1. si une créance v1 porte dans son `num` le numéro d'une facture (comparaison
   après normalisation : majuscules, tirets et espaces retirés), les deux ne font
   qu'un — on garde la créance, on lui affecte `documentNumero`, et on ne crée
   pas d'engagement pour cette facture ;
2. sinon, si une créance v1 a le même client **et** exactement le même montant
   qu'une facture non déjà appariée, le cas est **ambigu** : on applique la même
   fusion, et on journalise l'opération dans Activités pour que le manager puisse
   la vérifier ;
3. sinon, la créance et la facture restent deux engagements distincts.

Aucun rapprochement automatique n'est fait sur le seul montant sans le client :
deux factures de 500 000 F à des clients différents ne doivent jamais fusionner.

### 8.2 Critère de réussite

Pour toute sauvegarde v1, le bilan mensuel et le rapport de période calculés
après conversion sont identiques, au centime près, à ceux calculés avant. C'est
ce que vérifie le test de migration — il porte sur les règlements, seuls
responsables des montants comptables, et non sur les montants attendus.

Une sauvegarde v1 est conservée sous `donnees.v1.json` avant réécriture, pour
que la conversion reste réversible en cas d'anomalie découverte tardivement.

---

## 9. Organisation des fichiers

`models.dart` fait 461 lignes et porte onze classes sans rapport entre elles.
La refonte l'aggraverait. On le découpe selon les couches :

```
lib/core/
  models/
    client.dart        Client
    document.dart      DocumentItem, LineItem
    engagement.dart    Engagement, Reglement
    projet.dart        Projet, Jalon, TypeProjet, ModeAvancement
    divers.dart        Task, Note, ActivityItem, DimeEntry, Employee, Department
    settings.dart      AppSettings, kDefaultWarranty
  models.dart          réexporte tout — les imports existants ne changent pas
  avancement.dart      NOUVEAU — calculs de projet, sans état
  comptabilite.dart    réécrit sur les règlements
  app_state.dart       + projets, migration v1→v2
```

`models.dart` devient un fichier de réexport : aucun `import` existant ne casse.

---

## 10. Découpage en trois phases

L'ordre n'est pas négociable : la phase 2 s'appuie sur les règlements de la
phase 1, la phase 3 sur le projet de la phase 2.

### Phase 1 — Le socle financier

`Engagement`/`Reglement` unifiés, `Expense` et `facture.encaissee` absorbés,
`Comptabilite` réécrite, migration v1→v2, écran Suivi adapté à la liste de
règlements, découpage de `models.dart`.

**Aucun changement visible** : mêmes écrans, mêmes chiffres. Les ~2 800 lignes de
tests existantes sont le juge — si `comptabilite_test`, `acompte_test`,
`suivi_compta_test`, `cloture_mensuelle_test`, `rapport_periode_test` et
`persistence_test` passent après réécriture, la refonte est bonne.

### Phase 2 — Le projet

Entité `Projet` persistée, `projetId` sur documents et engagements, `qteLivree`
sur les lignes, correction de la copie de lignes dans `validateProforma`,
`avancement.dart` en mode `quantites` seul, Gantt en vraies dates, Kanban en
lecture seule, création d'engagement entrant dans `validateProforma`.

### Phase 3 — Types et jalons

`TypeProjet` paramétrable dans les Paramètres, les quatre modes d'avancement,
les jalons et leur affichage sur le Gantt, la rentabilité par projet, la
trésorerie prévisionnelle (`Σ reste` des engagements entrants par échéance).

---

## 11. Écrans touchés

| Écran | Phase | Nature du changement |
|---|---|---|
| Suivi | 1 | Liste de règlements au lieu d'un acompte unique ; dépenses fusionnées dans les engagements sortants |
| Comptabilité / Rapports | 1 | Aucune modification visible — la source change, pas l'affichage |
| Documents | 2 | Sélecteur de projet à la création d'une proforma |
| Projets | 2 | Kanban en lecture seule, alimenté par les vraies données |
| Gantt | 2 puis 3 | Vraies dates et deux barres ; jalons en phase 3 |
| Paramètres | 3 | Édition des types de projet |
| Dashboard | 3 | Rentabilité et trésorerie prévisionnelle |

---

## 12. Ce qui est écarté, et pourquoi

**Les bons de livraison partiels.** Le numéro d'un BL est dérivé de celui de sa
proforma : `retype()` change la lettre P→B en gardant compteur et date
([`utils.dart:28`](../../../lib/core/utils.dart)). Deux BL pour une même proforma
porteraient le même numéro. Permettre les livraisons partielles imposerait de
rouvrir la numérotation, décision déjà prise et livrée.

Conséquence assumée : `qteLivree` est un indicateur d'avancement **interne**. Le
BL imprimé continue d'afficher les quantités commandées. Si vous livrez 12 PC sur
20, l'avancement indique 60 % mais le BL en montre 20.

Cette limite est réversible : le jour où les BL multiples deviendront nécessaires,
`qteLivree` se recalculera comme la somme des lignes de BL. Aucune donnée perdue.

**Un référentiel `Tiers` unifiant clients et fournisseurs.** Les engagements
sortants gardent un `tiers` en texte libre. La généralisation serait cohérente,
mais aucun besoin actuel ne la justifie.

**Le suivi par tâches assignées.** L'application est mono-utilisateur ; les
assignés du Kanban actuel (`['AK', 'MD']`) sont décoratifs et disparaissent.

---

## 13. Stratégie de test

**Phase 1 — le filet existe déjà.** La règle est que les tests de comptabilité
passent *sans être réécrits sur le fond* : seule la construction des données de
test change (un règlement au lieu d'un `acompte`). Si un test doit changer
d'assertion, c'est le signe d'une régression, pas d'un test obsolète.

Tests neufs de la phase 1 :

- migration v1→v2 : bilan mensuel et rapport de période identiques avant/après,
  sur une sauvegarde couvrant les quatre mécanismes v1 ;
- fusion du doublon hérité (§ 8.1) : les trois branches de la règle, plus le cas
  de deux factures de même montant à des clients différents, qui ne doivent pas
  fusionner ;
- invariants des règlements : montant positif, somme écrêtée au montant engagé,
  refus sur engagement annulé ;
- suppression en cascade d'un engagement et de ses règlements.

**Phase 2** : calcul de l'avancement `quantites` (dont dénominateur nul) ;
non-partage des `LineItem` après `validateProforma`, vérifié **avant et après**
un cycle de persistance ; création de l'engagement entrant à la validation ;
persistance des projets.

**Phase 3** : les quatre modes d'avancement, dont les bornes de `duree` ;
pondération des jalons ; rentabilité d'un projet mêlant entrants et sortants.

---

## 14. Risques

| Risque | Parade |
|---|---|
| La réécriture de `Comptabilite` fausse des chiffres | Le test de migration compare les résultats avant/après sur les mêmes données |
| La migration v1→v2 perd des données | Sauvegarde `donnees.v1.json` conservée avant réécriture |
| La migration double les montants attendus | Règle de fusion du § 8.1, cas ambigus journalisés dans Activités |
| Le découpage de `models.dart` casse des imports | `models.dart` devient un fichier de réexport |
| La phase 1 n'apporte rien de visible et paraît vaine | Elle est la condition de tout le reste ; son livrable est un socle prouvé par les tests |
