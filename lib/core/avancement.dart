import 'models.dart';

/// Statut d'un projet. Déduit, jamais saisi — sauf l'annulation, seul état
/// qu'aucune donnée ne permet de deviner.
enum StatutProjet { annule, aDemarrer, termine, termineNonPaye, enCours }

extension StatutProjetLibelle on StatutProjet {
  String get libelle => switch (this) {
    StatutProjet.annule => 'Annulé',
    StatutProjet.aDemarrer => 'À démarrer',
    StatutProjet.termine => 'Terminé',
    // Le nom interne dit l'état réel — le travail est fait, l'argent non
    // rentré. Le libellé affiché est celui qu'a choisi le manager, et les
    // deux n'ont pas à coïncider : « Terminé » deux fois de suite dans le
    // bandeau du Kanban se lisait comme un doublon.
    StatutProjet.termineNonPaye => 'En révision',
    StatutProjet.enCours => 'En cours',
  };
}

/// Une rentrée attendue, à une échéance.
class EcheanceAttendue {
  final DateTime echeance;
  final double montant;
  final String tiers;
  final String? documentNumero;
  final bool enRetard;

  const EcheanceAttendue({
    required this.echeance, required this.montant, required this.tiers,
    required this.documentNumero, required this.enRetard,
  });
}

/// Résultat complet du calcul d'un projet. Aucun de ces chiffres n'est stocké.
class Avancement {
  final double physique;   // 0..1
  final double financier;  // 0..1
  final double montantAttendu;
  final double montantEncaisse;
  final double montantDepense;
  final double montantRestant;
  final StatutProjet statut;
  final bool enRetardLivraison;
  final bool enRetardPaiement;
  final bool finDepassee;

  const Avancement({
    required this.physique, required this.financier,
    required this.montantAttendu, required this.montantEncaisse,
    required this.montantDepense, required this.montantRestant,
    required this.statut,
    required this.enRetardLivraison, required this.enRetardPaiement,
    required this.finDepassee,
  });

  /// Marge réalisée : encaissé moins décaissé, en base caisse.
  ///
  /// Un résidu inférieur au centime est ramené à zéro. Les deux termes somment
  /// un nombre quelconque de règlements, et l'arithmétique flottante laisserait
  /// sinon un projet à l'équilibre exact du mauvais côté du zéro — affiché en
  /// rouge alors qu'il n'a rien perdu. Même précaution que `Engagement.reste`.
  double get marge {
    final m = montantEncaisse - montantDepense;
    return m.abs() < 0.01 ? 0 : m;
  }

  /// Calcule tout l'état d'un projet à la date `now`.
  ///
  /// `now` est un paramètre obligatoire, jamais `DateTime.now()` : c'est ce
  /// qui rend les retards et le mode `duree` testables.
  ///
  /// `physiqueForce` court-circuite le calcul physique — réservé aux tests du
  /// statut, qui doivent pouvoir poser un pourcentage arbitraire.
  static Avancement calculer({
    required Projet projet,
    required ModeAvancement mode,
    required List<DocumentItem> proformas,
    required List<Engagement> engagements,
    required DateTime now,
    double? physiqueForce,
  }) {
    // Même séparation que `Comptabilite._flux` (voir son commentaire) : ce
    // qui a RÉELLEMENT eu lieu (les règlements, donc `regle`) compte quel que
    // soit `annule`, ce qui reste seulement ATTENDU (`montant`, `reste`) ne
    // compte que pour un engagement encore actif. Annuler un engagement
    // retire ce qui restait à venir, jamais ce qui a déjà circulé — sans quoi
    // un projet dont l'engagement encaissé est ensuite annulé perdrait
    // l'argent réellement reçu (défaut 2, revue Lot B).
    final tousEntrants = engagements.where((e) => e.estEntrant).toList();
    final tousSortants = engagements.where((e) => !e.estEntrant).toList();
    final entrantsActifs = tousEntrants.where((e) => !e.annule).toList();

    final attendu = entrantsActifs.fold(0.0, (s, e) => s + e.montant);
    final encaisse = tousEntrants.fold(0.0, (s, e) => s + e.regle);
    final depense = tousSortants.fold(0.0, (s, e) => s + e.regle);

    // `restant` part de `e.reste`, déjà écrêté sous le centime par
    // `Engagement.reste` — jamais d'un ratio recalculé sur les sommes brutes
    // de `encaisse`, qui réintroduirait le résidu flottant IEEE-754 que la
    // Phase 1 a déjà corrigé une fois (voir le commentaire sur `reste`).
    // Comme `attendu`, restreint aux engagements actifs : un engagement
    // annulé ne doit plus rien « rester à devoir ».
    final restant = entrantsActifs.fold(0.0, (s, e) => s + e.reste);
    final physique = physiqueForce ?? _physique(projet, mode, proformas, now);
    final financier =
        attendu == 0 ? 0.0 : ((attendu - restant) / attendu).clamp(0.0, 1.0);

    // Le jour de l'échéance n'est pas un dépassement — même règle que
    // `Engagement.enRetard` (§ notes d'environnement) : deux règles de date
    // contradictoires dans la même appli seraient pires que l'une ou l'autre.
    // `now` est TRONQUÉ au jour avant comparaison, exactement comme
    // `Engagement.enRetard`. Sans cette troncature, `now` porte ses heures :
    // à 14 h le jour même de l'échéance, `14h.isAfter(minuit)` est vrai et le
    // projet bascule en révision avec une journée d'avance. Le test ne l'avait
    // pas vu parce qu'il passait un `now` à minuit pile.
    final jourCourant = DateTime(now.year, now.month, now.day);
    final finDepassee = jourCourant.isAfter(DateTime(
        projet.finPrevue.year, projet.finPrevue.month, projet.finPrevue.day));

    return Avancement(
      physique: physique,
      financier: financier,
      montantAttendu: attendu,
      montantEncaisse: encaisse,
      montantDepense: depense,
      montantRestant: restant,
      statut: _statut(projet, physique, financier, attendu, finDepassee),
      enRetardLivraison: !projet.annule && finDepassee && physique < 1,
      enRetardPaiement: entrantsActifs.any((e) => e.enRetard(now)),
      finDepassee: finDepassee,
    );
  }

