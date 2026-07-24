import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/comptabilite.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suivi', style: AppTheme.h1),
            const SizedBox(height: 3),
            Text('Factures, dîme, tâches et notes internes.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
            const SizedBox(height: 24),
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
          ],
        ),
      ),
    );
  }
}

// ── Factures Tab ──────────────────────────────────────────
class _FacturesTab extends StatelessWidget {
  const _FacturesTab();

  @override
  Widget build(BuildContext context) {
    final factures = context.watch<AppState>().factures;
    final totalPaye = factures.where((f) => f.statut == 'paye').fold<double>(0, (s, f) => s + f.montant);
    final totalAttente = factures.where((f) => f.statut == 'cours').fold<double>(0, (s, f) => s + f.montant);
    final totalRetard = factures.where((f) => f.statut == 'retard').fold<double>(0, (s, f) => s + f.montant);

    return Column(children: [
      StatGrid(cards: [
        StatCard(label: 'ENCAISSÉ', value: Fmt.millions(totalPaye), unit: 'FCFA',
          badge: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.greenBg, borderRadius: BorderRadius.circular(20)),
            child: Text('Payé', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)))),
        StatCard(label: 'EN ATTENTE', value: Fmt.millions(totalAttente), unit: 'FCFA'),
        StatCard(label: 'EN RETARD', value: Fmt.millions(totalRetard), unit: 'FCFA', red: true),
      ]),
      const SizedBox(height: 20),

      CardBox(
        padding: EdgeInsets.zero,
        child: HScrollTable(
          minWidth: 940,
          child: Column(children: [
            Container(
              color: AppColors.bg,
              child: const Row(children: [
                Expanded(flex: 3, child: ThCell('N° FACTURE')),
                Expanded(flex: 4, child: ThCell('CLIENT')),
                Expanded(flex: 3, child: ThCell('MONTANT')),
                Expanded(flex: 2, child: ThCell('STATUT')),
                Expanded(flex: 3, child: ThCell('ÉCHÉANCE')),
                SizedBox(width: 60),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            ...factures.asMap().entries.map((e) {
              final f = e.value;
              final isLast = e.key == factures.length - 1;
              return Container(
                decoration: BoxDecoration(
                  border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  Expanded(flex: 3, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Text(f.num, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  )),
                  Expanded(flex: 4, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(f.client, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                  )),
                  Expanded(flex: 3, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(Fmt.money(f.montant), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
                  )),
                  Expanded(flex: 2, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: StatusBadge(status: f.statut),
                  )),
                  Expanded(flex: 3, child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(f.echeance, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, color: f.statut == 'retard' ? AppColors.red : AppColors.text2)),
                  )),
                  SizedBox(width: 60, child: PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.text3),
                    padding: const EdgeInsets.all(6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: Colors.white,
                    onSelected: (action) {
                      if (action == 'paid') {
                        context.read<AppState>().markFacturePaid(f.num);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Facture ${f.num} marquée comme payée.', style: const TextStyle(fontSize: 13)),
                          backgroundColor: AppColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          margin: const EdgeInsets.all(16),
                        ));
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (f.statut != 'paye')
                        PopupMenuItem(value: 'paid', child: Row(children: [
                          const Icon(Icons.check_circle_outline, size: 15, color: AppColors.green),
                          const SizedBox(width: 8),
                          Text('Marquer payée', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1)),
                        ]))
                      else
                        PopupMenuItem(enabled: false, child: Row(children: [
                          const Icon(Icons.check_circle, size: 15, color: AppColors.green),
                          const SizedBox(width: 8),
                          Text('Déjà payée', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3)),
                        ])),
                    ],
                  )),
                ]),
              );
            }),
          ]),
        ),
      ),
    ]);
  }
}

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

// ── Tâches Tab ────────────────────────────────────────────
class _TachesTab extends StatefulWidget {
  const _TachesTab();

  @override
  State<_TachesTab> createState() => _TachesTabState();
}

