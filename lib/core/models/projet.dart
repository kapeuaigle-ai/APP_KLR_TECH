import 'package:flutter/material.dart';
import 'commun.dart';

/// Façon de mesurer l'avancement PHYSIQUE d'un projet. Le suivi financier,
/// lui, est identique pour tous les modes : règlements ÷ montant engagé.
enum ModeAvancement { quantites, jalons, duree, manuel }

/// Un type de projet, défini par le manager dans les Paramètres.
///
/// Le code ne connaît jamais les métiers : il connaît quatre modes
/// d'avancement. Ajouter « Formation » ou « Infogérance » ne demande donc
/// aucune ligne de code.
class TypeProjet {
  final String id;
  String libelle;
  ModeAvancement mode;
  Color couleur;

  TypeProjet({
    required this.id, required this.libelle,
    required this.mode, required this.couleur,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'libelle': libelle, 'mode': mode.name,
    'couleur': colorToInt(couleur),
  };

  factory TypeProjet.fromJson(Map<String, dynamic> j) => TypeProjet(
    id: j['id'], libelle: j['libelle'],
    // Un mode inconnu (type supprimé, sauvegarde d'une version ultérieure)
    // ne doit jamais faire planter le chargement.
    mode: ModeAvancement.values.firstWhere(
      (m) => m.name == j['mode'],
      orElse: () => ModeAvancement.quantites,
    ),
    couleur: colorFromInt(j['couleur']),
  );

  /// Types livrés au premier lancement. Tous modifiables et supprimables.
  static List<TypeProjet> get defauts => [
    TypeProjet(id: 'fourniture', libelle: 'Fourniture de matériel',
        mode: ModeAvancement.quantites, couleur: const Color(0xFF2563EB)),
    TypeProjet(id: 'installation', libelle: 'Installation / déploiement',
        mode: ModeAvancement.jalons, couleur: const Color(0xFFF59E0B)),
    TypeProjet(id: 'maintenance', libelle: 'Maintenance / contrat',
        mode: ModeAvancement.duree, couleur: const Color(0xFF10B981)),
    TypeProjet(id: 'interne', libelle: 'Projet interne',
        mode: ModeAvancement.manuel, couleur: const Color(0xFF8B5CF6)),
  ];
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

  /// Faux si `finPrevue` est antérieure à `debut` : une durée négative rend
  /// tout ce qui se construit sur la période (Gantt, retards) incohérent.
  /// Un projet d'un seul jour (`finPrevue == debut`) reste valide.
  bool get periodeValide => !finPrevue.isBefore(debut);

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
