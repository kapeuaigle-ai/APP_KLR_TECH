import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../core/models.dart';
import '../core/document_pagination.dart';
import '../core/signature_image.dart';
import '../core/utils.dart';
import 'klr_logo.dart';

// ─────────────────────────────────────────────────────────
//  A4 Preview — paginated automatiquement
//  • Page 1  : en-tête complet + info boxes + objet + lignes
//  • Pages N : mini en-tête (suite) + lignes
//  • Dernière page : totaux + conditions + signature + pied de page
// ─────────────────────────────────────────────────────────
class DocumentPreview extends StatelessWidget {
  final String type, numero, client, clientAddr, objet, conditions;
  final List<LineItem> lines;
  final bool tva;
  final double ht, tvaAmt, ttc;
  final AppSettings settings;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  /// Masquer la barre « Aperçu » quand l'appelant fournit déjà son en-tête.
  final bool showToolbar;

  // Taille de composition d'une page A4 (ratio 210/297). Le rendu est ensuite
  // mis à l'échelle : les capacités ci-dessous restent donc toujours valides.
  // Dimensions A4 partagées avec le PDF (adéquation parfaite aperçu ⇔ PDF).
  static const _pageW = DocumentPagination.pageW;
  static const _pageH = DocumentPagination.pageH;

  const DocumentPreview({
    super.key,
    required this.type, required this.numero, required this.settings,
    required this.client, required this.clientAddr,
    required this.objet, required this.lines, required this.tva,
    required this.ht, required this.tvaAmt, required this.ttc,
    required this.conditions,
    this.onPrint, this.onDownload, this.showToolbar = true,
  });

  // Le BL ne comporte aucun prix : ni P.U., ni montant, ni totaux.
  bool get _isBl => type == 'bl';

  String get _typeLabel {
    if (type == 'proforma') return 'FACTURE PROFORMA';
    if (type == 'facture') return 'FACTURE';
    return 'BON DE LIVRAISON';
  }