class _TachesTabState extends State<_TachesTab> {
  final _ctrl = TextEditingController();
  final _titreCtrl = TextEditingController();
  String _priorite = 'normale';

  static const _priorites = ['haute', 'normale', 'basse'];
  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};
  static const _priorityLabels = {'haute': 'Haute', 'normale': 'Normale', 'basse': 'Basse'};

  @override
  void dispose() {
    _ctrl.dispose();
    _titreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tasks = state.tasks;
    final done = tasks.where((t) => t.done).length;

    return ResponsiveSplit(
      sideWidth: 300,
      breakpoint: 760,
      main: Column(children: [
        CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Tâches en cours', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
            const Spacer(),
            Text('$done/${tasks.length} terminées', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
          ]),
          const SizedBox(height: 6),
          ProgressBar(value: tasks.isEmpty ? 0 : (done / tasks.length * 100).round(), color: AppColors.primary, height: 6),
          const SizedBox(height: 16),
          ...tasks.map((t) => _TaskItem(task: t)),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Aucune tâche', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
            ),
        ])),
      ]),

      // Add task form
      side: CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nouvelle tâche', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Description de la tâche...',
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        Text('TITRE', style: AppTheme.label),
        const SizedBox(height: 6),
        TextField(
          controller: _titreCtrl,
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1),
          decoration: InputDecoration(
            hintText: 'Ex : Facturation, Relance client...',
            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
            filled: true, fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Text('PRIORITÉ', style: AppTheme.label),
        const SizedBox(height: 6),
        Row(children: _priorites.map((p) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _priorite = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _priorite == p ? _priorityColors[p]!.withOpacity(0.12) : AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _priorite == p ? _priorityColors[p]! : AppColors.border),
              ),
              child: Text(_priorityLabels[p]!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _priorite == p ? _priorityColors[p]! : AppColors.text2)),
            ),
          ),
        )).toList()),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: PrimaryBtn(
          label: 'Ajouter la tâche',
          onTap: () {
            if (_ctrl.text.trim().isNotEmpty) {
              context.read<AppState>().addTask(Task(
                id: DateTime.now().millisecondsSinceEpoch,
                texte: _ctrl.text.trim(),
                titre: _titreCtrl.text.trim(),
                priorite: _priorite,
              ));
              _ctrl.clear();
              _titreCtrl.clear();
            }
          },
        )),
      ])),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  const _TaskItem({required this.task});

  static const _priorityColors = {'haute': AppColors.red, 'normale': AppColors.blue, 'basse': AppColors.text3};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.read<AppState>().toggleTask(task.id),
          child: Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: task.done ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: task.done ? AppColors.green : AppColors.border, width: 1.5),
            ),
            child: task.done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.texte, style: GoogleFonts.dmSans(
            fontSize: 13.5, fontWeight: FontWeight.w500,
            color: task.done ? AppColors.text3 : AppColors.text1,
            decoration: task.done ? TextDecoration.lineThrough : null,
          )),
          if (task.titre.isNotEmpty)
            Text(task.titre, style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3)),
        ])),
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: _priorityColors[task.priorite] ?? AppColors.text3, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => context.read<AppState>().deleteTask(task.id),
          child: const Icon(Icons.close, size: 14, color: AppColors.text3),
        ),
      ]),
    );
  }
}

// ── Notes Tab ─────────────────────────────────────────────
class _NotesTab extends StatefulWidget {
  const _NotesTab();

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  Note? _editing;

