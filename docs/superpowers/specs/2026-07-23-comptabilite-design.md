# Comptabilité — Bénéfice, dépenses et dîme

Date : 2026-07-23
Statut : validé (design), prêt pour le plan d'implémentation

## Contexte

L'application KLR TECH gère des documents (proforma → facture + BL générés à la
validation d'une proforma) et un onglet « Suivi » contenant *Factures & Crédits ·
Dîme · Tâches · Notes*. L'onglet « Dîme » actuel calcule 10 % sur le **revenu**, à
partir de données d'exemple statiques (`SampleData.dimeHistory`).

Le manager veut gérer sa comptabilité : saisir les **dépenses** (par facture et
générales), en tirer le **bénéfice**, et calculer la **dîme = 10 % du bénéfice
mensuel**. Le bénéfice se calcule en **comptabilité de caisse** : seules les
factures **encaissées** comptent comme revenu.

L'app fonctionne aujourd'hui entièrement **en mémoire** (état `AppState`, données
d'exemple, aucune persistance disque). Cette fonctionnalité suit le même modèle.

## Objectifs

- Nouvel onglet **« Comptabilité »** dans la page Suivi.
- Saisie de **dépenses** rattachées à une facture précise **ou** générales.
- Suivi de l'**encaissement** des factures réelles (bascule + date).
- Calcul du **bénéfice** par facture, total, et **mensuel**.
- **Dîme = 10 % du bénéfice mensuel** ; l'onglet « Dîme » est recalculé sur cette base.
- **Bilan mensuel** (le « bilan des activités »).

## Non-objectifs (hors périmètre)

- Persistance sur disque (survie au redémarrage) — concernerait toute l'app ;
  étape séparée ultérieure.
- Refonte de l'onglet « Factures & Crédits » (suivi de paiement sur données
  d'exemple `SampleData.factureHistory`) : laissé tel quel pour l'instant.
- Ventilation par client / projet, export comptable, TVA à reverser.

## Règles de calcul

- **Revenu d'une facture = son HT** = somme des lignes (`qte × pu`), recalculé
  depuis `DocumentItem.lines`. (Le champ `montant` est le TTC ; on n'utilise pas
  le TTC pour le bénéfice.)
- **Source des revenus** : les factures générées (`documents['facture']`).
- **Comptabilité de caisse** : une facture ne compte comme revenu que si elle est
  **encaissée** (`encaissee == true`). Son revenu est rattaché au **mois de sa
  date d'encaissement**.
- **Dépense** : rattachée à son propre mois (date de la dépense). Peut être liée à
  une facture (`factureNumero`) ou générale (`factureNumero == null`).
- **Bénéfice par facture** (potentiel) = HT de la facture − somme des dépenses
  rattachées à cette facture. Affiché pour toutes les factures ; n'entre dans les
  totaux/dîme que si la facture est encaissée.
- **Bénéfice mensuel** = (revenu HT encaissé du mois) − (dépenses du mois).
- **Dîme mensuelle** = `10 % × max(0, bénéfice mensuel)` (pas de dîme sur un mois
  en perte).
- **Totaux** (cartes de synthèse) : Revenu HT encaissé total, Dépenses totales,
  Bénéfice total = revenu encaissé − dépenses, Dîme totale = somme des dîmes
  mensuelles.

Un « mois » est identifié par `année-mois` extrait d'une date `dd/MM/yyyy` (dates
de facture/encaissement) ou d'un `DateTime` (dépenses). Libellé affiché en
français : « Juillet 2026 ».

## Modèle de données

### Nouveau : `Expense` (lib/core/models.dart)

```
class Expense {
  final int id;              // millisecondsSinceEpoch
  DateTime date;
  String label;              // libellé
  double amount;             // montant (FCFA)
  String category;           // voir catégories
  String? factureNumero;     // null = dépense générale
}
```

Catégories : `Achat matériel`, `Transport`, `Sous-traitance`, `Loyer & charges`,
`Salaires`, `Autre`.

### Modifié : `DocumentItem` (lib/core/models.dart)

Ajouter deux champs **mutables** (utilisés pour les factures ; ignorés pour
proforma/BL) :

```
bool encaissee = false;
String? dateEncaissement;  // 'dd/MM/yyyy', renseignée quand encaissee == true
```

Valeurs par défaut : `encaissee = false`, `dateEncaissement = null`. Une facture
générée à la validation d'une proforma démarre non encaissée.

### Suivi de versement de la dîme

Le versement de la dîme d'un mois est suivi dans `AppState` :

```
final Set<String> _dimePaidMonths = {};      // clés 'yyyy-MM'
final Map<String, String> _dimePaidDates = {}; // 'yyyy-MM' -> 'dd/MM/yyyy'
```

## Changements `AppState` (lib/core/app_state.dart)

Champs :
- `late List<Expense> expenses;` (initialisé à partir de `SampleData` — quelques
  dépenses d'exemple pour que l'écran ne soit pas vide).
- `_dimePaidMonths`, `_dimePaidDates` (ci-dessus).

Méthodes :
- `void addExpense(Expense e)` / `void updateExpense(Expense e)` /
  `void deleteExpense(int id)`.
- `void setFactureEncaissee(int id, bool encaissee, {String? date})` — bascule
  l'encaissement d'une facture (`documents['facture']`) ; met `dateEncaissement`.
