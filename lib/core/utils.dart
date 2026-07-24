import 'package:intl/intl.dart';
import 'models.dart';

/// Numérotation des documents : `PREFIX-NN-ddMMyy`.
/// NN = n° de la proforma DU JOUR (repart à 01 chaque jour).
class DocNumero {
  static String next(String prefix, List<DocumentItem> proformas, DateTime now) {
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final today = '$dd/$mm/${now.year}';
    final count = proformas.where((p) => p.date == today).length + 1;
    final d = '$dd$mm${now.year.toString().substring(2)}';
    return '$prefix-${count.toString().padLeft(2, '0')}-$d';
  }
}

class Fmt {
  static final _nf = NumberFormat('#,##0', 'fr_FR');

  static String money(double n) {
    if (n == 0) return '0 FCFA';
    return '${_nf.format(n.round())} FCFA';
  }

  static String number(double n) => _nf.format(n.round());

  static String millions(double n) => '${(n / 1000000).toStringAsFixed(1)}M';
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
