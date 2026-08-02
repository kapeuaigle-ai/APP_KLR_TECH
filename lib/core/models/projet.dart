/// Façon de mesurer l'avancement PHYSIQUE d'un projet. Le suivi financier,
/// lui, est identique pour tous les modes : règlements ÷ montant engagé.
enum ModeAvancement { quantites, jalons, duree, manuel }

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
  String typeId;
  int? clientId;      // null = projet interne
  String client;      // nom dénormalisé, comme DocumentItem.client
  DateTime debut;
  DateTime finPrevue;
  List<Jalon> jalons;
  double avancementManuel; // 0..1, utilisé seulement si mode == manuel
  bool annule;

  Projet({
    required this.id, required this.nom, required this.typeId,
    required this.clientId, required this.client,
    required this.debut, required this.finPrevue,
    List<Jalon>? jalons, this.avancementManuel = 0, this.annule = false,
  }) : jalons = jalons ?? [];

  Map<String, dynamic> toJson() => {
    'id': id, 'nom': nom, 'typeId': typeId,
    'clientId': clientId, 'client': client,
    'debut': debut.toIso8601String(), 'finPrevue': finPrevue.toIso8601String(),
    'jalons': jalons.map((j) => j.toJson()).toList(),
    'avancementManuel': avancementManuel, 'annule': annule,
  };

  factory Projet.fromJson(Map<String, dynamic> j) => Projet(
    id: j['id'], nom: j['nom'], typeId: j['typeId'] ?? 'fourniture',
    clientId: j['clientId'], client: j['client'] ?? '',
    debut: DateTime.parse(j['debut']), finPrevue: DateTime.parse(j['finPrevue']),
    jalons: (j['jalons'] as List? ?? []).map((x) => Jalon.fromJson(x)).toList(),
    avancementManuel: (j['avancementManuel'] as num? ?? 0).toDouble(),
    annule: j['annule'] ?? false,
  );
}
