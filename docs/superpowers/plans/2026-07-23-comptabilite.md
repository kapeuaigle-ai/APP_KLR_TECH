# Comptabilité (bénéfice, dépenses, dîme) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter une section « Comptabilité » à la page Suivi qui suit dépenses et encaissements, calcule le bénéfice (base caisse, HT) et la dîme mensuelle (10 % du bénéfice), et recalcule l'onglet Dîme.

**Architecture:** Toute la logique de calcul est isolée dans un helper pur `lib/core/comptabilite.dart` (testable sans widget). `AppState` porte les données brutes (factures, dépenses, versements de dîme). L'UI (`suivi_screen.dart`) lit les dérivés via le helper. Tout est en mémoire, comme le reste de l'app.

**Tech Stack:** Flutter, Provider (`ChangeNotifier`), `google_fonts`, `intl`. Tests via `flutter_test` avec la police chargée par `test/support/test_fonts.dart` (déjà présent).

**Note commits :** les étapes « Commit » sont incluses par convention. Dans ce dépôt on ne commite que si l'utilisateur le demande — regrouper ou ignorer selon sa préférence.

**Référence (déjà dans le code) :**
- `LineItem { String ref; String designation; int qte; double pu; double get total => qte*pu; }`
- `DocumentItem { final int id; final String numero; final String date; final int clientId; final String client; final String clientAddr; final String objet; final double montant; String statut; final List<LineItem> lines; }`
- `Fmt.money(double)`, `Fmt.number(double)`, `Fmt.millions(double)` (lib/core/utils.dart)
- Widgets : `StatCard(label,value,unit?,sub?,badge?,red)`, `StatGrid(cards, minCardWidth=230, spacing=16)`, `CardBox(child, padding?)`, `AppTabBar(tabs, selected, onChanged)`, `PrimaryBtn(label, onTap, icon?)`, `ThCell(label)`, `HScrollTable(minWidth, child)`, `AppFilterChip`, `SearchField`, `StatusBadge(status, config?)`
- Couleurs `AppColors` : primary, bg, surface, border, text1/2/3, green, orange, blue, red, purple, teal, emerald, greenBg, orangeBg, redBg

---

### Task 1: Modèle `Expense` + champs d'encaissement sur `DocumentItem`

**Files:**
- Modify: `lib/core/models.dart`

- [ ] **Step 1: Ajouter les champs d'encaissement à `DocumentItem`**

Dans `class DocumentItem`, ajouter deux champs mutables et deux paramètres nommés optionnels. Remplacer la classe existante par :

```dart
// ── Document ─────────────────────────────────────────────
class DocumentItem {
  final int id;
  final String numero;
  final String date;
  final int clientId;
  final String client;
  final String clientAddr;
  final String objet;
  final double montant;
  String statut; // 'cours' | 'validee' | 'annulee'
  final List<LineItem> lines;
  // Paiement de la facture (comptabilité de caisse). Distinct du statut de
  // workflow : ici c'est l'encaissement réel.
  bool encaissee;
  String? dateEncaissement; // 'dd/MM/yyyy' quand encaissee == true

  DocumentItem({
    required this.id, required this.numero, required this.date,
    required this.clientId, required this.client, required this.objet,
    required this.montant, required this.statut,
    this.clientAddr = '', this.lines = const [],
    this.encaissee = false, this.dateEncaissement,
  });
}
```

- [ ] **Step 2: Ajouter le modèle `Expense`**

À la fin de `lib/core/models.dart` (avant `enum NavScreen`), ajouter :

```dart
// ── Dépense (comptabilité) ───────────────────────────────
class Expense {
  final int id;
  DateTime date;
  String label;
  double amount;
  String category;
  String? factureNumero; // null = dépense générale

  Expense({
    required this.id, required this.date, required this.label,
    required this.amount, required this.category, this.factureNumero,
  });

  // Catégories proposées dans l'UI.
  static const categories = [
    'Achat matériel', 'Transport', 'Sous-traitance',
    'Loyer & charges', 'Salaires', 'Autre',
  ];
}
```

- [ ] **Step 3: Vérifier la compilation**

Run: `flutter analyze --no-pub lib/core/models.dart`
Expected: aucune erreur (`error -`).

- [ ] **Step 4: Commit**

```bash
git add lib/core/models.dart
git commit -m "feat(compta): modèle Expense + encaissement sur DocumentItem"
```

---