  /// Avancement physique selon le mode.
  static double _physique(Projet projet, ModeAvancement mode,
      List<DocumentItem> proformas, DateTime now) {
    switch (mode) {
      case ModeAvancement.quantites:
        var total = 0.0, livre = 0.0;
        for (final p in proformas) {
          for (final l in p.lines) {
            total += l.total;
            livre += l.totalLivre;
          }
        }
        return total == 0 ? 0.0 : (livre / total).clamp(0.0, 1.0);

      case ModeAvancement.jalons:
        // Pondéré par `poids`, pas par simple décompte : un jalon lourd fait
        // avancer plus qu'un jalon léger.
        var total = 0.0, fait = 0.0;
        for (final j in projet.jalons) {
          total += j.poids;
          if (j.fait) fait += j.poids;
        }
        return total == 0 ? 0.0 : (fait / total).clamp(0.0, 1.0);

      case ModeAvancement.duree:
        // Fraction du temps écoulé entre `debut` et `finPrevue`, écrêtée à
        // [0, 1]. `debut == finPrevue` (durée nulle) ne doit pas diviser
        // par zéro : avant strictement le terme, 0 ; sinon, 1.
        final debut = DateTime(projet.debut.year, projet.debut.month, projet.debut.day);
        final fin = DateTime(
            projet.finPrevue.year, projet.finPrevue.month, projet.finPrevue.day);
        final jour = DateTime(now.year, now.month, now.day);
        final duree = fin.difference(debut).inDays;
        if (duree <= 0) return jour.isBefore(fin) ? 0.0 : 1.0;
        final ecoule = jour.difference(debut).inDays;
        return (ecoule / duree).clamp(0.0, 1.0);

      case ModeAvancement.manuel:
        return projet.avancementManuel.clamp(0.0, 1.0);
    }
  }

  /// Ce qui doit rentrer, et quand : le reste dû de chaque engagement entrant
  /// non soldé, trié de l'échéance la plus proche à la plus lointaine.
  ///
  /// Ne devient calculable qu'une fois les engagements unifiés : c'est une
  /// retombée directe de la phase 1.
  static List<EcheanceAttendue> tresoreriePrevisionnelle(
      List<Engagement> engagements, {required DateTime now}) {
    final res = engagements
        .where((e) => e.estEntrant && !e.annule && !e.solde)
        .map((e) => EcheanceAttendue(
              echeance: e.echeance,
              montant: e.reste,
              tiers: e.tiers,
              documentNumero: e.documentNumero,
              enRetard: e.enRetard(now),
            ))
        .toList();
    res.sort((a, b) => a.echeance.compareTo(b.echeance));
    return res;
  }

  /// Les règles sont évaluées dans l'ordre : la première qui correspond
  /// l'emporte (§ 6.3 de la conception).
  ///
  /// `attendu == 0` signifie qu'aucun engagement entrant n'est rattaché — un
  /// projet interne, ou une proforma pas encore validée. Rien n'est alors dû,
  /// et le projet doit pouvoir se terminer : sans ce cas, `financier` reste
  /// nul à jamais et le projet resterait bloqué à « reste à encaisser » en
  /// annonçant un encaissement qui n'a jamais été attendu.
  ///
  /// « En révision » ne dit plus « livré mais pas payé » : le manager l'a
  /// redéfini comme « l'échéance est là, il faut renégocier ». D'où l'ordre :
  ///
  /// 1. Un projet livré ET soldé (`termine`) l'emporte toujours sur la date —
  ///    sans ce test avant celui de l'échéance, tout projet terminé finirait,
  ///    des mois après sa clôture, par retomber en « En révision » puisque sa
  ///    fin prévue est nécessairement dans le passé.
  /// 2. Un projet jamais démarré (`aDemarrer`) reste dans sa colonne même
  ///    après sa date : une idée notée et jamais lancée peut n'avoir aucun
  ///    client à renégocier. Le badge « Échéance atteinte » porte ce rappel,
  ///    pas un changement de colonne.
  /// 3. Sinon, une échéance dépassée bascule en révision : soit le client
  ///    n'a pas honoré son côté, soit l'entreprise le sien, et le manager
  ///    doit trancher.
  static StatutProjet _statut(Projet projet, double physique, double financier,
      double attendu, bool finDepassee) {
    if (projet.annule) return StatutProjet.annule;
    final rienARecevoir = attendu == 0 || financier >= 1;
    if (physique >= 1 && rienARecevoir) return StatutProjet.termine;
    if (physique == 0 && financier == 0) return StatutProjet.aDemarrer;
    if (finDepassee) return StatutProjet.termineNonPaye;
    return StatutProjet.enCours;
  }
}
