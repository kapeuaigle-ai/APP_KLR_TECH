import 'models.dart';

/// Totaux globaux, en base caisse : seules les sommes réellement encaissées ou
/// décaissées comptent. Il n'y a plus de distinction HT/TTC — l'application ne
/// gère aucune taxe, un document vaut la somme de ses lignes.
class ComptaTotaux {
  final double revenu; // factures encaissées uniquement
  final double depenses; // toutes les dépenses
  final double benefice; // revenu - depenses
  final double dime;     // somme des dîmes mensuelles
  const ComptaTotaux({
    required this.revenu, required this.depenses,
    required this.benefice, required this.dime,
  });
}

/// Une ligne du bilan mensuel.
class MonthlyRow {
  final String monthKey; // 'yyyy-MM'
  final String label;    // 'Juillet 2026'
  final double revenu;
  final double depenses;
  final double benefice;
  final double dime;
  final bool dimePaid;
  final String? dimeDate;
  const MonthlyRow({
    required this.monthKey, required this.label, required this.revenu,
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

  static double montantFacture(DocumentItem f) =>
      f.lines.fold(0.0, (s, l) => s + l.total);

  /// Décaissements rattachés à une facture — sert au bénéfice par facture.
  ///
  /// `regle` est déjà la somme réellement versée : un achat annulé après un
  /// paiement partiel continue de peser sur le bénéfice à hauteur de ce qui a
  /// circulé, par le même principe qu'en `_flux`.
  static double depensesFacture(String numero, List<Engagement> engagements) =>
      engagements
          .where((e) => !e.estEntrant && e.documentNumero == numero)
          .fold(0.0, (s, e) => s + e.regle);

  static double beneficeFacture(DocumentItem f, List<Engagement> engagements) =>
      montantFacture(f) - depensesFacture(f.numero, engagements);

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

  /// Tous les règlements d'une liste d'engagements, avec leur sens.
  ///
  /// Un engagement annulé n'est PAS écarté : ses règlements ont réellement eu
  /// lieu, et en base caisse une somme encaissée l'est restée. L'annulation
  /// retire l'engagement des montants ATTENDUS — voir `creancesEnCours` — pas
  /// des mouvements passés. Sans quoi annuler un engagement partiellement payé
  /// réécrirait des mois déjà clôturés, dont la dîme est peut-être versée.
  static Iterable<({Engagement engagement, Reglement reglement})> _flux(
      List<Engagement> engagements) sync* {
    for (final e in engagements) {
      for (final r in e.reglements) {
        yield (engagement: e, reglement: r);
      }
    }
  }

  static ComptaTotaux totaux(List<Engagement> engagements) {
    var revenu = 0.0, dep = 0.0;
    for (final f in _flux(engagements)) {
      if (f.engagement.estEntrant) {
        revenu += f.reglement.montant;
      } else {
        dep += f.reglement.montant;
      }
    }
    final dime = bilanMensuel(engagements, const {}, const {})
        .fold(0.0, (s, r) => s + r.dime);
    return ComptaTotaux(
      revenu: revenu, depenses: dep, benefice: revenu - dep, dime: dime,
    );
  }

  static List<MonthlyRow> bilanMensuel(
    List<Engagement> engagements,
    Set<String> dimePaidMonths,
    Map<String, String> dimePaidDates,
  ) {
    final rev = <String, double>{};
    final dep = <String, double>{};

    // Base caisse : chaque règlement est porté au mois de sa propre date.
    for (final f in _flux(engagements)) {
      if (f.reglement.montant <= 0) continue;
      final k = monthKeyFromDate(f.reglement.date);
      if (f.engagement.estEntrant) {
        rev[k] = (rev[k] ?? 0) + f.reglement.montant;
      } else {
        dep[k] = (dep[k] ?? 0) + f.reglement.montant;
      }
    }

    final keys = <String>{...rev.keys, ...dep.keys}.toList()..sort();
    return keys.map((k) {
      final r = rev[k] ?? 0, d = dep[k] ?? 0;
      final b = r - d;
      return MonthlyRow(
        monthKey: k, label: monthLabel(k), revenu: r, depenses: d,
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

  static RapportPeriode rapport({
    required DateTime debut,
    required DateTime fin,
    required List<Engagement> engagements,
  }) {
    final mouvements = <MouvementRapport>[];
    final parCategorie = <String, double>{};

    for (final f in _flux(engagements)) {
      final r = f.reglement, e = f.engagement;
      if (r.montant <= 0 || !dansPeriode(r.date, debut, fin)) continue;
      final entree = e.estEntrant;
      // La description porte l'information utile quand elle existe — c'est le
      // libellé que le manager a lui-même saisi, ou celui repris d'une dépense
      // v1. Le numéro de pièce ne sert de libellé qu'à défaut : sans lui, trois
      // achats rattachés à la même facture seraient indiscernables.
      final libelle = e.description.isNotEmpty
          ? e.description
          : (e.documentNumero != null
              ? '${entree ? 'Facture' : 'Achat'} ${e.documentNumero}'
              : (entree ? 'Encaissement' : 'Décaissement'));
      mouvements.add(MouvementRapport(
        date: r.date,
        libelle: libelle,
        detail: e.tiers,
        montant: r.montant,
        entree: entree,
      ));
      if (!entree) {
        parCategorie[e.categorie] = (parCategorie[e.categorie] ?? 0) + r.montant;
      }
    }

    mouvements.sort((a, b) => a.date.compareTo(b.date));

    final revenu = mouvements.where((m) => m.entree).fold(0.0, (s, m) => s + m.montant);
    final depenses = mouvements.where((m) => !m.entree).fold(0.0, (s, m) => s + m.montant);
    final benefice = revenu - depenses;

    // Détail mensuel : on réutilise le bilan global, restreint aux mois de la
    // période, pour rester cohérent avec l'onglet Comptabilité.
    final tousMois = bilanMensuel(engagements, const {}, const {});
    final mois = tousMois.where((r) {
      final p = r.monthKey.split('-');
      final debutMois = DateTime(int.parse(p[0]), int.parse(p[1]));
      final finMois = DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0);
      return !finMois.isBefore(DateTime(debut.year, debut.month, debut.day)) &&
             !debutMois.isAfter(DateTime(fin.year, fin.month, fin.day));
    }).toList();

    final creancesEnCours = engagements
        .where((e) => e.estEntrant && !e.annule && !e.solde)
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