### Task 2: Helper pur `Comptabilite` (TDD)

**Files:**
- Create: `lib/core/comptabilite.dart`
- Test: `test/comptabilite_test.dart`

- [ ] **Step 1: Écrire les tests d'abord**

Créer `test/comptabilite_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';

DocumentItem facture(String numero, List<LineItem> lines,
        {bool encaissee = false, String? dateEnc}) =>
    DocumentItem(
      id: numero.hashCode, numero: numero, date: '01/01/2026', clientId: 0,
      client: 'C', objet: 'O', montant: 0, statut: 'cours',
      lines: lines, encaissee: encaissee, dateEncaissement: dateEnc,
    );

LineItem l(int qte, double pu) => LineItem(ref: '01', designation: 'x', qte: qte, pu: pu);

Expense dep(double amount, DateTime date, {String? numero}) => Expense(
    id: date.microsecondsSinceEpoch, date: date, label: 'd',
    amount: amount, category: 'Autre', factureNumero: numero);

void main() {
  test('factureHt = somme des lignes (HT)', () {
    expect(Comptabilite.factureHt(facture('F1', [l(2, 1000), l(1, 500)])), 2500);
  });

  test('beneficeFacture = HT - dépenses rattachées', () {
    final f = facture('F1', [l(1, 1000)]);
    final ex = [dep(300, DateTime(2026, 1, 1), numero: 'F1'), dep(999, DateTime(2026, 1, 1), numero: 'F2')];
    expect(Comptabilite.beneficeFacture(f, ex), 700);
  });

  test('totaux : le revenu ne compte que les factures encaissées', () {
    final factures = [
      facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026'),
      facture('F2', [l(1, 5000)]), // non encaissée -> exclue du revenu
    ];
    final ex = [dep(200, DateTime(2026, 1, 5))];
    final t = Comptabilite.totaux(factures, ex);
    expect(t.revenuHt, 1000);
    expect(t.depenses, 200);
    expect(t.benefice, 800);
  });

  test('bilanMensuel : revenu au mois d\'encaissement, dépenses à leur mois', () {
    final factures = [
      facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026'),
      facture('F2', [l(1, 2000)], encaissee: true, dateEnc: '10/02/2026'),
    ];
    final ex = [dep(300, DateTime(2026, 1, 20)), dep(500, DateTime(2026, 2, 2))];
    final rows = Comptabilite.bilanMensuel(factures, ex, const {}, const {});
    expect(rows.length, 2);
    expect(rows[0].monthKey, '2026-01');
    expect(rows[0].revenuHt, 1000);
    expect(rows[0].depenses, 300);
    expect(rows[0].benefice, 700);
    expect(rows[0].dime, closeTo(70, 0.001));
    expect(rows[1].monthKey, '2026-02');
    expect(rows[1].dime, closeTo(150, 0.001));
  });

  test('dîme = 0 sur un mois en perte', () {
    final factures = [facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/03/2026')];
    final ex = [dep(3000, DateTime(2026, 3, 5))];
    final rows = Comptabilite.bilanMensuel(factures, ex, const {}, const {});
    expect(rows.single.benefice, -2000);
    expect(rows.single.dime, 0);
  });

  test('libellé et clé de mois', () {
    expect(Comptabilite.monthKeyFromDdMmYyyy('05/07/2026'), '2026-07');
    expect(Comptabilite.monthKeyFromDate(DateTime(2026, 7, 5)), '2026-07');
    expect(Comptabilite.monthLabel('2026-07'), 'Juillet 2026');
  });

  test('statut de versement de la dîme propagé', () {
    final factures = [facture('F1', [l(1, 1000)], encaissee: true, dateEnc: '10/01/2026')];
    final rows = Comptabilite.bilanMensuel(
        factures, const [], {'2026-01'}, {'2026-01': '03/02/2026'});
    expect(rows.single.dimePaid, isTrue);
    expect(rows.single.dimeDate, '03/02/2026');
  });
}
```

- [ ] **Step 2: Lancer les tests → doivent échouer (fichier absent)**

Run: `flutter test test/comptabilite_test.dart`
Expected: FAIL (compilation : `comptabilite.dart` introuvable).

- [ ] **Step 3: Implémenter le helper**

Créer `lib/core/comptabilite.dart` :