  String get _dateStr {
    const months = ['Janvier','Février','Mars','Avril','Mai','Juin',
                    'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final n = DateTime.now();
    return '${n.day} ${months[n.month - 1]} ${n.year}';
  }

  DocumentContext _pageContext() => DocumentContext(
        typeLabel: _typeLabel,
        numero: numero,
        date: _dateStr,
        deLines: [settings.company, settings.address, settings.bp],
        attentionLines: [
          if (client.isNotEmpty) client,
          if (clientAddr.isNotEmpty) clientAddr,
          if (client.isEmpty && clientAddr.isEmpty) '—',
        ],
        objet: objet,
        montantWords: 'Arrêté la présente facture à la somme de : ${NumberToWords.convert(ttc)} FRANCS CFA.',
        conditions: conditions,
        warranty: settings.warranty,
        footerLine: settings.footerLine,
        showMontant: ttc > 0 && !_isBl,
        tva: tva,
      );

  // ── Découpe les lignes en pages ───────────────────────
  // Même calcul que le PDF : voir DocumentPagination. On ignore les rangées
  // laissées vides — elles ne font pas partie du document.
  List<List<LineItem>> _paginate() => DocumentPagination.paginate(
        DocumentPagination.visible(lines),
        isBl: _isBl,
        context: _pageContext(),
      );

  // ── Widget de chaque page A4 ──────────────────────────
  Widget _buildPage({
    required List<LineItem> pageLines,
    required bool isFirst,
    required bool isLast,
    required int pageNum,
    required int totalPages,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: AspectRatio(
        aspectRatio: _pageW / _pageH,
        // La page est composée à une taille FIXE (_pageW × _pageH) — celle pour
        // laquelle les capacités de pagination ci-dessus sont calibrées — puis
        // mise à l'échelle. Sans cela, un volet plus étroit réduit la hauteur
        // disponible alors que les polices restent en pixels fixes : le
        // contenu déborde.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _pageW,
            height: _pageH,
            child: Column(children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── En-tête ─────────────────────────────
              if (isFirst) ...[
                // En-tête complet (page 1)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const KlrLogo(height: 26, markOnly: true),
                    const SizedBox(width: 8),
                    Text('KLR TECH', style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.5)),
                  ]),
                  const Spacer(),
                  Text(_typeLabel, style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.4)),
                ]),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('N°  $numero', style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                  Text('Date : $_dateStr', style: GoogleFonts.dmSans(fontSize: 9, color: AppColors.text3)),
                ])),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _InfoBox(
                    label: 'DE :',
                    lines: [settings.company, settings.address, settings.bp],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoBox(
                    label: 'À L\'ATTENTION DE :',
                    lines: [
                      if (client.isNotEmpty) client,
                      if (clientAddr.isNotEmpty) clientAddr,
                      if (client.isEmpty && clientAddr.isEmpty) '—',
                    ],
                    highlight: true,
                  )),
                ]),
                const SizedBox(height: 12),
                if (objet.isNotEmpty) ...[
                  Text('Objet : $objet', style: GoogleFonts.dmSans(
                      fontSize: 9.5, color: AppColors.text2, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                ],
              ] else ...[
                // Mini en-tête de continuation
                Row(children: [
                  const KlrLogo(height: 18, markOnly: true),
                  const SizedBox(width: 6),
                  Text('KLR TECH', style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.text1, letterSpacing: 0.5)),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Suite — $_typeLabel', style: GoogleFonts.dmSans(
                        fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.text2)),
                    Text('N°  $numero   -   Page $pageNum / $totalPages',
                        style: GoogleFonts.dmSans(fontSize: 8, color: AppColors.text3)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
              ],

              // ── Tableau des lignes ────────────────────
              _PreviewTable(
                lines: pageLines,
                tva: tva,
                ht: ht, tvaAmt: tvaAmt, ttc: ttc,
                showTotals: isLast,
                isBl: _isBl,
              ),

              // ── Totaux + montant en lettres (dernière page) ─
              if (isLast && ttc > 0 && !_isBl) ...[
                const SizedBox(height: 10),
                Text(
                  'Arrêté la présente facture à la somme de : ${NumberToWords.convert(ttc)} FRANCS CFA.',
                  style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text1, height: 1.5),
                ),
              ],

              // Spacer : épingle conditions / n° de page en bas de page,
              // identiquement au PDF.
              const Spacer(),

              // ── Numéro de page (pages intermédiaires) ─
              if (!isLast)
                Align(
                  alignment: Alignment.center,
                  child: Text('- Page $pageNum / $totalPages -',
                      style: GoogleFonts.dmSans(fontSize: 7.5, color: AppColors.text3)),
                ),

              // ── Conditions + Signature (dernière page) ─
              // IntrinsicHeight + stretch → la case Signature prend exactement la
              // hauteur de la colonne conditions. « Signature » posé sur le bord
              // supérieur (fond blanc qui masque le trait pointillé).
              if (isLast)
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Conditions de règlement :',
                          style: GoogleFonts.dmSans(fontSize: 7.5, fontWeight: FontWeight.w700, color: AppColors.text1)),
                      const SizedBox(height: 3),
                      ...conditions.split('\n').where((l) => l.trim().isNotEmpty).map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 2.4, height: 2.4,
                            margin: const EdgeInsets.only(top: 3.4, right: 4),
                            decoration: const BoxDecoration(color: AppColors.text2, shape: BoxShape.circle),
                          ),
                          Expanded(child: Text(l.trim(),
                              style: GoogleFonts.dmSans(fontSize: 7.5, color: AppColors.text2, height: 1.25))),
                        ]),
                      )),
                      const SizedBox(height: 5),
                      Text(
                        settings.warranty,
                        style: GoogleFonts.dmSans(fontSize: 6, color: AppColors.text3, height: 1.25),
                      ),
                    ])),
                    const SizedBox(width: 16),
                    // Case signature étirée sur la hauteur des conditions.
                    _signatureBox(),
                  ],
                )),
            ]),
          )),

          // ── Pied de page (toutes les pages) ──────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
            color: const Color(0xFFF8F8F8),
            child: Text(
              settings.footerLine,
              style: GoogleFonts.dmSans(fontSize: 6.5, color: AppColors.text3, letterSpacing: 0.4),
              textAlign: TextAlign.center,
            ),
          ),
            ]),
          ),
        ),
      ),
    );
  }

  // Case « Signature » de la dernière page. Vide, elle garde son cadre pointillé
  // pour une signature manuscrite ; renseignée, elle affiche l'image et la
  // légende du manager (rendu identique au PDF via la même source base64).
  Widget _signatureBox() {
    final bytes = decodeSignature(settings.signature);
    return Expanded(child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _DashedRectPainter())),
        if (bytes != null)
          Positioned.fill(child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
            child: Column(children: [
              Expanded(child: Center(child: Image.memory(bytes, fit: BoxFit.contain))),
              if (settings.signatureLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(settings.signatureLabel,
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 6.5, fontWeight: FontWeight.w600, color: AppColors.text2)),
              ],
            ]),
          )),
        Positioned(
          top: -5, left: 0, right: 0,
          child: Center(child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('Signature', style: GoogleFonts.dmSans(
                fontSize: 7.5, fontWeight: FontWeight.w600, color: AppColors.text3)),
          )),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = _paginate();
    final total = pages.length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Toolbar
      if (showToolbar) ...[
        Row(children: [
          Text('Aperçu', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text1)),
          const Spacer(),
          if (total > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
              child: Text('$total pages', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.text2, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(width: 8),
          _ToolIcon(icon: Icons.print_outlined, onTap: onPrint, tooltip: 'Imprimer'),
          const SizedBox(width: 4),
          _ToolIcon(icon: Icons.download_outlined, onTap: onDownload, tooltip: 'Télécharger PDF'),
        ]),
        const SizedBox(height: 10),
      ],

      // Pages A4 empilées
      ...pages.asMap().entries.map((e) => Padding(
        padding: EdgeInsets.only(top: e.key > 0 ? 14 : 0),
        child: _buildPage(
          pageLines: e.value,
          isFirst: e.key == 0,
          isLast: e.key == total - 1,
          pageNum: e.key + 1,
          totalPages: total,
        ),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────
//  Dashed rounded-rect painter  (PathMetrics → coins arrondis)
// ─────────────────────────────────────────────────────────
class _DashedRectPainter extends CustomPainter {
  // Valeurs fixes : la case signature est le seul usage de ce painter.
  static const Color color = AppColors.border;
  static const double dashWidth = 4;
  static const double dashSpace = 3;
  static const double borderRadius = 16;
  static const double strokeWidth = 0.8;

  const _DashedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dashWidth).clamp(0.0, m.length)), paint);
        d += dashWidth + dashSpace;
      }
    }
  }

  // Painter sans état (uniquement des constantes) : jamais besoin de repeindre.
  @override
  bool shouldRepaint(covariant _DashedRectPainter old) => false;
}

