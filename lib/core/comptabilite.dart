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
