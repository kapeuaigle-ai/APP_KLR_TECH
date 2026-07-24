import 'package:flutter/material.dart';

// ── Client ──────────────────────────────────────────────
class Client {
  final int id;
  final String initials;
  final Color color;
  final String name;
  final String contact;
  final String email;
  final String phone;
  final double totalFacture;
  final String status; // 'actif' | 'attente' | 'cours'
  final String address;

  const Client({
    required this.id, required this.initials, required this.color,
    required this.name, required this.contact, required this.email,
    required this.phone, required this.totalFacture, required this.status,
    this.address = '',
  });
}

// ── Document ─────────────────────────────────────────────
class DocumentItem {
  final int id;
  final String numero;
  final String date;
  final int clientId;
  final String client;
  final String clientAddr;
  final String objet;
  final double montant;
  String statut; // 'cours' | 'validee' | 'annulee'
  // Lignes du document — permettent de régénérer le PDF depuis la liste.
  final List<LineItem> lines;
  // Encaissement (comptabilité de caisse). Distinct du statut de workflow.
  bool encaissee;
  String? dateEncaissement; // 'dd/MM/yyyy' quand encaissee == true

  DocumentItem({
    required this.id, required this.numero, required this.date,
    required this.clientId, required this.client, required this.objet,
    required this.montant, required this.statut,
    this.clientAddr = '', this.lines = const [],
    this.encaissee = false, this.dateEncaissement,
  });
}

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

// ── Facture History ──────────────────────────────────────
class FactureEntry {
  final String num;
  final String client;
  final double montant;
  String statut;
  final String echeance;

  FactureEntry({
    required this.num, required this.client, required this.montant,
    required this.statut, required this.echeance,
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
}

// ── Project Card ─────────────────────────────────────────
class ProjectCard {
  final String? tag;
  final String title;
  final String? desc;
  final String? date;
  final List<String> assignees;
  final String? subtasks;
  final int? attachments;
  final int? progress;
  final List<String> tags;

  const ProjectCard({
    this.tag, required this.title, this.desc, this.date,
    required this.assignees, this.subtasks, this.attachments,
    this.progress, this.tags = const [],
  });
}

// ── App Settings ─────────────────────────────────────────
class AppSettings {
  String company;
  String address;
  String bp;
  String rccm;
  String regime;
  String tel;
  String email;
  String prefix;
  String startNum;
  double tva;
  String conditions;

  AppSettings({
    required this.company, required this.address, required this.bp,
    required this.rccm, required this.regime, required this.tel,
    required this.email, required this.prefix,
    required this.startNum, required this.tva, required this.conditions,
  });

  /// Ligne légale affichée en pied de page des documents.
  String get footerLine =>
      '$company $address - $bp - RCCM: $rccm '
      'Régime d\'imposition $regime - Tel: $tel - Email: $email';
}

// ── Document Line Item ───────────────────────────────────
class LineItem {
  String ref;
  String designation;
  int qte;
  double pu;

  LineItem({required this.ref, required this.designation, required this.qte, required this.pu});

  double get total => qte * pu;
}

// ── Dépense (comptabilité) ───────────────────────────────
class Expense {
  final int id;
  DateTime date;
  String label;
  double amount;
  String category;
  String? factureNumero; // null = dépense générale

  Expense({
    required this.id, required this.date, required this.label,
    required this.amount, required this.category, this.factureNumero,
  });

  static const categories = [
    'Achat matériel', 'Transport', 'Sous-traitance',
    'Loyer & charges', 'Salaires', 'Autre',
  ];
}

// ── Nav Screen enum ──────────────────────────────────────
enum NavScreen {
  dashboard, documents, clients, projets, suivi, activites, rapports, parametres, gantt, documentCreate,
}
