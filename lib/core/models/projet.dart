/// Façon de mesurer l'avancement PHYSIQUE d'un projet. Le suivi financier,
/// lui, est identique pour tous les modes : règlements ÷ montant engagé.
enum ModeAvancement { quantites, jalons, duree, manuel }

/// Libellé et explication d'un mode, affichés à la création d'un projet
/// (comment son avancement sera mesuré). Centralisés ici pour n'exister
/// qu'une fois.
extension ModeAvancementLibelle on ModeAvancement {
  String get libelle => switch (this) {
    ModeAvancement.quantites => 'Quantités livrées',
    ModeAvancement.jalons => 'Jalons',
    ModeAvancement.duree => 'Durée écoulée',
    ModeAvancement.manuel => 'Saisie manuelle',
  };

  String get explication => switch (this) {
    ModeAvancement.quantites =>
      'L\'avancement se déduit des quantités livrées, pondérées par le montant.',
    ModeAvancement.jalons =>
      'L\'avancement se déduit des jalons réalisés, selon leur poids.',
    ModeAvancement.duree =>
      'L\'avancement suit le calendrier, du début à la fin prévue.',
    ModeAvancement.manuel =>
      'L\'avancement est saisi à la main. Aucun contrôle possible.',
  };
}

/// Une étape datée d'un projet, pondérée dans l'avancement.
class Jalon {
  String nom;
  DateTime prevue;
  DateTime? realisee; // null = pas encore fait
  double poids;

  Jalon({required this.nom, required this.prevue, this.realisee, this.poids = 1});

  bool get fait => realisee != null;

  Map<String, dynamic> toJson() => {
    'nom': nom, 'prevue': prevue.toIso8601String(),
    'realisee': realisee?.toIso8601String(), 'poids': poids,
  };

  factory Jalon.fromJson(Map<String, dynamic> j) => Jalon(
    nom: j['nom'], prevue: DateTime.parse(j['prevue']),
    realisee: j['realisee'] == null ? null : DateTime.parse(j['realisee']),
    poids: (j['poids'] as num).toDouble(),
  );
}

/// Un regroupement de documents et d'engagements sous un même objectif.
///
/// NE STOCKE AUCUN MONTANT ni aucun pourcentage : montant total, encaissé,
/// avancement et statut sont calculés par `avancement.dart` à partir des
/// couches du dessous. C'est cette règle qui empêche toute redondance de
/// réapparaître.
class Projet {
  final int id;
  String nom;
  /// Libellé libre : « Fourniture de matériel », « Voyage employés »…
  /// L'application n'en tient aucun registre — c'est une étiquette, pas une
  /// entité. Les suggestions offertes à la saisie se construisent depuis les
  /// projets déjà enregistrés.
  String type;
  /// Comment l'avancement physique de CE projet se mesure. Porté par le
  /// projet lui-même : c'est la seule chose que l'ancien registre de types
  /// apportait.
  ModeAvancement mode;
  int? clientId;      // null = projet interne
  String client;      // nom dénormalisé, comme DocumentItem.client
  DateTime debut;
  DateTime finPrevue;
  List<Jalon> jalons;
  double avancementManuel; // 0..1, utilisé seulement si mode == manuel
  bool annule;

  Projet({
    required this.id, required this.nom, required this.type, required this.mode,
    required this.clientId, required this.client,
    required this.debut, required this.finPrevue,
    List<Jalon>? jalons, this.avancementManuel = 0, this.annule = false,
  }) : jalons = jalons ?? [];

  /// Faux si `finPrevue` est antérieure à `debut` : une durée négative rend
  /// tout ce qui se construit sur la période (Gantt, retards) incohérent.
  /// Un projet d'un seul jour (`finPrevue == debut`) reste valide.
  bool get periodeValide => !finPrevue.isBefore(debut);

  Map<String, dynamic> toJson() => {
    'id': id, 'nom': nom, 'type': type, 'mode': mode.name,
    'clientId': clientId, 'client': client,
    'debut': debut.toIso8601String(), 'finPrevue': finPrevue.toIso8601String(),
    'jalons': jalons.map((j) => j.toJson()).toList(),
    'avancementManuel': avancementManuel, 'annule': annule,
  };

  factory Projet.fromJson(Map<String, dynamic> j) => Projet(
    id: j['id'], nom: j['nom'], type: j['type'] ?? '',
    // Un mode inconnu (sauvegarde d'une version ultérieure, champ corrompu)
    // ne doit jamais faire planter le chargement.
    mode: ModeAvancement.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => ModeAvancement.quantites,
    ),
    clientId: j['clientId'], client: j['client'] ?? '',
    debut: DateTime.parse(j['debut']), finPrevue: DateTime.parse(j['finPrevue']),
    jalons: (j['jalons'] as List? ?? []).map((x) => Jalon.fromJson(x)).toList(),
    avancementManuel: (j['avancementManuel'] as num? ?? 0).toDouble(),
    annule: j['annule'] ?? false,
  );
}