```dart
import 'models.dart';

/// Totaux globaux (base caisse, HT).
class ComptaTotaux {
  final double revenuHt; // factures encaissées uniquement
  final double depenses; // toutes les dépenses
  final double benefice; // revenuHt - depenses
  final double dime;     // somme des dîmes mensuelles
  const ComptaTotaux({
    required this.revenuHt, required this.depenses,
    required this.benefice, required this.dime,
  });
}

/// Une ligne du bilan mensuel.
class MonthlyRow {
  final String monthKey; // 'yyyy-MM'
  final String label;    // 'Juillet 2026'
  final double revenuHt;
  final double depenses;
  final double benefice;
  final double dime;
  final bool dimePaid;
  final String? dimeDate;
  const MonthlyRow({
    required this.monthKey, required this.label, required this.revenuHt,
    required this.depenses, required this.benefice, required this.dime,
    required this.dimePaid, required this.dimeDate,
  });
}

/// Calculs de comptabilité — fonctions pures, sans dépendance widget.
class Comptabilite {
  static const _moisFr = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  static double factureHt(DocumentItem f) =>
      f.lines.fold(0.0, (s, l) => s + l.total);

  static double depensesFacture(String numero, List<Expense> expenses) =>
      expenses.where((e) => e.factureNumero == numero).fold(0.0, (s, e) => s + e.amount);

  static double beneficeFacture(DocumentItem f, List<Expense> expenses) =>
      factureHt(f) - depensesFacture(f.numero, expenses);

  static String monthKeyFromDdMmYyyy(String date) {
    final p = date.split('/'); // dd/MM/yyyy
    return '${p[2]}-${p[1].padLeft(2, '0')}';
  }

  static String monthKeyFromDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static String monthLabel(String monthKey) {
    final p = monthKey.split('-');
    return '${_moisFr[int.parse(p[1])]} ${p[0]}';
  }

  static ComptaTotaux totaux(List<DocumentItem> factures, List<Expense> expenses) {
    final revenu = factures
        .where((f) => f.encaissee)
        .fold(0.0, (s, f) => s + factureHt(f));
    final dep = expenses.fold(0.0, (s, e) => s + e.amount);
    final dime = bilanMensuel(factures, expenses, const {}, const {})
        .fold(0.0, (s, r) => s + r.dime);
    return ComptaTotaux(
      revenuHt: revenu, depenses: dep, benefice: revenu - dep, dime: dime,
    );
  }

  static List<MonthlyRow> bilanMensuel(
    List<DocumentItem> factures,
    List<Expense> expenses,
    Set<String> dimePaidMonths,
    Map<String, String> dimePaidDates,
  ) {
    final rev = <String, double>{};
    final dep = <String, double>{};
    for (final f in factures) {
      if (f.encaissee && f.dateEncaissement != null) {
        final k = monthKeyFromDdMmYyyy(f.dateEncaissement!);
        rev[k] = (rev[k] ?? 0) + factureHt(f);
      }
    }
    for (final e in expenses) {
      final k = monthKeyFromDate(e.date);
      dep[k] = (dep[k] ?? 0) + e.amount;
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
}
```

- [ ] **Step 4: Lancer les tests → doivent passer**

