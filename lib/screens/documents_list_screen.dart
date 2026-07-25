import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/app_state.dart';
import '../core/pdf_generator.dart';
import '../core/utils.dart';
import '../widgets/common.dart';
import '../widgets/document_preview.dart';
import '../widgets/responsive.dart';

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
    // Seules les proformas portent un statut (en cours / validée / annulée).
    // Les factures et BL sont générés à la validation d'une proforma.
    final isProforma = type == 'proforma';
    final allDocs = state.documents[type] ?? [];

    final filtered = allDocs.where((d) {
      final matchSearch = _search.isEmpty ||
          d.numero.toLowerCase().contains(_search.toLowerCase()) ||
          d.client.toLowerCase().contains(_search.toLowerCase()) ||
          d.objet.toLowerCase().contains(_search.toLowerCase());
      final matchFilter = _filter == 'tous' || d.statut == _filter;
      return matchSearch && matchFilter;
    }).toList();

    // Compteurs par statut, affichés directement dans les filtres.
    // Un compteur à 0 n'est pas montré (inutile d'encombrer).
    final counts = {
      'tous': allDocs.length,
      'cours': allDocs.where((d) => d.statut == 'cours').length,
      'validee': allDocs.where((d) => d.statut == 'validee').length,
      'annulee': allDocs.where((d) => d.statut == 'annulee').length,
    };
    String chipLabel(String key, String label) {
      final n = counts[key] ?? 0;
      return n > 0 ? '$label ($n)' : label;
    }

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
              PrimaryBtn(label: 'Nouvelle Proforma', icon: Icons.add, onTap: () => state.setCreating(true)),
            ]),
            const SizedBox(height: 24),

            // Type tabs
            _TypeTabs(current: type, onChanged: (t) { state.setDocType(t); setState(() { _filter = 'tous'; _search = ''; }); }),
            const SizedBox(height: 20),

            // Barre de recherche. Le nombre de documents par statut est
            // désormais porté par les filtres eux-mêmes, plus par des cartes.
            Align(
              alignment: Alignment.centerLeft,
              child: SearchField(placeholder: 'Rechercher un document...', onChanged: (v) => setState(() => _search = v), maxWidth: 280),
            ),
            const SizedBox(height: 16),

            // Filter chips — seulement pour les proformas (les autres n'ont pas de statut).
            if (isProforma) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in [('tous', 'Tous'), ('cours', 'En cours'), ('validee', 'Validé'), ('annulee', 'Annulé')])
                  AppFilterChip(label: chipLabel(f.$1, f.$2), active: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
              ]),
              const SizedBox(height: 16),
            ],

            // Table
            CardBox(
              padding: EdgeInsets.zero,
              child: HScrollTable(
                minWidth: 1020,
                child: Column(children: [
                  // Table header
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(children: [
                      const Expanded(flex: 3, child: ThCell('NUMÉRO')),
                      const Expanded(flex: 3, child: ThCell('DATE')),
                      const Expanded(flex: 4, child: ThCell('CLIENT')),
                      const Expanded(flex: 4, child: ThCell('OBJET')),
                      const Expanded(flex: 3, child: ThCell('MONTANT')),
                      if (isProforma) const Expanded(flex: 2, child: ThCell('STATUT')),
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
                    ...filtered.asMap().entries.map((e) => _DocRow(doc: e.value, type: type, isLast: e.key == filtered.length - 1)),
                ]),
              ),
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

class _DocRow extends StatefulWidget {
  final DocumentItem doc;
  final String type;
  final bool isLast;
  const _DocRow({required this.doc, required this.type, required this.isLast});

  @override
  State<_DocRow> createState() => _DocRowState();
}

class _DocRowState extends State<_DocRow> {
  bool _hovered = false;

  // Totaux recalculés depuis les lignes enregistrées du document.
  // Le BL ne porte aucun montant.
  ({double ht, double tvaAmt, double ttc, bool tva}) _totals(AppSettings s) {
    if (widget.type == 'bl') return (ht: 0, tvaAmt: 0, ttc: 0, tva: false);
    final ht = widget.doc.lines.fold<double>(0, (sum, l) => sum + l.total);
    final tva = s.tva > 0;
    final tvaAmt = tva ? ht * 0.05 : 0.0;
    return (ht: ht, tvaAmt: tvaAmt, ttc: ht + tvaAmt, tva: tva);
  }

  // Régénère le PDF du document depuis ses lignes enregistrées.
  Future<List<int>> _buildPdf() {
    final s = context.read<AppState>().settings;
    final doc = widget.doc;
    final t = _totals(s);
    return PdfGenerator.generate(
      settings: s,
      type: widget.type,
      numero: doc.numero,
      date: doc.date,
      client: doc.client,
      clientAddr: doc.clientAddr,
      objet: doc.objet,
      lines: doc.lines,
      tva: t.tva,
      ht: t.ht, tvaAmt: t.tvaAmt, ttc: t.ttc,
      conditions: s.conditions,
    );
  }

  // ── Aperçu du document en pleine page ──────────────────
  void _showFullDocument() {
    final doc = widget.doc;
    final s = context.read<AppState>().settings;
    final t = _totals(s);
    const typeLabels = {'proforma': 'Facture Proforma', 'facture': 'Facture', 'bl': 'Bon de livraison'};

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // En-tête de la fenêtre
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${typeLabels[widget.type] ?? widget.type}  ·  ${doc.numero}',
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
                  const SizedBox(height: 2),
                  Text(doc.client, style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.text3)),
                ])),
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close, size: 18, color: AppColors.text2),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            // Document A4 défilant
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: doc.lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text(
                          'Ce document a été créé avant l\'enregistrement du détail\ndes lignes : son contenu ne peut pas être reconstitué.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3, height: 1.5),
                        )),
                      )
                    : DocumentPreview(
                        type: widget.type,
                        numero: doc.numero,
                        settings: s,
                        client: doc.client,
                        clientAddr: doc.clientAddr,
                        objet: doc.objet,
                        lines: doc.lines,
                        tva: t.tva,
                        ht: t.ht, tvaAmt: t.tvaAmt, ttc: t.ttc,
                        conditions: s.conditions,
                        showToolbar: false,
                      ),
              ),
            ),
            // Actions
            if (doc.lines.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton.icon(
                    onPressed: _printPdf,
                    icon: const Icon(Icons.print_outlined, size: 16, color: AppColors.text2),
                    label: Text('Imprimer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  ),
                  TextButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download_outlined, size: 16, color: AppColors.primary),
                    label: Text('Télécharger PDF', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _printPdf() async {
    try {
      await PdfGenerator.printDoc(await _buildPdf());
    } catch (e) {
      if (mounted) _pdfError(e);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final path = await PdfGenerator.saveWithDialog(
          bytes: await _buildPdf(), type: widget.type, numero: widget.doc.numero);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF enregistré :\n$path', style: const TextStyle(fontSize: 13)),
          backgroundColor: AppColors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) _pdfError(e);
    }
  }

  void _pdfError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Erreur PDF : $e', style: const TextStyle(fontSize: 13)),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showDetails(BuildContext context) {
    final doc = widget.doc;
    const typeLabels = {'proforma': 'Proforma', 'facture': 'Facture', 'bl': 'Bon de livraison'};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Expanded(child: Text(doc.numero, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary))),
          if (widget.type == 'proforma') StatusBadge(status: doc.statut),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final item in [
              ('Type', typeLabels[widget.type] ?? widget.type),
              ('Date', doc.date),
              ('Client', doc.client),
              ('Objet', doc.objet),
              ('Montant', doc.montant > 0 ? Fmt.money(doc.montant) : '—'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 90, child: Text(item.$1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text3))),
                  Expanded(child: Text(item.$2, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1))),
                ]),
              ),
            // Changement de statut : uniquement pour les proformas. Valider
            // une proforma génère la facture et le BL ; factures et BL n'ont
            // pas de statut propre.
            if (widget.type == 'proforma') ...[
              const SizedBox(height: 8),
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              Text('CHANGER LE STATUT', style: AppTheme.label),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Valider une proforma génère automatiquement la facture et le bon de livraison avec le même numéro.',
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.text3, height: 1.4),
                ),
              ),
              Row(children: [
                for (final s in [('cours', 'En cours', AppColors.orange), ('validee', 'Validée', AppColors.green), ('annulee', 'Annulée', AppColors.text2)])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        final appState = context.read<AppState>();
                        if (s.$1 == 'validee') {
                          final generated = appState.validateProforma(doc.id);
                          if (generated) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Facture et Bon de livraison ${doc.numero} générés.',
                                  style: const TextStyle(fontSize: 13)),
                              backgroundColor: AppColors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              margin: const EdgeInsets.all(16),
                            ));
                          }
                        } else {
                          appState.setDocumentStatus(widget.type, doc.id, s.$1);
                        }
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: doc.statut == s.$1 ? s.$3.withValues(alpha: 0.12) : AppColors.bg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: doc.statut == s.$1 ? s.$3 : AppColors.border),
                        ),
                        child: Text(s.$2, style: GoogleFonts.dmSans(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: doc.statut == s.$1 ? s.$3 : AppColors.text2)),
                      ),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
        actions: [
          TextButton.icon(
            onPressed: () { Navigator.of(ctx).pop(); _showFullDocument(); },
            icon: const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
            label: Text('Voir le document', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Fermer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
          ),
        ],
      ),
    );
  }

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
            child: Text(doc.numero, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.date, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2)),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.client, maxLines: 1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text1, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 4, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.objet, maxLines: 1, style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.text2), overflow: TextOverflow.ellipsis),
          )),
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(doc.montant > 0 ? Fmt.money(doc.montant) : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text1)),
          )),
          if (widget.type == 'proforma')
            Expanded(flex: 2, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StatusBadge(status: doc.statut),
            )),
          SizedBox(width: 60, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
              tooltip: 'Voir le document',
              icon: const Icon(Icons.remove_red_eye_outlined, size: 15, color: AppColors.text3),
              onPressed: () => _showDetails(context),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ])),
        ]),
      ),
    );
  }
}
