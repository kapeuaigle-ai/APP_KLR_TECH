import 'package:intl/intl.dart';
import 'models.dart';

/// Numérotation des documents : `PREFIX-{L}{NN}-JJMMAAAA`.
/// L = lettre de type (P proforma, F facture, B bon de livraison),
/// NN = n° de ce type DU JOUR (repart à 01 chaque jour), date sur 8 chiffres.
/// Ex. `KLR-P01-25072026`.
class DocNumero {
  static const _letters = {'proforma': 'P', 'facture': 'F', 'bl': 'B'};
  static const _labels = {'proforma': 'Proforma', 'facture': 'Facture', 'bl': 'BL'};

  /// Numéro d'un nouveau document. [sameType] = les documents DÉJÀ existants du
  /// MÊME type (l'appelant passe `documents[type]`) : NN = ceux du jour + 1, ce
  /// qui donne le reset quotidien automatique (aucun doc du jour → repart à 01).
  static String next(String prefix, String type, List<DocumentItem> sameType, DateTime now) {
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final today = '$dd/$mm/${now.year}';
    final count = sameType.where((d) => d.date == today).length + 1;
    final letter = _letters[type] ?? '';
    return '$prefix-$letter${count.toString().padLeft(2, '0')}-$dd$mm${now.year}';
  }

  /// Décline un numéro vers un autre type en gardant compteur ET date : seule la
  /// lettre change (`KLR-P02-25072026` → facture `KLR-F02-25072026`). Sert à
  /// générer la facture et le BL appariés à leur proforma. Un ancien numéro
  /// (sans lettre, année sur 2 chiffres) est normalisé au passage.
  static String retype(String numero, String toType) {
    final parts = numero.split('-');
    if (parts.length < 3) return numero; // format inattendu : inchangé
    final prefix = parts.sublist(0, parts.length - 2).join('-');
    final nn = parts[parts.length - 2].replaceAll(RegExp(r'\D'), '');
    var date = parts.last;
    if (date.length == 6) date = '${date.substring(0, 4)}20${date.substring(4)}';
    if (nn.isEmpty || int.tryParse(date) == null) return numero;
    return '$prefix-${_letters[toType] ?? ''}$nn-$date';
  }

  /// Nom du fichier PDF proposé au téléchargement : le numéro exact du document
  /// suivi de `.pdf` (ex. `KLR-F02-25072026.pdf`). La lettre indique déjà le
  /// type, donc pas de libellé ajouté ; deux documents d'une même journée
  /// donnent bien deux fichiers distincts.
  ///
  /// Si le numéro est absent ou inattendu (brouillon), on retombe sur un nom
  /// daté du jour portant le libellé du type.
  static String fileName(String type, String numero, DateTime now) {
    final parts = numero.split('-');
    if (parts.length >= 3) {
      final seq = parts[parts.length - 2];
      final date = parts.last;
      final looksLikeNumero = seq.contains(RegExp(r'\d')) &&
          (date.length == 6 || date.length == 8) && int.tryParse(date) != null;
      if (looksLikeNumero) return '$numero.pdf';
    }

    // Numéro absent ou inattendu : nom daté du jour, avec le libellé du type.
    final label = _labels[type] ?? type;
    final d = '${now.day.toString().padLeft(2, '0')}'
              '${now.month.toString().padLeft(2, '0')}'
              '${now.year}';
    return 'KLR-$label-$d.pdf';
  }
}

class Fmt {
  static final _nf = NumberFormat('#,##0', 'fr_FR');

  static String money(double n) {
    if (n == 0) return '0 FCFA';
    return '${_nf.format(n.round())} FCFA';
  }

  static String number(double n) => _nf.format(n.round());

  /// 'dd/MM/yyyy' — le format de date utilisé partout dans l'app.
  static String jour(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class NumberToWords {
  static const _units = ['', 'UN', 'DEUX', 'TROIS', 'QUATRE', 'CINQ', 'SIX', 'SEPT', 'HUIT', 'NEUF',
    'DIX', 'ONZE', 'DOUZE', 'TREIZE', 'QUATORZE', 'QUINZE', 'SEIZE', 'DIX-SEPT', 'DIX-HUIT', 'DIX-NEUF'];
  static const _tens = ['', '', 'VINGT', 'TRENTE', 'QUARANTE', 'CINQUANTE', 'SOIXANTE', 'SOIXANTE', 'QUATRE-VINGT', 'QUATRE-VINGT'];

  static String _h(int n) {
    if (n < 20) return _units[n];
    final t = n ~/ 10, r = n % 10;
    if (t == 7) return r == 1 ? 'SOIXANTE-ET-ONZE' : 'SOIXANTE-${_units[10 + r]}';
    if (t == 9) return r == 0 ? 'QUATRE-VINGT' : 'QUATRE-VINGT-${_units[10 + r]}';
    final sep = r == 1 && t != 8 ? ' ET ' : r > 0 ? '-' : '';
    return '${_tens[t]}$sep${_units[r]}';
  }

  static String _hundred(int n) {
    if (n < 100) return _h(n);
    final c = n ~/ 100, r = n % 100;
    final prefix = c > 1 ? '${_units[c]} ' : '';
    return r > 0 ? '${prefix}CENT ${_h(r)}' : '${prefix}CENT';
  }

  static String convert(double amount) {
    final n = amount.round();
    if (n == 0) return 'ZÉRO';
    final M = n ~/ 1000000, rest = n % 1000000;
    final m = rest ~/ 1000, r = rest % 1000;
    var s = '';
    if (M > 0) s += '${M == 1 ? 'UN MILLION' : '${_hundred(M)} MILLIONS'} ';
    if (m > 0) s += '${m == 1 ? 'MILLE' : '${_hundred(m)} MILLE'} ';
    if (r > 0) s += _hundred(r);
    return s.trim();
  }
}
