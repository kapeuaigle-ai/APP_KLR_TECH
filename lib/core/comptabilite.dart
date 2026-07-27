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

/// Un mouvement d'argent daté, à l'intérieur d'une période de rapport.
class MouvementRapport {
  final DateTime date;
  final String libelle;
  final String detail;   // client, tiers, catégorie…
  final double montant;
  final bool entree;     // true = encaissement, false = décaissement
  const MouvementRapport({
    required this.date, required this.libelle, required this.detail,
    required this.montant, required this.entree,
  });
}

/// Rapport d'activité sur une période bornée, en base caisse : seules les
/// sommes réellement encaissées ou décaissées entre les deux dates comptent.
class RapportPeriode {
  final DateTime debut, fin;
  final double revenu;
  final double depenses;
  final double benefice;
  final double dime;
  /// Détail mensuel restreint aux mois touchés par la période.
  final List<MonthlyRow> mois;
  /// Tous les mouvements de la période, du plus ancien au plus récent.
  final List<MouvementRapport> mouvements;
  final Map<String, double> depensesParCategorie;
  /// Reste dû sur les créances non encore réglées (hors période : c'est une
  /// situation à date, pas un flux).
  final double creancesEnCours;

  const RapportPeriode({
    required this.debut, required this.fin, required this.revenu,
    required this.depenses, required this.benefice, required this.dime,
    required this.mois, required this.mouvements,
    required this.depensesParCategorie, required this.creancesEnCours,
  });

  bool get estVide => mouvements.isEmpty;
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

  static ComptaTotaux totaux(List<DocumentItem> factures, List<Expense> expenses,
      List<Engagement> engagements) {
    // Base caisse : ce qui a réellement circulé. Un engagement réglé compte
    // pour son montant entier ; s'il n'est pas encore réglé, seul l'acompte
    // déjà versé compte.
    double encaisse(Engagement e) => e.regle ? e.montant : (e.aAcompte ? e.acompte : 0.0);

    final revenu = factures
            .where((f) => f.encaissee)
            .fold(0.0, (s, f) => s + factureHt(f)) +
        engagements
            .where((e) => e.estCreance)
            .fold(0.0, (s, e) => s + encaisse(e));
    final dep = expenses.fold(0.0, (s, e) => s + e.amount) +
        engagements
            .where((e) => !e.estCreance)
            .fold(0.0, (s, e) => s + encaisse(e));
    final dime = bilanMensuel(factures, expenses, engagements, const {}, const {})
        .fold(0.0, (s, r) => s + r.dime);
    return ComptaTotaux(
      revenuHt: revenu, depenses: dep, benefice: revenu - dep, dime: dime,
    );
  }