Run: `flutter test test/comptabilite_test.dart`
Expected: All tests passed! (8 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/comptabilite.dart test/comptabilite_test.dart
git commit -m "feat(compta): helper de calcul pur + tests"
```

---

### Task 3: État `AppState` + données d'exemple

**Files:**
- Modify: `lib/core/app_state.dart`
- Modify: `lib/core/data.dart`

- [ ] **Step 1: Données d'exemple — dépenses + factures encaissées**

Dans `lib/core/data.dart`, marquer deux factures d'exemple comme encaissées : dans la map `documents`, section `'facture'`, ajouter aux deux `DocumentItem` les paramètres `encaissee: true`. Remplacer les deux lignes par :

```dart
    'facture': [
      DocumentItem(id: 1, numero: 'KLR-04-240426', date: '24/04/2026', clientId: 7, client: "Advans Côte d'Ivoire", clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Équipements Réseau', montant: 3927000, statut: 'cours', lines: _linesEquipements(), encaissee: true, dateEncaissement: '30/04/2026'),
      DocumentItem(id: 2, numero: 'KLR-02-100126', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 1575000, statut: 'validee', lines: _linesDeveloppement(), encaissee: true, dateEncaissement: '15/01/2026'),
    ],
```

Puis, juste avant `static final List<DimeEntry> dimeHistory = [` (qui devient inutilisé mais peut rester), ajouter :

```dart
  static List<Expense> get initialExpenses => [
    Expense(id: 1, date: DateTime(2026, 1, 12), label: 'Licences de développement', amount: 250000, category: 'Achat matériel', factureNumero: 'KLR-02-100126'),
    Expense(id: 2, date: DateTime(2026, 1, 20), label: 'Sous-traitance intégration', amount: 180000, category: 'Sous-traitance', factureNumero: 'KLR-02-100126'),
    Expense(id: 3, date: DateTime(2026, 4, 26), label: 'Achat switches et bornes Wi-Fi', amount: 1650000, category: 'Achat matériel', factureNumero: 'KLR-04-240426'),
    Expense(id: 4, date: DateTime(2026, 4, 10), label: 'Loyer atelier — avril', amount: 150000, category: 'Loyer & charges'),
    Expense(id: 5, date: DateTime(2026, 1, 5), label: 'Transport livraisons', amount: 60000, category: 'Transport'),
  ];
```

- [ ] **Step 2: `AppState` — champs et initialisation**

Dans `lib/core/app_state.dart`, ajouter le champ après `late List<FactureEntry> factures;` :

```dart
  late List<Expense> expenses;
  final Set<String> _dimePaidMonths = {};
  final Map<String, String> _dimePaidDates = {};
```

Dans le constructeur `AppState()`, après `factures = List.from(SampleData.factureHistory);`, ajouter :

```dart
    expenses = List.from(SampleData.initialExpenses);
```

Ajouter les getters (près des autres getters, ex. après `bool get creating => _creating;`) :

```dart
  Set<String> get dimePaidMonths => _dimePaidMonths;
  Map<String, String> get dimePaidDates => _dimePaidDates;
  List<DocumentItem> get factures2 => documents['facture'] ?? [];
```

- [ ] **Step 3: `AppState` — méthodes**

Ajouter, à la fin de la classe `AppState` (avant l'accolade fermante) :

```dart
  // ── Comptabilité : dépenses ────────────────────────────
  void addExpense(Expense e) {
    expenses.add(e);
    notifyListeners();
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ── Comptabilité : encaissement des factures ───────────
  void setFactureEncaissee(int id, bool encaissee, {String? date}) {
    final f = documents['facture']?.where((d) => d.id == id);
    if (f != null && f.isNotEmpty) {
      f.first.encaissee = encaissee;
      f.first.dateEncaissement = encaissee ? date : null;
      notifyListeners();
    }
  }

  // ── Comptabilité : versement de la dîme ────────────────
  void setDimePaid(String monthKey, bool paid, {String? date}) {
    if (paid) {
      _dimePaidMonths.add(monthKey);
      if (date != null) _dimePaidDates[monthKey] = date;
    } else {
      _dimePaidMonths.remove(monthKey);
      _dimePaidDates.remove(monthKey);
    }
    notifyListeners();
  }
```

- [ ] **Step 4: Vérifier la compilation**

Run: `flutter analyze --no-pub lib/core/app_state.dart lib/core/data.dart`
Expected: aucune erreur (`error -`). (Avertissements `withOpacity` préexistants ignorés.)

- [ ] **Step 5: Commit**

```bash
git add lib/core/app_state.dart lib/core/data.dart
git commit -m "feat(compta): dépenses, encaissement et versement dîme dans AppState"
```

---

### Task 4: Onglet « Comptabilité » dans la page Suivi

**Files:**
- Modify: `lib/screens/suivi_screen.dart`
- Test: `test/suivi_compta_test.dart`

- [ ] **Step 1: Importer le helper**

En haut de `lib/screens/suivi_screen.dart`, ajouter après `import '../core/app_state.dart';` :

```dart
import '../core/comptabilite.dart';
```

- [ ] **Step 2: Ajouter l'onglet dans la barre et le switch**

Dans `_SuiviScreenState.build`, remplacer le bloc `AppTabBar(...)` + le `if/else` des onglets par :

```dart
            AppTabBar(
              tabs: const ['Factures & Crédits', 'Comptabilité', 'Dîme', 'Tâches', 'Notes'],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 20),
            if (_tab == 0) const _FacturesTab()
            else if (_tab == 1) const _ComptaTab()
            else if (_tab == 2) const _DimeTab()
            else if (_tab == 3) const _TachesTab()
            else const _NotesTab(),
```

- [ ] **Step 3: Ajouter le widget `_ComptaTab`**

Juste après la classe `_FacturesTab` (avant `// ── Dîme Tab ──`), insérer le code complet ci-dessous :

```dart
// ── Comptabilité Tab ──────────────────────────────────────
class _ComptaTab extends StatefulWidget {
  const _ComptaTab();
  @override
  State<_ComptaTab> createState() => _ComptaTabState();
}

class _ComptaTabState extends State<_ComptaTab> {
  final _labelCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _categorie = Expense.categories.first;
  String? _factureNumero; // null = générale

  @override
  void dispose() {
    _labelCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  void _addExpense(AppState state) {
    final montant = double.tryParse(_montantCtrl.text.replaceAll(' ', '')) ?? 0;
    if (_labelCtrl.text.trim().isEmpty || montant <= 0) return;
    state.addExpense(Expense(
      id: DateTime.now().millisecondsSinceEpoch,
      date: _date,
      label: _labelCtrl.text.trim(),
      amount: montant,
      category: _categorie,
      factureNumero: _factureNumero,
    ));
    _labelCtrl.clear();
    _montantCtrl.clear();
    setState(() => _date = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final factures = state.documents['facture'] ?? [];
    final expenses = state.expenses;
    final t = Comptabilite.totaux(factures, expenses);
    final rows = Comptabilite.bilanMensuel(factures, expenses, state.dimePaidMonths, state.dimePaidDates);
    final generales = expenses.where((e) => e.factureNumero == null).toList();

    return Column(children: [
      // Synthèse
      StatGrid(cards: [
        StatCard(label: 'REVENU HT ENCAISSÉ', value: Fmt.millions(t.revenuHt), unit: 'FCFA'),
        StatCard(label: 'DÉPENSES', value: Fmt.millions(t.depenses), unit: 'FCFA'),
        StatCard(label: 'BÉNÉFICE', value: Fmt.millions(t.benefice), unit: 'FCFA', red: t.benefice < 0),
        StatCard(label: 'DÎME (10%)', value: Fmt.millions(t.dime), unit: 'FCFA'),
      ]),
      const SizedBox(height: 20),

      // Ajouter une dépense
      CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ajouter une dépense', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          _field('LIBELLÉ', SizedBox(width: 240, child: _tf(_labelCtrl, 'Ex : Achat matériel'))),
          _field('MONTANT (FCFA)', SizedBox(width: 140, child: _tf(_montantCtrl, '0', numeric: true))),
          _field('DATE', GestureDetector(
            onTap: () async {
              final d = await _pickDate(_date);
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              width: 130, height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Text(_fmtDate(_date), style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
            ),
          )),
          _field('RATTACHEMENT', _factureDropdown(factures)),
        ]),
        const SizedBox(height: 12),
        Text('CATÉGORIE', style: AppTheme.label),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: Expense.categories.map((c) => GestureDetector(
          onTap: () => setState(() => _categorie = c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _categorie == c ? AppColors.primary : AppColors.bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _categorie == c ? AppColors.primary : AppColors.border),
            ),
            child: Text(c, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _categorie == c ? Colors.white : AppColors.text2)),
          ),
        )).toList()),
        const SizedBox(height: 16),
        PrimaryBtn(label: 'Ajouter la dépense', icon: Icons.add, onTap: () => _addExpense(state)),
      ])),
      const SizedBox(height: 20),

      // Bénéfice par facture
      CardBox(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text('Bénéfice par facture', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1))),
        HScrollTable(minWidth: 820, child: Column(children: [
          Container(color: AppColors.bg, child: const Row(children: [
            Expanded(flex: 3, child: ThCell('N° FACTURE')),
            Expanded(flex: 4, child: ThCell('CLIENT')),
            Expanded(flex: 3, child: ThCell('HT')),
            Expanded(flex: 3, child: ThCell('DÉPENSES')),
            Expanded(flex: 3, child: ThCell('BÉNÉFICE')),
            Expanded(flex: 3, child: ThCell('ENCAISSÉE')),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (factures.isEmpty)
            Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Aucune facture', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))))
          else
            ...factures.map((f) => _factureRow(state, f, expenses)),
        ])),
      ])),
      const SizedBox(height: 20),

      // Dépenses générales
      CardBox(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text('Dépenses générales', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1))),
        HScrollTable(minWidth: 720, child: Column(children: [
          Container(color: AppColors.bg, child: const Row(children: [
            Expanded(flex: 2, child: ThCell('DATE')),
            Expanded(flex: 4, child: ThCell('LIBELLÉ')),
            Expanded(flex: 3, child: ThCell('CATÉGORIE')),
            Expanded(flex: 3, child: ThCell('MONTANT')),
            SizedBox(width: 48),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (generales.isEmpty)
            Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Aucune dépense générale', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))))
          else
            ...generales.map((e) => _expenseRow(state, e)),
        ])),
      ])),
      const SizedBox(height: 20),

      // Bilan mensuel
      CardBox(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Text('Bilan mensuel', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1))),
        HScrollTable(minWidth: 720, child: Column(children: [
          Container(color: AppColors.bg, child: const Row(children: [
            Expanded(flex: 3, child: ThCell('MOIS')),
            Expanded(flex: 3, child: ThCell('REVENU HT')),
            Expanded(flex: 3, child: ThCell('DÉPENSES')),
            Expanded(flex: 3, child: ThCell('BÉNÉFICE')),
            Expanded(flex: 3, child: ThCell('DÎME (10%)')),
          ])),
          const Divider(height: 1, color: AppColors.border),
          if (rows.isEmpty)
            Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Aucune activité', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))))
          else
            ...rows.map((r) => Row(children: [
              _cell(r.label, flex: 3, bold: true),
              _cell(Fmt.money(r.revenuHt), flex: 3),
              _cell(Fmt.money(r.depenses), flex: 3),
              _cell(Fmt.money(r.benefice), flex: 3, color: r.benefice < 0 ? AppColors.red : AppColors.text1),
              _cell(Fmt.money(r.dime), flex: 3, color: AppColors.primary, bold: true),
            ])),
        ])),
      ])),
    ]);
  }

  // Ligne facture avec bascule d'encaissement.
  Widget _factureRow(AppState state, DocumentItem f, List<Expense> expenses) {
    final ht = Comptabilite.factureHt(f);
    final dep = Comptabilite.depensesFacture(f.numero, expenses);
    final benef = ht - dep;
    return Container(
      decoration: BoxDecoration(
        color: f.encaissee ? Colors.white : const Color(0xFFFAFAFB),
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _cell(f.numero, flex: 3, color: AppColors.primary, bold: true),
        _cell(f.client, flex: 4),
        _cell(Fmt.money(ht), flex: 3),
        _cell(Fmt.money(dep), flex: 3),
        _cell(Fmt.money(benef), flex: 3, bold: true, color: benef < 0 ? AppColors.red : AppColors.text1),
        Expanded(flex: 3, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Switch(
              value: f.encaissee,
              activeColor: AppColors.green,
              onChanged: (v) async {
                if (v) {
                  final d = await _pickDate(DateTime.now());
                  if (d != null) state.setFactureEncaissee(f.id, true, date: _fmtDate(d));
                } else {
                  state.setFactureEncaissee(f.id, false);
                }
              },
            ),
            Expanded(child: Text(
              f.encaissee ? (f.dateEncaissement ?? '') : 'en attente',
              style: GoogleFonts.dmSans(fontSize: 11.5, color: f.encaissee ? AppColors.green : AppColors.text3),
              overflow: TextOverflow.ellipsis,
            )),
          ]),
        )),
      ]),
    );
  }

  Widget _expenseRow(AppState state, Expense e) => Container(
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      _cell(_fmtDate(e.date), flex: 2),
      _cell(e.label, flex: 4),
      _cell(e.category, flex: 3, color: AppColors.text2),
      _cell(Fmt.money(e.amount), flex: 3, bold: true),
      SizedBox(width: 48, child: IconButton(
        icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.red),
        onPressed: () => state.deleteExpense(e.id),
      )),
    ]),
  );

  Widget _factureDropdown(List<DocumentItem> factures) => Container(
    width: 200, height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
      value: _factureNumero,
      isExpanded: true,
      hint: Text('Générale', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text('Générale', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2))),
        ...factures.map((f) => DropdownMenuItem<String?>(value: f.numero, child: Text(f.numero, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) => setState(() => _factureNumero = v),
    )),
  );

  Widget _field(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: AppTheme.label),
    const SizedBox(height: 6),
    child,
  ]);

  Widget _tf(TextEditingController c, String hint, {bool numeric = false}) => SizedBox(
    height: 40,
    child: TextField(
      controller: c,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
        filled: true, fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    ),
  );

  Widget _cell(String text, {int flex = 1, Color color = AppColors.text1, bool bold = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    ),
  );
}
```

- [ ] **Step 4: Test de rendu (smoke test)**

Créer `test/suivi_compta_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/suivi_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('l\'onglet Comptabilité s\'affiche sans erreur', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));

    // Aller sur l'onglet Comptabilité.
    await tester.tap(find.text('Comptabilité'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ajouter une dépense'), findsOneWidget);
    expect(find.text('Bénéfice par facture'), findsOneWidget);
    expect(find.text('Bilan mensuel'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Lancer le test**

Run: `flutter test test/suivi_compta_test.dart`
Expected: All tests passed!

- [ ] **Step 6: Commit**

```bash
git add lib/screens/suivi_screen.dart test/suivi_compta_test.dart
git commit -m "feat(compta): onglet Comptabilité (synthèse, dépenses, bénéfice, bilan)"
```

---

### Task 5: Onglet « Dîme » recalculé + versements

**Files:**
- Modify: `lib/screens/suivi_screen.dart`
- Test: `test/suivi_compta_test.dart` (ajout)

- [ ] **Step 1: Réécrire `_DimeTab`**

Remplacer entièrement la classe `_DimeTab` (le widget `StatelessWidget` qui lit `SampleData.dimeHistory`) par :

```dart
// ── Dîme Tab (recalculée sur le bénéfice mensuel) ─────────
class _DimeTab extends StatelessWidget {
  const _DimeTab();

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final factures = state.documents['facture'] ?? [];
    final rows = Comptabilite.bilanMensuel(factures, state.expenses, state.dimePaidMonths, state.dimePaidDates);
    final totalBenef = rows.fold<double>(0, (s, r) => s + (r.benefice > 0 ? r.benefice : 0));
    final totalDime = rows.fold<double>(0, (s, r) => s + r.dime);
    final totalPaye = rows.where((r) => r.dimePaid).fold<double>(0, (s, r) => s + r.dime);

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'BÉNÉFICE (MOIS +)', value: Fmt.millions(totalBenef), unit: 'FCFA'),
        StatCard(label: 'DÎME TOTALE (10%)', value: Fmt.millions(totalDime), unit: 'FCFA', red: true),
        StatCard(label: 'DÉJÀ VERSÉ', value: Fmt.millions(totalPaye), unit: 'FCFA'),
      ]),
      const SizedBox(height: 20),
      CardBox(padding: EdgeInsets.zero, child: HScrollTable(minWidth: 880, child: Column(children: [
        Container(color: AppColors.bg, child: const Row(children: [
          Expanded(flex: 3, child: ThCell('MOIS')),
          Expanded(flex: 3, child: ThCell('BÉNÉFICE')),
          Expanded(flex: 3, child: ThCell('DÎME (10%)')),
          Expanded(flex: 2, child: ThCell('STATUT')),
          Expanded(flex: 3, child: ThCell('DATE VERSEMENT')),
          SizedBox(width: 56),
        ])),
        const Divider(height: 1, color: AppColors.border),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(30), child: Center(child: Text('Aucune activité', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))))
        else
          ...rows.map((r) => Container(
            decoration: BoxDecoration(
              color: (!r.dimePaid && r.dime > 0) ? const Color(0xFFFFFBEB) : Colors.white,
              border: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              _dcell(r.label, flex: 3, bold: true),
              _dcell(Fmt.money(r.benefice), flex: 3, color: r.benefice < 0 ? AppColors.red : AppColors.text1),
              _dcell(Fmt.money(r.dime), flex: 3, color: AppColors.primary, bold: true),
              Expanded(flex: 2, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: StatusBadge(status: r.dimePaid ? 'paye' : 'attente'),
              )),
              _dcell(r.dimeDate ?? '—', flex: 3, color: AppColors.text2),
              SizedBox(width: 56, child: (r.dime > 0 && !r.dimePaid)
                ? IconButton(
                    tooltip: 'Marquer versée',
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
                    onPressed: () => state.setDimePaid(r.monthKey, true, date: _fmtDate(DateTime.now())),
                  )
                : (r.dimePaid
                    ? IconButton(
                        tooltip: 'Annuler le versement',
                        icon: const Icon(Icons.undo, size: 16, color: AppColors.text3),
                        onPressed: () => state.setDimePaid(r.monthKey, false),
                      )
                    : const SizedBox())),
            ]),
          )),
      ]))),
    ]);
  }

  Widget _dcell(String text, {int flex = 1, Color color = AppColors.text1, bool bold = false}) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color)),
    ),
  );
}
```

- [ ] **Step 2: Nettoyer les imports inutilisés**

Si `import '../core/data.dart';` n'est plus utilisé dans `suivi_screen.dart` après cette réécriture (l'onglet Dîme n'utilise plus `SampleData.dimeHistory`), le retirer. Vérifier avec l'analyse à l'étape suivante (avertissement `unused_import`).

Run: `flutter analyze --no-pub lib/screens/suivi_screen.dart`
Expected: aucune erreur ; retirer tout import signalé `unused_import`.

- [ ] **Step 3: Ajouter un test de l'onglet Dîme**

Ajouter dans `test/suivi_compta_test.dart`, dans `main()` après le premier `testWidgets` :

```dart
  testWidgets('l\'onglet Dîme recalculé s\'affiche et marque un versement', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(home: Scaffold(body: SuiviScreen())),
    ));
    await tester.tap(find.text('Dîme'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('DÎME TOTALE (10%)'), findsOneWidget);
    // Au moins une dîme mensuelle à verser (données d'exemple).
    expect(find.byTooltip('Marquer versée'), findsWidgets);
  });