// ─────────────────────────────────────────────────────────
//  Preview sub-widgets
// ─────────────────────────────────────────────────────────
class _InfoBox extends StatelessWidget {
  final String label;
  final List<String> lines;
  final bool highlight;
  const _InfoBox({required this.label, required this.lines, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 2, color: highlight ? AppColors.primary : AppColors.text3),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w800,
                  color: highlight ? AppColors.primary : AppColors.text3, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              ...lines.asMap().entries.map((e) => Text(e.value, style: GoogleFonts.dmSans(
                fontSize: e.key == 0 ? 10 : 8.5,
                fontWeight: e.key == 0 ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.text1, height: 1.5,
              ))),
            ]),
          )),
        ],
      )),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final List<LineItem> lines;
  final bool tva;
  final double ht, tvaAmt, ttc;
  final bool showTotals;
  final bool isBl;
  const _PreviewTable({required this.lines, required this.tva, required this.ht, required this.tvaAmt, required this.ttc, required this.isBl, this.showTotals = true});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header row
      Container(
        color: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          const SizedBox(width: 28, child: _TH('Réf')),
          const SizedBox(width: 8),
          const Expanded(child: _TH('Désignation')),
          const SizedBox(width: 30, child: _TH('Qté', right: true)),
          if (!isBl) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 70, child: _TH('P.U (FCFA)', right: true)),
            const SizedBox(width: 8),
            const SizedBox(width: 65, child: _TH('Montant', right: true)),
          ],
        ]),
      ),
      // Data rows
      ...lines.asMap().entries.map((e) {
        final l = e.value;
        final even = e.key % 2 == 0;
        return Container(
          color: even ? const Color(0xFFFAFAFA) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 28, child: Text(l.ref, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2))),
            const SizedBox(width: 8),
            Expanded(child: Text(l.designation, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text1, height: 1.3))),
            SizedBox(width: 30, child: Text('${l.qte}', style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2), textAlign: TextAlign.right)),
            if (!isBl) ...[
              const SizedBox(width: 8),
              SizedBox(width: 70, child: Text(Fmt.number(l.pu), style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2), textAlign: TextAlign.right)),
              const SizedBox(width: 8),
              SizedBox(width: 65, child: Text(Fmt.number(l.total), style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.text1), textAlign: TextAlign.right)),
            ],
          ]),
        );
      }),
      // Totaux — uniquement sur la dernière page, jamais sur un BL
      if (showTotals && !isBl) ...[
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: SizedBox(width: 200, child: Column(children: [
          _PTotal(label: 'Sous-total HT', value: Fmt.number(ht)),
          if (tva) _PTotal(label: 'TVA (5%)', value: Fmt.number(tvaAmt)),
          const Divider(height: 8, color: AppColors.border),
          Row(children: [
            Text('TOTAL TTC', style: GoogleFonts.dmSans(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const Spacer(),
            Text(Fmt.number(ttc), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ]),
        ]))),
      ],
    ]);
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  const _TH(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.dmSans(
      fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
      textAlign: right ? TextAlign.right : TextAlign.left);
}

class _PTotal extends StatelessWidget {
  final String label, value;
  const _PTotal({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 8.5, color: AppColors.text2)),
      const Spacer(),
      Text(value, style: GoogleFonts.dmSans(fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.text1)),
    ]),
  );
}

class _ToolIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  const _ToolIcon({required this.icon, this.onTap, this.tooltip});
  @override
  State<_ToolIcon> createState() => _ToolIconState();
}

class _ToolIconState extends State<_ToolIcon> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null ? AppColors.bg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(widget.icon, size: 16,
              color: _hovered && widget.onTap != null ? AppColors.text1 : AppColors.text3),
        ),
      ),
    );
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}