- `void setDimePaid(String monthKey, bool paid, {String? date})`.

Getters/helpers calculés (peuvent vivre dans un service `Comptabilite` dédié pour
garder `AppState` léger — voir Architecture) :
- HT d'une facture, dépenses d'une facture, bénéfice d'une facture.
- Totaux (revenu encaissé, dépenses, bénéfice, dîme).
- **Bilan mensuel** : liste ordonnée de `MonthlyRow { monthKey, label, revenuHt,
  depenses, benefice, dime, dimePaid, dimeDate }`.

## Architecture

Pour ne pas gonfler `AppState`, la logique de calcul est isolée dans un helper pur
**`lib/core/comptabilite.dart`** :

```
class Comptabilite {
  static double factureHt(DocumentItem f);
  static double depensesFacture(String numero, List<Expense> expenses);
  static double beneficeFacture(DocumentItem f, List<Expense> expenses);
  static ComptaTotaux totaux(List<DocumentItem> factures, List<Expense> expenses);
  static List<MonthlyRow> bilanMensuel(
      List<DocumentItem> factures, List<Expense> expenses,
      Set<String> dimePaidMonths, Map<String,String> dimePaidDates);
  static String monthKeyFromDdMmYyyy(String date);   // 'dd/MM/yyyy' -> 'yyyy-MM'
  static String monthKeyFromDate(DateTime d);
  static String monthLabel(String monthKey);          // 'yyyy-MM' -> 'Juillet 2026'
}
```

`AppState` expose les données brutes (`documents['facture']`, `expenses`, sets de
dîme) ; l'UI appelle `Comptabilite` pour les dérivés. Ce helper pur est
**testable unitairement** sans widget.

Types de support : `ComptaTotaux { revenuHt, depenses, benefice, dime }` et
`MonthlyRow` (ci-dessus).

## UI

### Onglet « Comptabilité » (nouveau, dans `suivi_screen.dart`)

Ordre des onglets Suivi : *Factures & Crédits · **Comptabilité** · Dîme · Tâches ·
Notes* (mettre à jour `AppTabBar`).

Contenu (de haut en bas), style existant (`StatGrid`, `StatCard`, `CardBox`,
`HScrollTable`, `PrimaryBtn`) :

1. **Cartes de synthèse** (`StatGrid`) : Revenu HT encaissé · Dépenses totales ·
   Bénéfice total · Dîme totale (10 %). Bénéfice en rouge si négatif.
2. **Ajouter une dépense** (`CardBox` avec formulaire) : date (sélecteur, défaut
   aujourd'hui), libellé, montant, catégorie (puces sélectionnables), rattachement
   (menu : « Générale » ou une facture par N°). Bouton « Ajouter la dépense ».
3. **Bénéfice par facture** (`CardBox` + `HScrollTable`) : colonnes *N° · Client ·
   HT · Dépenses · Bénéfice · Encaissée*. La colonne « Encaissée » est une bascule ;
   à l'activation, on demande/renseigne la date d'encaissement (défaut
   aujourd'hui). Lignes non encaissées grisées avec mention « en attente ». Un
   dépli (ou dialogue) liste les dépenses de la facture avec suppression.
4. **Dépenses générales** (`CardBox`) : liste des dépenses `factureNumero == null`
   (date · libellé · catégorie · montant · supprimer).
5. **Bilan mensuel** (`CardBox` + `HScrollTable`) : colonnes *Mois · Revenu HT ·
   Dépenses · Bénéfice · Dîme (10 %)*. C'est le « bilan des activités ».

### Onglet « Dîme » (recalculé, `suivi_screen.dart`)

Remplacer la source `SampleData.dimeHistory` par `Comptabilite.bilanMensuel(...)`.
- Cartes : Bénéfice total · Dîme totale (10 %) · Déjà versé.
- Tableau : *Mois · Bénéfice · Dîme (10 %) · Statut · Date versement*, avec une
  action pour **marquer la dîme d'un mois comme versée** (renseigne la date,
  bascule `dimePaid`). Les mois sans bénéfice (perte) affichent Dîme = 0.

## Données d'exemple

`SampleData` : ajouter `initialExpenses` (3–5 dépenses réparties sur des factures
existantes et quelques générales) et marquer 1–2 factures d'exemple comme
encaissées, pour que Comptabilité et Dîme affichent des chiffres cohérents dès
l'ouverture. `dimeHistory` devient inutilisé (peut être retiré).

## Tests

Helper pur `Comptabilite` testé unitairement (`test/comptabilite_test.dart`) :
- `factureHt` = somme des lignes.
- `beneficeFacture` = HT − dépenses rattachées.
- `totaux` ne compte que les factures encaissées dans le revenu.
- `bilanMensuel` : attribution du revenu au mois d'encaissement, des dépenses à
  leur mois ; dîme = 10 % du bénéfice ; **0 sur un mois en perte**.
- `monthKeyFromDdMmYyyy` / `monthLabel` : parsing et libellé corrects.

## Hypothèses

- Revenu compté à l'**encaissement** (caisse), rattaché au **mois d'encaissement**.
- Dîme non due sur un mois déficitaire (plancher à 0).
- Base HT (hors TVA 5 %).
- Onglet « Factures & Crédits » inchangé (legacy, données d'exemple).