```

- [ ] **Step 4: Lancer les tests du fichier**

Run: `flutter test test/suivi_compta_test.dart`
Expected: All tests passed! (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/suivi_screen.dart test/suivi_compta_test.dart
git commit -m "feat(compta): onglet Dîme recalculé sur le bénéfice mensuel + versements"
```

---

### Task 6: Vérification d'ensemble et lancement

**Files:** aucun (vérification)

- [ ] **Step 1: Analyse statique globale**

Run: `flutter analyze --no-pub lib/core/comptabilite.dart lib/core/models.dart lib/core/app_state.dart lib/core/data.dart lib/screens/suivi_screen.dart`
Expected: aucune ligne ` error `. (Les avertissements `withOpacity`/`deprecated_member_use` préexistants sont tolérés.)

- [ ] **Step 2: Suite de tests complète**

Run: `flutter test`
Expected: All tests passed! (254 existants + comptabilité + suivi = tout au vert).

- [ ] **Step 3: Lancer l'app native et vérifier visuellement**

Arrêter l'instance en cours puis :

```bash
# PowerShell
Stop-Process -Name klr_tech_app -Force -ErrorAction SilentlyContinue
flutter run -d windows --release
```

Vérifier dans l'app : Suivi → onglet **Comptabilité** (cartes de synthèse cohérentes, ajout d'une dépense, bascule *Encaissée* sur une facture ouvre le sélecteur de date et met à jour les totaux, bilan mensuel) ; onglet **Dîme** (dîme = 10 % du bénéfice mensuel, bouton « Marquer versée »).

