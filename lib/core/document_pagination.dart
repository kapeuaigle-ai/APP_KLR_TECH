import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';

/// Éléments textuels d'un document dont la hauteur dépend du contenu et de la
/// police. Fournis au paginateur pour qu'il mesure les vraies hauteurs plutôt
/// que de supposer un nombre de lignes.
class DocumentContext {
  final String typeLabel;
  final String numero;
  final String date;
  final List<String> deLines; // bloc « DE : »
  final List<String> attentionLines; // bloc « À L'ATTENTION DE : »
  final String objet;
  final String montantWords; // « Arrêté la présente facture… »
  final String conditions; // lignes séparées par \n
  final String warranty; // clause de garantie
  final String footerLine;
  final bool showMontant; // montant en lettres affiché (facture/proforma non nulle)

  const DocumentContext({
    required this.typeLabel,
    required this.numero,
    required this.date,
    required this.deLines,
    required this.attentionLines,
    required this.objet,
    required this.montantWords,
    required this.conditions,
    required this.warranty,
    required this.footerLine,
    required this.showMontant,
  });
}

/// Découpe les lignes d'un document en pages.
///
/// Partagé par l'aperçu à l'écran et le générateur PDF : c'est le même calcul
/// qui produit les deux, ils ne peuvent donc pas diverger.
///
/// Les hauteurs sont MESURÉES à l'exécution avec la police réellement active
/// (via [TextPainter] + GoogleFonts), et non estimées : une police plus étroite
/// renvoie moins à la ligne et laisse tenir davantage de lignes par page. Le
/// calcul est donc juste quel que soit l'environnement — DM Sans en production,
/// police de repli dans les tests — puisque mesure et rendu partagent la police.
///
/// La géométrie de référence est la page de composition de l'aperçu
/// (530 × 749,6, ratio A4). La page PDF (A4, 595 × 842 pt) est plus grande à
/// tailles de police identiques : ce qui tient dans l'aperçu tient donc a
/// fortiori dans le PDF.
class DocumentPagination {
  // ── Géométrie partagée aperçu ⇔ PDF ───────────────────
  // Dimensions A4 en points : l'aperçu compose à ces mêmes dimensions puis les
  // met à l'échelle. Aperçu et PDF partagent donc EXACTEMENT la même géométrie
  // (page, marges, colonnes), condition d'une adéquation parfaite.
  static const pageW = 595.28; // A4 largeur (PdfPageFormat.a4.width)
  static const pageH = 841.89; // A4 hauteur (PdfPageFormat.a4.height)
  static const padL = 28.0, padR = 28.0, padT = 24.0, padB = 12.0;
  static const contentW = pageW - padL - padR;
  static const tableHPad = 8.0; // padding horizontal interne du tableau
  static const colGap = 8.0; // écart entre colonnes

  // Largeurs des colonnes fixes du tableau (identiques aperçu/PDF).
  static const colRef = 28.0, colQte = 30.0, colPu = 70.0, colMontant = 65.0;

  // Somme des colonnes fixes (hors Désignation, qui prend le reste).
  static const _fixedCols = colRef + colGap + colQte + colGap + colPu + colGap + colMontant;
  static const _fixedColsBl = colRef + colGap + colQte;

  // Alias internes conservés pour la lisibilité du modèle de hauteur.
  static const _pageW = pageW;
  static const _pageH = pageH;
  static const _padT = padT;
  static const _padB = padB;
  static const _contentW = contentW;

  // Largeur utile de la colonne Désignation.
  static const _designationW = _contentW - 2 * tableHPad - _fixedCols;
  static const _designationWBl = _contentW - 2 * tableHPad - _fixedColsBl;

  // Marge de sécurité : absorbe les petits écarts entre le modèle de hauteur et
  // la mise en page réelle, pour ne jamais déborder d'un cheveu.
  static const _safety = 12.0;

  // Interligne effectif des textes sans `height` explicite (hérité du thème).
  // Calibré sur le rendu réel ; légèrement majoré pour rester conservateur.
  static const _leading = 1.5;


