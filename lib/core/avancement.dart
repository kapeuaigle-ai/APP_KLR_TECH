import 'models.dart';

/// Statut d'un projet. Déduit, jamais saisi — sauf l'annulation, seul état
/// qu'aucune donnée ne permet de deviner.
enum StatutProjet { annule, aDemarrer, solde, livreNonPaye, enCours }

extension StatutProjetLibelle on StatutProjet {
  String get libelle => switch (this) {
    StatutProjet.annule => 'Annulé',
    StatutProjet.aDemarrer => 'À démarrer',
    StatutProjet.solde => 'Soldé',
    StatutProjet.livreNonPaye => 'Livré — reste à encaisser',
    StatutProjet.enCours => 'En cours',
  };
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

  const Avancement({
    required this.physique, required this.financier,
    required this.montantAttendu, required this.montantEncaisse,
    required this.montantDepense, required this.montantRestant,
    required this.statut,
    required this.enRetardLivraison, required this.enRetardPaiement,
  });

  double get marge => montantEncaisse - montantDepense;

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
    final actifs = engagements.where((e) => !e.annule).toList();
    final entrants = actifs.where((e) => e.estEntrant).toList();
    final sortants = actifs.where((e) => !e.estEntrant).toList();

    final attendu = entrants.fold(0.0, (s, e) => s + e.montant);
    final encaisse = entrants.fold(0.0, (s, e) => s + e.regle);
    final depense = sortants.fold(0.0, (s, e) => s + e.regle);

    // `restant` part de `e.reste`, déjà écrêté sous le centime par
    // `Engagement.reste` — jamais d'un ratio recalculé sur les sommes brutes
    // de `encaisse`, qui réintroduirait le résidu flottant IEEE-754 que la
    // Phase 1 a déjà corrigé une fois (voir le commentaire sur `reste`).
    final restant = entrants.fold(0.0, (s, e) => s + e.reste);
    final physique = physiqueForce ?? _physique(projet, mode, proformas, now);
    final financier =
        attendu == 0 ? 0.0 : ((attendu - restant) / attendu).clamp(0.0, 1.0);

    final finDepassee = now.isAfter(DateTime(
        projet.finPrevue.year, projet.finPrevue.month, projet.finPrevue.day));

    return Avancement(
      physique: physique,
      financier: financier,
      montantAttendu: attendu,
      montantEncaisse: encaisse,
      montantDepense: depense,
      montantRestant: restant,
      statut: _statut(projet, physique, financier),
      enRetardLivraison: !projet.annule && finDepassee && physique < 1,
      enRetardPaiement: entrants.any((e) => e.enRetard(now)),
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

  /// Les règles sont évaluées dans l'ordre : la première qui correspond
  /// l'emporte (§ 6.3 de la conception).
  static StatutProjet _statut(Projet projet, double physique, double financier) {
    if (projet.annule) return StatutProjet.annule;
    if (physique == 0 && financier == 0) return StatutProjet.aDemarrer;
    if (physique >= 1 && financier >= 1) return StatutProjet.solde;
    if (physique >= 1) return StatutProjet.livreNonPaye;
    return StatutProjet.enCours;
  }
}
