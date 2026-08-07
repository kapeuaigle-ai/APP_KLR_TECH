import 'package:flutter/material.dart';

/// Encodage couleur ⇄ entier ARGB, pour la persistance JSON.
int colorToInt(Color c) => c.toARGB32();
Color colorFromInt(int v) => Color(v);

/// Conversion JSON → double, tolérante aux entiers (4 lu comme 4.0) mais PAS
/// à un type qui n'est pas un nombre — `as num` lève dans ce cas.
///
/// Ne pas confondre avec `_double` de `migration.dart`, qui elle avale tout
/// et retombe sur 0.0 : distinction délibérée (lot G, hygiène), pas un
/// oubli. `fromJson` lit une sauvegarde que CETTE version de l'app vient
/// d'écrire — un champ qui n'est pas un nombre y est une corruption qu'il
/// vaut mieux voir planter que masquer. La migration, elle, lit un fichier
/// hérité d'une version antérieure, potentiellement modifié à la main ou
/// partiellement corrompu ; son travail est de produire quelque chose
/// d'exploitable même face à un champ manquant ou aberrant, pas de refuser
/// de migrer.
double toDouble(dynamic v) => (v as num).toDouble();

// ── Nav Screen enum ──────────────────────────────────────
enum NavScreen {
  dashboard, documents, clients, projets, suivi, activites, rapports,
  parametres, gantt, documentCreate,
}