  /// Clause de garantie par défaut. Source unique dans models (`kDefaultWarranty`),
  /// réutilisée ici comme repli et pour le calcul de hauteur. Le texte réellement
  /// affiché vient de `settings.warranty` (personnalisable).
  static const warrantyClause = kDefaultWarranty;

  /// Lignes réellement portées par le document : celles ayant une désignation.
  /// Les rangées laissées vides ne sont ni affichées ni comptées.
  static List<LineItem> visible(List<LineItem> lines) =>
      lines.where((l) => l.designation.trim().isNotEmpty).toList();

  // ── Mesure de texte avec la police active ─────────────
  static double _h(String s, double size,
      {double? height, FontWeight? weight, double letterSpacing = 0, double maxWidth = double.infinity}) {
    // On n'utilise TextPainter QUE pour compter les lignes (fiable, fonction de
    // la largeur) : sa hauteur brute est trompeuse quand la police n'est pas
    // résolue. La hauteur réelle d'une ligne est fontSize × facteur d'interligne
    // — soit la valeur explicite du rendu (`height`), soit celle héritée du
    // thème (`_leading`) pour les textes qui n'en fixent pas.
    final lines = _lineCount(s, size, weight: weight, letterSpacing: letterSpacing, maxWidth: maxWidth);
    return lines * size * (height ?? _leading);
  }

  static int _lineCount(String s, double size,
      {FontWeight? weight, double letterSpacing = 0, double maxWidth = double.infinity}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s.isEmpty ? ' ' : s,
        style: GoogleFonts.dmSans(fontSize: size, fontWeight: weight, letterSpacing: letterSpacing),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return tp.computeLineMetrics().length.clamp(1, 60);
  }

  /// Hauteur occupée par une ligne dans le tableau (padding vertical compris).
  /// La rangée est dominée par les cellules sans `height` (Réf, Qté…) → interligne du thème.
  static double _lineHeight(LineItem l, {required bool isBl}) =>
      10 + rowsFor(l, isBl: isBl) * 8.5 * _leading; // padding vertical 5 + 5

  /// Nombre de rangées d'une ligne (exposé pour les tests).
  static int rowsFor(LineItem l, {required bool isBl}) =>
      _lineCount(l.designation, 8.5, maxWidth: isBl ? _designationWBl : _designationW).clamp(1, 6);

  // ── Hauteurs des blocs fixes, mesurées ────────────────
  static double _footerH(DocumentContext c) =>
      14 + _h(c.footerLine, 6.5, letterSpacing: 0.4, maxWidth: _pageW - 32);

  static double _infoBoxH(DocumentContext c) {
    const boxW = (_contentW - 12) / 2; // deux boîtes + 12 d'écart
    const inner = boxW - 2 - 20; // barre latérale 2 + padding 10×2
    double linesH(List<String> lines) {
      var h = 0.0;
      for (var i = 0; i < lines.length; i++) {
        h += _h(lines[i], i == 0 ? 10 : 8.5,
            height: 1.5, weight: i == 0 ? FontWeight.w700 : null, maxWidth: inner);
      }
      return h;
    }

    final de = linesH(c.deLines);
    final att = linesH(c.attentionLines);
    return 20 + _h('DE', 8, weight: FontWeight.w800) + 4 + (de > att ? de : att);
  }

  static double _firstHeaderH(DocumentContext c) {
    final logoRow = 26.0; // le losange fait 26px, > hauteur du texte type
    final numDate = _h(c.numero, 9.5, weight: FontWeight.w700) + _h(c.date, 9);
    final objet = c.objet.isEmpty ? 0.0 : _h(c.objet, 9.5, maxWidth: _contentW) + 10;
    return logoRow + 6 + numDate + 14 + _infoBoxH(c) + 12 + objet;
  }

  static double _miniHeaderH(DocumentContext c) {
    final right = _h('Suite', 9, weight: FontWeight.w700) + _h(c.numero, 8);
    final row = right > 18 ? right : 18.0;
    return row + 10 + 1 + 10; // + SizedBox10 + Divider1 + SizedBox10
  }

  // padding vertical 10 + hauteur mesurée de l'en-tête de colonne
  static double _tableHeaderH() => 10 + _h('Réf', 8, weight: FontWeight.w700);

