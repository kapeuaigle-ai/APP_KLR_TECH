import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  String _search = '';
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final type = state.docType;
    final allDocs = state.documents[type] ?? [];

    final filtered = allDocs.where((d) {
      final matchSearch = _search.isEmpty ||
          d.numero.toLowerCase().contains(_search.toLowerCase()) ||
          d.client.toLowerCase().contains(_search.toLowerCase()) ||
          d.objet.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'tous' || d.statut == _filter;
      return matchSearch && matchFilter;
    }).toList();

    final total = allDocs.fold<double>(0, (s, d) => s + d.montant);
    final validated = allDocs.where((d) => d.statut == 'validee').length;
    final pending = allDocs.where((d) => d.statut == 'cours').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Documents', style: AppTheme.h1),
                const SizedBox(height: 3),
                Text('Gérez vos proformas, factures et bons de livraison.', style: GoogleFonts.dmSans(fontSize: 13.5, color: AppColors.text3)),
              ])),
              PrimaryBtn(label: 'Nouveau document', icon: Icons.add, onTap: () => state.setCreating(true)),
            ]),
            const SizedBox(height: 24),

            // Type tabs
            _TypeTabs(current: type, onChanged: (t) { state.setDocType(t); setState(() { _filter = 'tous'; _search = ''; }); }),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              _StatPill(label: 'TOTAL', value: Fmt.money(total), color: AppColors.primary),
              const SizedBox(width: 12),
              _StatPill(label: 'VALIDÉS', value: '$validated', color: AppColors.green),
              const SizedBox(width: 12),
              _StatPill(label: 'EN COURS', value: '$pending', color: AppColors.orange),
              const Spacer(),
              SearchField(placeholder: 'Rechercher un document...', onChanged: (v) => setState(() => _search = v), maxWidth: 280),
            ]),
            const SizedBox(height: 16),

            // Filter chips
            Row(children: [
              for (final f in [('tous', 'Tous'), ('cours', 'En cours'), ('validee', 'Validé'), ('annulee', 'Annulé')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppFilterChip(label: f.$2, active: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
                ),
            ]),
            const SizedBox(height: 16),

            // Table
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(children: [
                // Table header
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(children: [
                    const Expanded(flex: 3, child: ThCell('NUMÉRO')),
                    const Expanded(flex: 2, child: ThCell('DATE')),
                    const Expanded(flex: 4, child: ThCell('CLIENT')),
                    const Expanded(flex: 4, child: ThCell('OBJET')),
                    const Expanded(flex: 3, child: ThCell('MONTANT')),
                    const Expanded(flex: 2, child: ThCell('STATUT')),
                    const SizedBox(width: 60),
                  ]),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('Aucun document trouvé', style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text3))),
                  )
                else
                  ...filtered.asMap().entries.map((e) => _DocRow(doc: e.value, isLast: e.key == filtered.length - 1)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _TypeTabs({required this.current, required this.onChanged});

  static const _tabs = [('proforma', 'Proformas'), ('facture', 'Factures'), ('bl', 'Bons de Livraison')];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 2))),
      child: Row(children: _tabs.map((t) {
        final active = t.$1 == current;
        return GestureDetector(
          onTap: () => onChanged(t.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2)),
            ),
            child: Text(t.$2, style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.primary : AppColors.text2,
            )),
          ),
        );
      }).toList()),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1, letterSpacing: -0.3)),
      ]),
    );
  }
}

class _DocRow extends StatefulWidget {
  final DocumentItem doc;
  final bool isLast;
  const _DocRow({required this.doc, required this.isLast});

  @override
  State<_DocRow> createState() => _DocRowState();
}

class _DocRowState extends State<_DocRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFFAFAFB) : AppColors.surface,
          border: widget.isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
          borderRadius: widget.isLast ? const BorderRadius.vertical(bottom: Radius.circular(12)) : null,
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(doc.numero, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.date, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.client, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.objet, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.montant > 0 ? Fmt.money(doc.montant) : '—', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StatusBadge(status: doc.statut),
          )),
          SizedBox(width: 60, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              icon: const Icon(Icons.remove_red_eye_outlined, size: 15, color: AppColors.text3),
              onPressed: () {},
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ])),
        ]),
      ),
    );
  }
}