  // Suppression directe depuis la carte, avec confirmation simple
  void _confirmDeleteNote(Note n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Supprimer cette note ?', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
        content: Text(
          '« ${n.titre.isEmpty ? 'Sans titre' : n.titre} » sera supprimée définitivement.',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () {
              context.read<AppState>().deleteNote(n.id);
              if (_editing?.id == n.id) setState(() => _editing = null);
              Navigator.of(ctx).pop();
            },
            child: Text('Supprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<AppState>().notes;
    // Notes grid using Wrap — avoids Expanded constraint issues
    final grid = Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        ...notes.map((n) => SizedBox(
          width: 240,
          height: 180,
          child: _NoteCard(
            note: n,
            onTap: () => setState(() => _editing = n),
            onDelete: () => _confirmDeleteNote(n),
          ),
        )),
        SizedBox(
          width: 240,
          height: 180,
          child: _AddNoteCard(onTap: () => setState(() => _editing = Note(
            id: DateTime.now().millisecondsSinceEpoch,
            titre: '', contenu: '', color: AppColors.blue, date: "Aujourd'hui",
          ))),
        ),
      ],
    );
    if (_editing == null) return grid;
    return ResponsiveSplit(
      sideWidth: 300,
      breakpoint: 760,
      main: grid,
      side: _NoteEditor(
        note: _editing!,
        onSave: (n) {
          context.read<AppState>().saveNote(n);
          setState(() => _editing = null);
        },
        onDelete: () {
          context.read<AppState>().deleteNote(_editing!.id);
          setState(() => _editing = null);
        },
        onClose: () => setState(() => _editing = null),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onTap, required this.onDelete});

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? [BoxShadow(color: n.color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Bandeau d'accent coloré en haut de la carte
            Container(height: 3, color: n.color),
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(n.titre.isEmpty ? 'Sans titre' : n.titre, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // Bouton de suppression directe, toujours visible
                  Tooltip(
                    message: 'Supprimer la note',
                    child: InkWell(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline, size: 16, color: AppColors.red),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                // Expanded : le contenu occupe tout l'espace disponible
                // et la date reste collée en bas de la carte
                Expanded(child: Text(n.contenu, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text2, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 8),
                Text(n.date, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text3)),
              ]),
            )),
          ]),
        ),
      ),
    );
  }
}

class _AddNoteCard extends StatefulWidget {
  final VoidCallback onTap;
  const _AddNoteCard({required this.onTap});

  @override
  State<_AddNoteCard> createState() => _AddNoteCardState();
}

class _AddNoteCardState extends State<_AddNoteCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline, size: 28, color: _hovered ? AppColors.primary : AppColors.text3),
            const SizedBox(height: 8),
            Text('Nouvelle note', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: _hovered ? AppColors.primary : AppColors.text3)),
          ]),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final Note note;
  final ValueChanged<Note> onSave;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  const _NoteEditor({required this.note, required this.onSave, required this.onDelete, required this.onClose});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late TextEditingController _titreCtrl;
  late TextEditingController _contenuCtrl;
  late Color _color;

  static const _colors = [AppColors.blue, AppColors.orange, AppColors.emerald, AppColors.purple, AppColors.red];

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController(text: widget.note.titre);
    _contenuCtrl = TextEditingController(text: widget.note.contenu);
    _color = widget.note.color;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _contenuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CardBox(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Éditer la note', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text1)),
        const Spacer(),
        GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, size: 16, color: AppColors.text3)),
      ]),
      const SizedBox(height: 14),
      TextField(
        controller: _titreCtrl,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1),
        decoration: InputDecoration(
          hintText: 'Titre de la note',
          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const Divider(color: AppColors.border),
      const SizedBox(height: 8),
      TextField(
        controller: _contenuCtrl,
        maxLines: 8,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Contenu de la note...',
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3),
          border: InputBorder.none,
        ),
      ),
      const SizedBox(height: 12),
      Text('COULEUR', style: AppTheme.label),
      const SizedBox(height: 8),
      Row(children: _colors.map((c) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _color = c),
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(color: _color == c ? AppColors.text1 : Colors.transparent, width: 2),
            ),
          ),
        ),
      )).toList()),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: PrimaryBtn(label: 'Enregistrer', onTap: () {
          final updated = widget.note
            ..titre = _titreCtrl.text
            ..contenu = _contenuCtrl.text
            ..color = _color;
          widget.onSave(updated);
        })),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
          onPressed: widget.onDelete,
          padding: const EdgeInsets.all(8),
        ),
      ]),
    ]));
  }
}
