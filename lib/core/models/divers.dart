import 'package:flutter/material.dart';
import 'commun.dart';

// ── Employee ─────────────────────────────────────────────
class Employee {
  final int id;
  final String nom;
  final String initiales;
  final String role;
  final String dept;
  final String statut; // 'actif' | 'conge' | 'mission'
  final int projets;
  final int taches;
  final int perf;
  final String phone;
  final String email;
  final Color color;

  const Employee({
    required this.id, required this.nom, required this.initiales,
    required this.role, required this.dept, required this.statut,
    required this.projets, required this.taches, required this.perf,
    required this.phone, required this.email, required this.color,
  });
}

// ── Department ───────────────────────────────────────────
class Department {
  final String nom;
  final int membres;
  final Color color;
  final Color bg;
  final int projets;
  final String chef;

  const Department({
    required this.nom, required this.membres, required this.color,
    required this.bg, required this.projets, required this.chef,
  });
}

// ── Dîme History ─────────────────────────────────────────
class DimeEntry {
  final String mois;
  final double revenu;
  final double dime;
  final String statut; // 'paye' | 'attente'
  final String? date;

  const DimeEntry({
    required this.mois, required this.revenu, required this.dime,
    required this.statut, this.date,
  });
}

// ── Task ─────────────────────────────────────────────────
class Task {
  final int id;
  String texte;
  String titre;
  String priorite; // 'haute' | 'normale' | 'basse'
  bool done;

  Task({
    required this.id, required this.texte, required this.titre,
    required this.priorite, this.done = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'texte': texte, 'titre': titre, 'priorite': priorite, 'done': done,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'], texte: j['texte'], titre: j['titre'],
    priorite: j['priorite'], done: j['done'] ?? false,
  );
}

// ── Note ─────────────────────────────────────────────────
class Note {
  final int id;
  String titre;
  String contenu;
  Color color;
  String date;

  Note({
    required this.id, required this.titre, required this.contenu,
    required this.color, required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'titre': titre, 'contenu': contenu,
    'color': colorToInt(color), 'date': date,
  };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'], titre: j['titre'], contenu: j['contenu'],
    color: colorFromInt(j['color']), date: j['date'],
  );
}

// ── Activity ─────────────────────────────────────────────
class ActivityItem {
  final int id;
  final String type;
  final String titre;
  final String desc;
  final String auteur;
  final String initiales;
  final String time;
  final Color color;

  const ActivityItem({
    required this.id, required this.type, required this.titre,
    required this.desc, required this.auteur, required this.initiales,
    required this.time, required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'titre': titre, 'desc': desc,
    'auteur': auteur, 'initiales': initiales, 'time': time,
    'color': colorToInt(color),
  };

  factory ActivityItem.fromJson(Map<String, dynamic> j) => ActivityItem(
    id: j['id'], type: j['type'], titre: j['titre'], desc: j['desc'],
    auteur: j['auteur'], initiales: j['initiales'], time: j['time'],
    color: colorFromInt(j['color']),
  );
}