  static List<MonthlyRow> bilanMensuel(
    List<DocumentItem> factures,
    List<Expense> expenses,
    List<Engagement> engagements,
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
    // Engagements : chaque mouvement d'argent est rattaché au mois où il a eu
    // lieu. L'acompte compte donc au mois de son versement, et la validation
    // n'apporte plus que le solde — sans quoi l'acompte serait compté deux fois.
    void porter(String monthKey, bool creance, double montant) {
      if (montant <= 0) return;
      if (creance) {
        rev[monthKey] = (rev[monthKey] ?? 0) + montant;
      } else {
        dep[monthKey] = (dep[monthKey] ?? 0) + montant;
      }
    }

    for (final e in engagements) {
      if (e.aAcompte) {
        porter(monthKeyFromDdMmYyyy(e.dateAcompte!), e.estCreance, e.acompte);
      }
      if (e.regle) {
        porter(monthKeyFromDdMmYyyy(e.dateReglement!), e.estCreance, e.montantAuReglement);
      }
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

  /// 'dd/MM/yyyy' → DateTime, ou null si la chaîne est inexploitable.
  static DateTime? parseJour(String? s) {
    if (s == null) return null;
    final p = s.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  /// Bornes incluses, à la journée près.
  static bool dansPeriode(DateTime d, DateTime debut, DateTime fin) {
    final j = DateTime(d.year, d.month, d.day);
    final a = DateTime(debut.year, debut.month, debut.day);
    final b = DateTime(fin.year, fin.month, fin.day);
    return !j.isBefore(a) && !j.isAfter(b);
  }

  /// Construit le rapport d'une période. Ne retient que les mouvements réels :
  /// factures encaissées, dépenses payées, acomptes reçus ou versés, et soldes
  /// d'engagements réglés — chacun à sa propre date.
  static RapportPeriode rapport({
    required DateTime debut,
    required DateTime fin,
    required List<DocumentItem> factures,
    required List<Expense> expenses,
    required List<Engagement> engagements,
  }) {
    final mouvements = <MouvementRapport>[];
    final parCategorie = <String, double>{};

    void ajouterDepense(String categorie, double montant) {
      if (montant <= 0) return;
      parCategorie[categorie] = (parCategorie[categorie] ?? 0) + montant;
    }

    for (final f in factures) {
      final d = parseJour(f.dateEncaissement);
      if (!f.encaissee || d == null || !dansPeriode(d, debut, fin)) continue;
      mouvements.add(MouvementRapport(
        date: d, libelle: 'Facture ${f.numero}', detail: f.client,
        montant: factureHt(f), entree: true));
    }

    for (final e in expenses) {
      if (!dansPeriode(e.date, debut, fin)) continue;
      mouvements.add(MouvementRapport(
        date: e.date, libelle: e.label, detail: e.category,
        montant: e.amount, entree: false));
      ajouterDepense(e.category, e.amount);
    }

    for (final e in engagements) {
      final creance = e.estCreance;
      // Acompte : compté à sa date de versement.
      final da = parseJour(e.dateAcompte);
      if (e.aAcompte && da != null && dansPeriode(da, debut, fin)) {
        mouvements.add(MouvementRapport(
          date: da, libelle: 'Acompte ${e.num}', detail: e.tiers,
          montant: e.acompte, entree: creance));
        if (!creance) ajouterDepense(e.categorie, e.acompte);
      }
      // Règlement : le solde seulement, l'acompte ayant déjà été porté.
      final dr = parseJour(e.dateReglement);
      if (e.regle && dr != null && dansPeriode(dr, debut, fin)) {
        final montant = e.montantAuReglement;
        if (montant > 0) {
          mouvements.add(MouvementRapport(
            date: dr,
            libelle: creance ? 'Créance ${e.num}' : 'Dette ${e.num}',
            detail: e.tiers, montant: montant, entree: creance));
          if (!creance) ajouterDepense(e.categorie, montant);
        }
      }
    }

    mouvements.sort((a, b) => a.date.compareTo(b.date));

    final revenu = mouvements.where((m) => m.entree).fold(0.0, (s, m) => s + m.montant);
    final depenses = mouvements.where((m) => !m.entree).fold(0.0, (s, m) => s + m.montant);
    final benefice = revenu - depenses;

    // Détail mensuel : on réutilise le bilan global, restreint aux mois de la
    // période, pour rester cohérent avec l'onglet Comptabilité.
    final tousMois = bilanMensuel(factures, expenses, engagements, const {}, const {});
    final mois = tousMois.where((r) {
      final p = r.monthKey.split('-');
      final debutMois = DateTime(int.parse(p[0]), int.parse(p[1]));
      final finMois = DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0);
      return !finMois.isBefore(DateTime(debut.year, debut.month, debut.day)) &&
             !debutMois.isAfter(DateTime(fin.year, fin.month, fin.day));
    }).toList();

    final creancesEnCours = engagements
        .where((e) => e.estCreance && !e.regle)
        .fold(0.0, (s, e) => s + e.reste);

    return RapportPeriode(
      debut: debut, fin: fin,
      revenu: revenu, depenses: depenses, benefice: benefice,
      dime: benefice > 0 ? benefice * 0.10 : 0,
      mois: mois, mouvements: mouvements,
      depensesParCategorie: parCategorie,
      creancesEnCours: creancesEnCours,
    );
  }

  static MonthlyRow? ligneMois(String monthKey, List<MonthlyRow> rows) {
    for (final r in rows) {
      if (r.monthKey == monthKey) return r;
    }
    return null;
  }

  /// Mois à clôturer : de `dernierMois` (inclus) au mois précédant `now`.
  ///
  /// `dernierMois` est le mois que l'app a vu la dernière fois. Au premier
  /// lancement il est nul : il n'y a rien à clôturer. Si l'app est restée
  /// fermée plusieurs mois, ils ressortent tous, du plus ancien au plus
  /// récent, pour être archivés dans Activités.
  static List<String> moisAClore(String? dernierMois, DateTime now) {
    if (dernierMois == null) return const [];
    final p = dernierMois.split('-');
    if (p.length != 2) return const [];
    var y = int.tryParse(p[0]) ?? 0;
    var m = int.tryParse(p[1]) ?? 0;
    if (y == 0 || m < 1 || m > 12) return const [];

    final res = <String>[];
    while (y < now.year || (y == now.year && m < now.month)) {
      res.add('$y-${m.toString().padLeft(2, '0')}');
      m++;
      if (m > 12) { m = 1; y++; }
    }
    return res;
  }
}