  // Un document ne porte plus qu'un seul montant (pas de ligne « Sous-total »
  // séparée : sans TVA, elle afficherait le même chiffre que TOTAL).
  static double _totalsH() {
    final total = _h('TOTAL', 9.5, weight: FontWeight.w800);
    final montant = _h('0', 11, weight: FontWeight.w900);
    return 8 + 8 + (total > montant ? total : montant); // SizedBox8 + Divider8 + ligne TOTAL
  }

  static double _montantH(DocumentContext c) =>
      c.showMontant ? 10 + _h(c.montantWords, 8.5, height: 1.5, maxWidth: _contentW) : 0;

  /// Hauteur de la colonne conditions (titre + puces + clause). Sert de hauteur
  /// exacte à la case Signature (aperçu + PDF), pour qu'elle s'aligne au texte.
  static double conditionsLeftHeight(String conditions, String warranty) {
    const leftColW = (_contentW - 16) / 2; // deux colonnes + écart 16
    const bullet = 2.4 + 4; // cercle dessiné + marge droite
    const condW = leftColW - bullet;
    var lines = 0.0;
    for (final l in conditions.split('\n').where((l) => l.trim().isNotEmpty)) {
      lines += _h(l.trim(), 7.5, height: 1.25, maxWidth: condW) + 1;
    }
    return _h('Conditions', 7.5, weight: FontWeight.w700) +
        3 + lines + 5 +
        _h(warranty, 6, height: 1.25, maxWidth: leftColW);
  }

  static double _conditionsH(DocumentContext c) =>
      7 + conditionsLeftHeight(c.conditions, c.warranty); // +7 : étiquette Signature

  static double _pageNumH() => _h('— Page 1 / 2 —', 7.5);

  // ── Pagination ────────────────────────────────────────
  static List<List<LineItem>> paginate(
    List<LineItem> lines, {
    required bool isBl,
    required DocumentContext context,
  }) {
    if (lines.isEmpty) return [[]];

    final contentAvail = _pageH - _footerH(context) - _padT - _padB;
    final firstHeader = _firstHeaderH(context);
    final miniHeader = _miniHeaderH(context);
    final totals = isBl ? 0.0 : _totalsH();
    final montant = isBl ? 0.0 : _montantH(context);
    final conditions = _conditionsH(context);

    // Budgets en pixels pour les rangées, selon le rôle de la page.
    final singleBudget = contentAvail - firstHeader - _tableHeaderH() - totals - montant - conditions - _safety;
    final firstBudget = contentAvail - firstHeader - _tableHeaderH() - _safety;
    final lastBudget = contentAvail - miniHeader - _tableHeaderH() - totals - montant - conditions - _safety;
    final midBudget = contentAvail - miniHeader - _tableHeaderH() - _pageNumH() - _safety;

    final heights = [for (final l in lines) _lineHeight(l, isBl: isBl)];

    // Nombre de lignes tenant dans [budget] px à partir de [from].
    // Toujours au moins 1, sinon la boucle ne progresserait pas.
    int fit(int from, double budget) {
      var used = 0.0, n = 0;
      for (var i = from; i < lines.length; i++) {
        if (used + heights[i] > budget) break;
        used += heights[i];
        n++;
      }
      return n.clamp(1, lines.length - from);
    }

    // Page unique : tout tient avec les totaux et les conditions.
    if (fit(0, singleBudget) == lines.length) return [List.from(lines)];

    // Multi-pages : au moins deux pages. On garde au moins une ligne pour la
    // suivante afin que la page 1 ne soit jamais aussi la dernière.
    final pages = <List<LineItem>>[];
    var cursor = fit(0, firstBudget).clamp(1, lines.length - 1);
    pages.add(lines.sublist(0, cursor));

    while (cursor < lines.length) {
      final remaining = lines.length - cursor;
      if (fit(cursor, lastBudget) == remaining) {
        pages.add(lines.sublist(cursor));
        cursor = lines.length;
      } else {
        var n = fit(cursor, midBudget);
        if (n >= remaining) n = remaining - 1;
        pages.add(lines.sublist(cursor, cursor + n));
        cursor += n;
      }
    }
    return pages;
  }
}