- [ ] **Step 4: Commit final (optionnel, selon préférence utilisateur)**

```bash
git add -A
git commit -m "feat(compta): section Comptabilité complète dans Suivi"
```

---

## Self-Review (effectuée)

**Couverture de la spec :**
- Modèle `Expense` + encaissement `DocumentItem` → Task 1. ✓
- Helper de calcul pur + tests → Task 2. ✓
- `AppState` (dépenses, encaissement, versement dîme) + données d'exemple → Task 3. ✓
- Onglet Comptabilité (synthèse, ajout dépense, bénéfice par facture avec bascule Encaissée, dépenses générales, bilan mensuel) → Task 4. ✓
- Onglet Dîme recalculé + versements → Task 5. ✓
- Base HT, base caisse (encaissé), attribution au mois d'encaissement, dîme plancher 0, mensuelle → Task 2 (logique) + tests. ✓
- Onglet « Factures & Crédits » inchangé → non modifié. ✓

**Cohérence des types/noms :** `Expense`, `DocumentItem.encaissee/dateEncaissement`, `Comptabilite.factureHt/depensesFacture/beneficeFacture/totaux/bilanMensuel/monthKeyFromDdMmYyyy/monthKeyFromDate/monthLabel`, `ComptaTotaux{revenuHt,depenses,benefice,dime}`, `MonthlyRow{monthKey,label,revenuHt,depenses,benefice,dime,dimePaid,dimeDate}`, `AppState.expenses/dimePaidMonths/dimePaidDates/addExpense/deleteExpense/setFactureEncaissee/setDimePaid` — cohérents entre toutes les tâches.

**Placeholders :** aucun ; tout le code est fourni.
