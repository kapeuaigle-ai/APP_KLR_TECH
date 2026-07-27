import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'comptabilite.dart';
import 'document_pagination.dart';
import 'models.dart';
import 'signature_image.dart';
import 'utils.dart';

// ─────────────────────────────────────────────────────────
//  PdfGenerator — identique à l'aperçu Flutter
//  • Une pw.Page par feuille A4 (même pagination que le preview)
//  • pw.Spacer() → conditions/signature toujours en bas
//  • Mêmes couleurs, mêmes proportions
// ─────────────────────────────────────────────────────────
class PdfGenerator {
  // Couleurs identiques à AppColors
  static const _red    = PdfColor.fromInt(0xFFC62828);
  static const _grey1  = PdfColor.fromInt(0xFF1A1D2E);
  static const _grey2  = PdfColor.fromInt(0xFF6B7280);
  static const _grey3  = PdfColor.fromInt(0xFF9CA3AF);
  static const _bgBox  = PdfColor.fromInt(0xFFF7F7F7);
  static const _rowAlt = PdfColor.fromInt(0xFFFAFAFA);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);
  static const _bgFoot = PdfColor.fromInt(0xFFF8F8F8);

  // ── Pagination : strictement celle de l'aperçu ────────
  // Le découpage vient de DocumentPagination, partagé avec DocumentPreview :
  // le PDF a donc toujours le même nombre de pages et la même répartition des
  // lignes que ce qui est affiché à l'écran. Les hauteurs sont mesurées sur la
  // géométrie de l'aperçu (plus petite que l'A4), donc sûres pour le PDF.
  static List<List<LineItem>> _paginate(
    List<LineItem> lines,
    bool isBl,
    DocumentContext context,
  ) =>
      DocumentPagination.paginate(lines, isBl: isBl, context: context);

  // ── Helpers texte ─────────────────────────────────────
  static pw.TextStyle _ts(double sz, {
    PdfColor? color, pw.Font? font, double? spacing,
  }) => pw.TextStyle(
    font: font, fontSize: sz, color: color ?? _grey1, letterSpacing: spacing,
  );

  static String _typeLabel(String type) {
    if (type == 'proforma') return 'FACTURE PROFORMA';
    if (type == 'facture')  return 'FACTURE';
    return 'BON DE LIVRAISON';
  }

  // Repli si l'appelant ne fournit pas de numéro : premier document du jour de
  // ce type (`PREFIX-{L}01-JJMMAAAA`). En pratique les écrans passent toujours
  // le vrai numéro ; ce repli garde juste un format cohérent.
  static String _numero(AppSettings s, String type) =>
      DocNumero.next(s.prefix, type, const [], DateTime.now());

  static String _dateStr() {
    const m = ['Janvier','Février','Mars','Avril','Mai','Juin',
                'Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final n = DateTime.now();
    return '${n.day} ${m[n.month - 1]} ${n.year}';
  }

  // ── Logo KLR ─────────────────────────────────────────
  /// Logo officiel chargé depuis les assets, mémorisé pour ne le décoder
  /// qu'une fois par session (il apparaît sur chaque page de chaque document).
  static pw.ImageProvider? _logo;
  static bool _logoTried = false;

  static Future<pw.ImageProvider?> _loadLogo() async {
    if (_logoTried) return _logo;
    _logoTried = true;
    try {
      final data = await rootBundle.load('assets/logo/klr_mark.png');
      _logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      _logo = null; // asset indisponible : on retombe sur le losange dessiné
    }
    return _logo;
  }

  /// Marque affichée en tête de document : le vrai logo si disponible, sinon
  /// le losange tracé (repli qui garantit un en-tête jamais vide).
  static pw.Widget _mark(double size) =>
      _logo != null ? pw.Image(_logo!, height: size, width: size) : _diamond(size: size);

  static pw.Widget _diamond({double size = 22}) => pw.CustomPaint(
    size: PdfPoint(size, size),
    painter: (canvas, s) {
      canvas.setFillColor(_red);
      canvas.moveTo(s.x / 2, 0);
      canvas.lineTo(s.x,     s.y / 2);
      canvas.lineTo(s.x / 2, s.y);
      canvas.lineTo(0,       s.y / 2);
      canvas.closePath();
      canvas.fillPath();
    },
  );

  // ── En-tête page 1 ───────────────────────────────────
  static pw.Widget _header(AppSettings s, String type, String numero, String dateStr,
      pw.Font bold, pw.Font reg) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          _mark(26),
          pw.SizedBox(width: 8),
          pw.Text('KLR TECH', style: _ts(14, font: bold, spacing: 0.5)),
        ]),
        pw.Spacer(),
        pw.Text(_typeLabel(type), style: _ts(15, font: bold, spacing: 0.4)),
      ]),
      pw.SizedBox(height: 6),
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('N°  $numero', style: _ts(9.5, font: bold)),
          // Date omise si le manager ne l'a pas saisie.
          if (dateStr.isNotEmpty) pw.Text(dateStr, style: _ts(9, color: _grey3)),
        ],
      )),
    ]);
  }

  // ── Mini en-tête pages suivantes ──────────────────────
  static pw.Widget _miniHeader(String type, String numero, int page, int total,
      pw.Font bold, pw.Font reg) {
    return pw.Column(children: [
      pw.Row(children: [
        _mark(18),
        pw.SizedBox(width: 6),
        pw.Text('KLR TECH', style: _ts(11, font: bold, spacing: 0.5)),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Suite — ${_typeLabel(type)}', style: _ts(8, color: _grey2, font: bold)),
          pw.Text('N°  $numero   -   Page $page / $total', style: _ts(7.5, color: _grey3)),
        ]),
      ]),
      pw.SizedBox(height: 8),
      pw.Divider(color: _border, thickness: 0.5),
      pw.SizedBox(height: 8),
    ]);
  }

  // ── Info box (DE / À L'ATTENTION DE) ─────────────────
  static pw.Widget _infoBox(String label, List<String> lines,
      pw.Font bold, pw.Font reg, {bool highlight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _bgBox,
        border: pw.Border(left: pw.BorderSide(
          color: highlight ? _red : _grey3, width: 2)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: _ts(8, color: highlight ? _red : _grey3,
            font: bold, spacing: 0.8)),
        pw.SizedBox(height: 4),
        ...lines.asMap().entries.map((e) => pw.Text(e.value,
          style: _ts(e.key == 0 ? 10 : 8.5, font: e.key == 0 ? bold : reg))),
      ]),
    );
  }

  // ── Tableau + totaux ──────────────────────────────────
  static pw.Widget _table(List<LineItem> lines, bool tva,
      double ht, double tvaAmt, double ttc, bool showTotals, bool isBl,
      pw.Font bold, pw.Font reg) {
    return pw.Column(children: [
      // Header rouge
      pw.Container(
        color: _red,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(children: [
          pw.SizedBox(width: 28, child: pw.Text('Réf',        style: _ts(8, color: PdfColors.white, font: bold))),
          pw.SizedBox(width: 8),
          pw.Expanded(           child: pw.Text('Désignation',style: _ts(8, color: PdfColors.white, font: bold))),
          pw.SizedBox(width: 30, child: pw.Text('Qté',        style: _ts(8, color: PdfColors.white, font: bold), textAlign: pw.TextAlign.right)),
          if (!isBl) ...[
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 70, child: pw.Text('P.U (FCFA)', style: _ts(8, color: PdfColors.white, font: bold), textAlign: pw.TextAlign.right)),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 65, child: pw.Text('Montant',    style: _ts(8, color: PdfColors.white, font: bold), textAlign: pw.TextAlign.right)),
          ],
        ]),
      ),
      // Lignes
      ...lines.asMap().entries.map((e) {
        final l = e.value;
        return pw.Container(
          color: e.key % 2 == 0 ? _rowAlt : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 28, child: pw.Text(l.ref, style: _ts(8.5, color: _grey2))),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(l.designation, style: _ts(8.5))),
            pw.SizedBox(width: 30, child: pw.Text('${l.qte}', style: _ts(8.5, color: _grey2), textAlign: pw.TextAlign.right)),
            if (!isBl) ...[
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 70, child: pw.Text(Fmt.number(l.pu),    style: _ts(8.5, color: _grey2), textAlign: pw.TextAlign.right)),
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 65, child: pw.Text(Fmt.number(l.total), style: _ts(8.5, font: bold),    textAlign: pw.TextAlign.right)),
            ],
          ]),
        );
      }),
      // Totaux (dernière page uniquement, jamais sur un BL)
      if (showTotals && !isBl) ...[
        pw.SizedBox(height: 8),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.SizedBox(width: 200, child: pw.Column(children: [
          _ptRow('Sous-total HT', Fmt.number(ht), reg),
          if (tva) _ptRow('TVA (5%)', Fmt.number(tvaAmt), reg),
          pw.Divider(color: _border, thickness: 0.5),
          pw.Row(children: [
            pw.Text('TOTAL TTC', style: _ts(9.5, font: bold)),
            pw.Spacer(),
            pw.Text(Fmt.number(ttc), style: _ts(11, color: _red, font: bold)),
          ]),
        ]))),
      ],
    ]);
  }

  static pw.Widget _ptRow(String label, String value, pw.Font reg) =>
    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(children: [
      pw.Text(label, style: _ts(8.5, color: _grey2)),
      pw.Spacer(),
      pw.Text(value, style: _ts(8.5)),
    ]));

  // ── Conditions + Signature ────────────────────────────
  // Rendu simple et fiable : pas de Stack/Positioned/Overflow qui peuvent
  // casser silencieusement dans le moteur PDF.
  // CrossAxisAlignment.stretch → la boîte signature a la même hauteur
  // que la colonne conditions.
  static pw.Widget _conditionsRow(String conditions, String warranty, pw.Font bold, pw.Font reg,
      pw.ImageProvider? sigImage, String sigLabel) {
    // Hauteur exacte de la colonne conditions → hauteur de la case Signature,
    // pour qu'elle s'aligne au même niveau que le texte.
    final boxH = DocumentPagination.conditionsLeftHeight(conditions, warranty);

    // Alignement `start` (pas `stretch`) : dans le moteur PDF, `stretch` effondre
    // le Row à hauteur nulle. La case reçoit donc une hauteur explicite calculée.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Colonne gauche : conditions + clause ──────────
        pw.Expanded(child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Conditions de règlement :',
                style: _ts(7.5, font: bold)),
            pw.SizedBox(height: 3),
            ...conditions.split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((l) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 1),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Puce dessinée (un petit cercle) : DM Sans embarqué ne
                      // contient pas le glyphe « • », qui s'imprimerait en ▯.
                      pw.Container(
                        width: 2.4, height: 2.4,
                        margin: const pw.EdgeInsets.only(top: 3.4, right: 4),
                        decoration: const pw.BoxDecoration(color: _grey2, shape: pw.BoxShape.circle),
                      ),
                      pw.Expanded(child:
                          pw.Text(l.trim(), style: _ts(7.5, color: _grey2))),
                    ],
                  ),
                )),
            pw.SizedBox(height: 5),
            pw.Text(warranty, style: _ts(6, color: _grey3)),
          ],
        )),

        pw.SizedBox(width: 16),

        // ── Colonne droite : boîte signature ─────────────
        // Hauteur = colonne conditions. « Signature » posé sur le bord haut
        // (fond blanc masquant le trait pointillé).
        pw.Expanded(child: pw.SizedBox(
          height: boxH,
          child: pw.Stack(overflow: pw.Overflow.visible, children: [
            pw.Positioned(top: 0, left: 0, right: 0, bottom: 0, child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _border, width: 0.8, style: pw.BorderStyle.dashed),
                borderRadius: pw.BorderRadius.circular(16),
              ),
            )),
            // Signature du manager si présente : image + légende, à l'intérieur
            // du cadre. Même agencement que l'aperçu.
            if (sigImage != null)
              pw.Positioned(top: 7, left: 8, right: 8, bottom: 5, child: pw.Column(children: [
                pw.Expanded(child: pw.Center(child: pw.Image(sigImage, fit: pw.BoxFit.contain))),
                if (sigLabel.isNotEmpty)
                  pw.Text(sigLabel, textAlign: pw.TextAlign.center,
                      style: _ts(6.5, color: _grey2, font: bold)),
              ])),
            pw.Positioned(top: -5, left: 0, right: 0, child: pw.Center(child: pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6),
              child: pw.Text('Signature', style: _ts(7.5, color: _grey3, font: bold)),
            ))),
          ]),
        )),
      ],
    );
  }

  // ── Bande pied de page ────────────────────────────────
  static pw.Widget _footerBar(AppSettings s, pw.Font reg) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 16),
    color: _bgFoot,
    child: pw.Text(
      s.footerLine,
      style: _ts(6.5, color: _grey3, spacing: 0.4),
      textAlign: pw.TextAlign.center,
    ),
  );

  // ── Génération ───────────────────────────────────────
  static Future<List<int>> generate({
    required AppSettings settings,
    required String type,
    required String client,
    required String clientAddr,
    required String objet,
    required List<LineItem> lines,
    required bool tva,
    required double ht,
    required double tvaAmt,
    required double ttc,
    required String conditions,
    String? numero,
    String? date,
  }) async {
    final doc = pw.Document(title: _typeLabel(type));
    await _loadLogo();

    // Google Fonts → supporte tous les caractères Unicode (é, è, •, —, …)
    // Fallback sur Helvetica si pas d'accès réseau.
    pw.Font bold, reg;
    try {
      bold = await PdfGoogleFonts.dMSansBold();
      reg  = await PdfGoogleFonts.dMSansRegular();
    } catch (_) {
      bold = pw.Font.helveticaBold();
      reg  = pw.Font.helvetica();
    }
    final docNumero = numero ?? _numero(settings, type);
    // Date libre saisie par le manager : absente, aucune date n'est imprimée
    // (le PDF doit être le calque exact de l'aperçu).
    final docDate = (date == null || date.trim().isEmpty) ? '' : 'Date : ${date.trim()}';
    // Signature du manager décodée une seule fois, réutilisée sur la dernière page.
    final sigBytes = decodeSignature(settings.signature);
    final pw.ImageProvider? sigImage = sigBytes != null ? pw.MemoryImage(sigBytes) : null;
    final pageContext = DocumentContext(
      typeLabel: _typeLabel(type),
      numero: docNumero,
      date: docDate,
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
      showMontant: ttc > 0 && type != 'bl',
      tva: tva,
    );
    final pages  = _paginate(DocumentPagination.visible(lines), type == 'bl', pageContext);
    final total  = pages.length;

    for (int i = 0; i < total; i++) {
      final pageLines = pages[i];
      final isFirst = i == 0;
      final isLast  = i == total - 1;

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Column(children: [
          // ── Corps de la page ──────────────────────────
          pw.Expanded(child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                // En-tête
                if (isFirst) ...[
                  _header(settings, type, docNumero, docDate, bold, reg),
                  pw.SizedBox(height: 14),
                  // Info boxes
                  pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Expanded(child: _infoBox('DE :', [
                      settings.company, settings.address, settings.bp,
                    ], bold, reg)),
                    pw.SizedBox(width: 12),
                    pw.Expanded(child: _infoBox('À L\'ATTENTION DE :', [
                      if (client.isNotEmpty) client,
                      if (clientAddr.isNotEmpty) clientAddr,
                      if (client.isEmpty && clientAddr.isEmpty) '—',
                    ], bold, reg, highlight: true)),
                  ]),
                  pw.SizedBox(height: 12),
                  if (objet.isNotEmpty) ...[
                    pw.Text('Objet : $objet',
                        style: _ts(9.5, color: _grey2)),
                    pw.SizedBox(height: 10),
                  ],
                ] else ...[
                  _miniHeader(type, docNumero, i + 1, total, bold, reg),
                ],

                // Tableau
                _table(pageLines, tva, ht, tvaAmt, ttc, isLast, type == 'bl', bold, reg),

                // Montant en lettres (dernière page, jamais sur un BL)
                if (isLast && ttc > 0 && type != 'bl') ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Arrêté la présente facture à la somme de : '
                    '${NumberToWords.convert(ttc)} FRANCS CFA.',
                    style: _ts(8.5),
                  ),
                ],

                // Spacer : épingle les conditions / le n° de page en bas de page.
                // (L'invisibilité venait du `stretch` du bloc conditions, pas du
                // Spacer — désormais en alignement `start`.)
                pw.Spacer(),

                // Numéro de page (pages intermédiaires)
                if (!isLast)
                  pw.Align(alignment: pw.Alignment.center,
                    child: pw.Text('- Page ${i + 1} / $total -',
                        style: _ts(7.5, color: _grey3))),

                // Conditions + Signature (dernière page)
                if (isLast) _conditionsRow(conditions, settings.warranty, bold, reg, sigImage, settings.signatureLabel),
              ],
            ),
          )),

          // ── Bande grise toutes les pages ──────────────
          _footerBar(settings, reg),
        ]),
      ));
    }

    return doc.save();
  }

  /// Vrai sur Android et iOS, où il n'existe pas de boîte « Enregistrer
  /// sous » : le partage système remplace le choix d'un dossier.
  ///
  /// Le test de `kIsWeb` doit précéder toute lecture de `Platform`, qui n'est
  /// pas disponible dans un navigateur.
  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ── Enregistrer avec boîte "Enregistrer sous" ─────────
  // Retourne le chemin du fichier enregistré, ou null si annulé.
  static Future<String?> saveWithDialog({
    required List<int> bytes,
    required String type,
    required String numero,
  }) async {
    // Nom pré-rempli unique par document (compteur du jour repris du numéro) :
    // voir DocNumero.fileName. Aucun renommage manuel nécessaire.
    final filename = DocNumero.fileName(type, numero, DateTime.now());

    // Web et mobile passent par la même sortie : le paquet printing.
    //
    // Web : dart:io et FilePicker ne peuvent pas écrire de fichier, printing
    // déclenche le téléchargement du navigateur.
    //
    // Android / iOS : `FilePicker.platform.saveFile` n'y est **pas
    // implémenté**. Sans ce branchement, l'appel plus bas échouait et
    // l'exécution retombait sur un sélecteur de dossier puis sur une
    // supposition du dossier Téléchargements. `Printing.sharePdf` ouvre la
    // feuille de partage du système — enregistrer dans les Fichiers ou Drive,
    // envoyer par messagerie — ce qui est l'idiome mobile attendu.
    if (kIsWeb || _isMobile) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      return filename;
    }

    // 1. Boîte « Enregistrer sous » native : l'utilisateur choisit le dossier
    //    ET le nom du fichier.
    try {
      final chosen = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le document PDF',
        fileName: filename,
        // Ne pas passer type: FileType.custom — incompatible avec certaines
        // versions de file_picker sur Windows.
      );
      if (chosen != null) {
        final dest = chosen.toLowerCase().endsWith('.pdf') ? chosen : '$chosen.pdf';
        await File(dest).writeAsBytes(bytes);
        return dest;
      }
      return null; // annulé par l'utilisateur
    } catch (_) {
      // 2. Si « Enregistrer sous » n'est pas disponible, laisser au moins
      //    choisir le DOSSIER de destination.
      try {
        final dir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Choisir le dossier d\'enregistrement',
        );
        if (dir != null) {
          final path = '$dir${Platform.pathSeparator}$filename';
          await File(path).writeAsBytes(bytes);
          return path;
        }
        return null; // annulé
      } catch (_) {
        // 3. Dernier recours : dossier Téléchargements.
        return _saveToDownloads(bytes, filename);
      }
    }
  }

  // ── Rapport financier ─────────────────────────────────
  /// Rapport d'activité sur la période choisie. Tout provient des données
  /// réelles de l'application, via [Comptabilite.rapport] : aucun chiffre n'est
  /// inventé, et un exercice vide produit un rapport vide mais valide.
  static Future<List<int>> generateRapport({
    required AppSettings settings,
    required RapportPeriode rapport,
  }) async {
    final doc = pw.Document(title: 'Rapport d\'activité');

    pw.Font bold, reg;
    try {
      bold = await PdfGoogleFonts.dMSansBold();
      reg  = await PdfGoogleFonts.dMSansRegular();
    } catch (_) {
      bold = pw.Font.helveticaBold();
      reg  = pw.Font.helvetica();
    }
    await _loadLogo();

    String jour(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final periodeLabel = '${jour(rapport.debut)} — ${jour(rapport.fin)}';

    final categories = rapport.depensesParCategorie.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    pw.Widget kpi(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _bgBox,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: _ts(7, color: _grey3, font: bold, spacing: 0.6)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: _ts(12, font: bold)),
        ]),
      ),
    );

    pw.Widget sectionTitle(String t) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Text(t, style: _ts(12, font: bold, color: _red)),
    );

    pw.Widget cell(String t, {bool head = false, bool right = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(t,
        style: _ts(8.5, font: head ? bold : reg, color: head ? PdfColors.white : _grey1),
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      build: (ctx) => [
        // En-tête
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _mark(30),
          pw.SizedBox(width: 10),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(settings.company, style: _ts(14, font: bold)),
            pw.Text(settings.address, style: _ts(8, color: _grey2)),
            pw.Text('RCCM : ${settings.rccm}   Régime d\'imposition : ${settings.regime}', style: _ts(8, color: _grey2)),
          ]),
          pw.Spacer(),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('RAPPORT D\'ACTIVITÉ', style: _ts(14, font: bold, color: _red)),
            pw.Text(periodeLabel, style: _ts(9, font: bold, color: _grey1)),
            pw.Text('Édité le ${_dateStr()}', style: _ts(8, color: _grey2)),
          ]),
        ]),
        pw.SizedBox(height: 14),
        pw.Divider(color: _border, height: 1),

        // ── Synthèse ───────────────────────────────────────
        sectionTitle('Synthèse de la période'),
        pw.Row(children: [
          kpi('ENCAISSEMENTS', '${Fmt.number(rapport.revenu)} FCFA'),
          kpi('DÉCAISSEMENTS', '${Fmt.number(rapport.depenses)} FCFA'),
          kpi('BÉNÉFICE', '${Fmt.number(rapport.benefice)} FCFA'),
          kpi('DÎME (10%)', '${Fmt.number(rapport.dime)} FCFA'),
        ]),
        pw.SizedBox(height: 8),
        pw.Text(
          'Comptabilité tenue en base caisse : seules les sommes réellement '
          'encaissées ou décaissées entre le ${jour(rapport.debut)} et le '
          '${jour(rapport.fin)} figurent dans ce rapport.',
          style: _ts(7.5, color: _grey3),
        ),

        if (rapport.estVide) ...[
          pw.SizedBox(height: 30),
          pw.Center(child: pw.Text('Aucun mouvement sur cette période.',
              style: _ts(11, color: _grey2, font: bold))),
        ] else ...[
          // ── Détail mensuel ───────────────────────────────
          if (rapport.mois.isNotEmpty) ...[
            sectionTitle('Détail par mois'),
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(3),
                4: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _red),
                  children: [
                    cell('Mois', head: true),
                    cell('Encaissé', head: true, right: true),
                    cell('Dépensé', head: true, right: true),
                    cell('Bénéfice', head: true, right: true),
                    cell('Dîme', head: true, right: true),
                  ],
                ),
                ...rapport.mois.asMap().entries.map((e) => pw.TableRow(
                  decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? _rowAlt : PdfColors.white),
                  children: [
                    cell(e.value.label),
                    cell(Fmt.number(e.value.revenuHt), right: true),
                    cell(Fmt.number(e.value.depenses), right: true),
                    cell(Fmt.number(e.value.benefice), right: true),
                    cell(Fmt.number(e.value.dime), right: true),
                  ],
                )),
              ],
            ),
          ],

          // ── Dépenses par catégorie ───────────────────────
          if (categories.isNotEmpty) ...[
            sectionTitle('Dépenses par catégorie'),
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _red),
                  children: [
                    cell('Catégorie', head: true),
                    cell('Montant', head: true, right: true),
                    cell('Part', head: true, right: true),
                  ],
                ),
                ...categories.asMap().entries.map((e) => pw.TableRow(
                  decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? _rowAlt : PdfColors.white),
                  children: [
                    cell(e.value.key),
                    cell(Fmt.number(e.value.value), right: true),
                    cell(rapport.depenses > 0
                        ? '${(e.value.value / rapport.depenses * 100).round()}%'
                        : '—', right: true),
                  ],
                )),
              ],
            ),
          ],

          // ── Mouvements détaillés ─────────────────────────
          sectionTitle('Détail des mouvements (${rapport.mouvements.length})'),
          pw.Table(
            border: pw.TableBorder.all(color: _border, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(4),
              3: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _red),
                children: [
                  cell('Date', head: true),
                  cell('Libellé', head: true),
                  cell('Tiers / catégorie', head: true),
                  cell('Montant', head: true, right: true),
                ],
              ),
              ...rapport.mouvements.asMap().entries.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(color: e.key % 2 == 0 ? _rowAlt : PdfColors.white),
                children: [
                  cell(jour(e.value.date)),
                  cell(e.value.libelle),
                  cell(e.value.detail),
                  // Le signe distingue une entrée d'une sortie d'argent.
                  cell('${e.value.entree ? '+' : '-'} ${Fmt.number(e.value.montant)}',
                      right: true),
                ],
              )),
            ],
          ),
        ],

        // ── Situation des créances ─────────────────────────
        sectionTitle('Situation à date'),
        pw.Text(
          'Créances encore en cours (restant dû, acomptes déduits) : '
          '${Fmt.number(rapport.creancesEnCours)} FCFA',
          style: _ts(9),
        ),
      ],
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          '${settings.company.toUpperCase()}  |  RCCM : ${settings.rccm}  —  Page ${ctx.pageNumber}/${ctx.pagesCount}',
          style: _ts(6.5, color: _grey3),
        ),
      ),
    ));

    return doc.save();
  }

  /// Enregistre un rapport PDF via la boîte de dialogue (ou Téléchargements).
  static Future<String?> saveRapport(List<int> bytes) async {
    final now = DateTime.now();
    final d = '${now.day.toString().padLeft(2,'0')}'
              '${now.month.toString().padLeft(2,'0')}'
              '${now.year}';
    final filename = 'KLR-Rapport-$d.pdf';

    // Même sortie que saveWithDialog sur web et mobile. Cette fonction n'avait
    // aucun garde : sur le web, `saveFile` levait puis `_saveToDownloads`
    // levait à son tour en lisant `Platform.environment`, indisponible dans un
    // navigateur — l'export de rapport y était donc cassé.
    if (kIsWeb || _isMobile) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: filename);
      return filename;
    }

    try {
      final chosen = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le rapport PDF',
        fileName: filename,
      );
      if (chosen != null) {
        final dest = chosen.toLowerCase().endsWith('.pdf') ? chosen : '$chosen.pdf';
        await File(dest).writeAsBytes(bytes);
        return dest;
      }
      return null;
    } catch (_) {
      return _saveToDownloads(bytes, filename);
    }
  }

  /// Enregistre dans le dossier Téléchargements et retourne le chemin.
  static Future<String> _saveToDownloads(
      List<int> bytes, String filename) async {
    final home = Platform.environment['USERPROFILE'] ??
                 Platform.environment['HOME'] ??
                 Directory.current.path;
    final dir = Directory('$home${Platform.pathSeparator}Downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    final path = '${dir.path}${Platform.pathSeparator}$filename';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  // ── Imprimer ──────────────────────────────────────────
  static Future<void> printDoc(List<int> bytes) async {
    final data = Uint8List.fromList(bytes);
    await Printing.layoutPdf(
      onLayout: (_) async => data,
      name: 'KLR Document',
    );
  }
}
