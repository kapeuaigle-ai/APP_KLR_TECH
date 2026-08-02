import 'package:flutter/material.dart';

/// Encodage couleur ⇄ entier ARGB, pour la persistance JSON.
int colorToInt(Color c) => c.toARGB32();
Color colorFromInt(int v) => Color(v);

/// Conversion JSON → double, tolérante aux entiers.
double toDouble(dynamic v) => (v as num).toDouble();

// ── Nav Screen enum ──────────────────────────────────────
enum NavScreen {
  dashboard, documents, clients, projets, suivi, activites, rapports,
  parametres, gantt, documentCreate,
}
