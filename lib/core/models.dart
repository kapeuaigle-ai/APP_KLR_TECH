import 'package:flutter/material.dart';
import 'auth.dart';

/// Encodage couleur ⇄ entier ARGB, pour la persistance JSON.
int colorToInt(Color c) => c.toARGB32();
Color colorFromInt(int v) => Color(v);

/// Conversion JSON → double. Défini au niveau bibliothèque car la classe
/// Engagement possède un champ `num` qui masque le type `num` dans son corps.
double _toDouble(dynamic v) => (v as num).toDouble();

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
  final String address;

  const Client({
    required this.id, required this.initials, required this.color,
    required this.name, required this.contact, required this.email,
    required this.phone, required this.totalFacture,
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'initials': initials, 'color': colorToInt(color), 'name': name,
    'contact': contact, 'email': email, 'phone': phone,
    'totalFacture': totalFacture, 'address': address,
  };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'], initials: j['initials'], color: colorFromInt(j['color']),
    name: j['name'], contact: j['contact'], email: j['email'], phone: j['phone'],
    totalFacture: (j['totalFacture'] as num).toDouble(), address: j['address'] ?? '',
  );
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
  /// Date telle qu'elle apparaît SUR le document (saisie libre par le manager).
  /// Distincte de [date], qui reste la date de création et sert au compteur
  /// journalier de la numérotation. Vide = aucune date imprimée.
  String dateAffichee;
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
    this.dateAffichee = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'numero': numero, 'date': date, 'clientId': clientId,
    'client': client, 'clientAddr': clientAddr, 'objet': objet,
    'montant': montant, 'statut': statut,
    'lines': lines.map((l) => l.toJson()).toList(),
    'encaissee': encaissee, 'dateEncaissement': dateEncaissement,
    'dateAffichee': dateAffichee,
  };

  factory DocumentItem.fromJson(Map<String, dynamic> j) => DocumentItem(
    id: j['id'], numero: j['numero'], date: j['date'], clientId: j['clientId'],
    client: j['client'], clientAddr: j['clientAddr'] ?? '', objet: j['objet'],
    montant: (j['montant'] as num).toDouble(), statut: j['statut'],
    lines: (j['lines'] as List? ?? []).map((l) => LineItem.fromJson(l)).toList(),
    encaissee: j['encaissee'] ?? false, dateEncaissement: j['dateEncaissement'],
    dateAffichee: j['dateAffichee'] ?? '',
  );
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

// ── Engagement : dette ou créance ────────────────────────
/// Ce que l'entreprise doit (dette) ou ce qu'on lui doit (créance).
///
/// Tant qu'il est en cours, un engagement reste hors comptabilité : seule
/// sa validation (= encaissement d'une créance, paiement d'une dette) le
/// fait entrer au bilan, dans le mois de son règlement — la comptabilité
/// de l'app étant tenue en base caisse.
class Engagement {
  final int id;
  final String sens;   // 'creance' (on nous doit) | 'dette' (nous devons)
  final String num;    // référence libre (n° de facture, de contrat…)
  final String tiers;  // débiteur pour une créance, créancier pour une dette
  final String description; // objet de l'engagement, affiché sous le tiers
  final double montant;
  String statut;       // 'cours' | 'retard' | 'paye'
  final String echeance;     // 'dd/MM/yyyy'
  String? dateReglement;     // 'dd/MM/yyyy' — rempli à la validation
  final String categorie;    // catégorie de dépense (dettes)
  /// Acompte déjà encaissé (créance) ou déjà versé (dette).
  double acompte;
  /// Date de l'acompte, 'dd/MM/yyyy'. C'est à ce mois-là que l'acompte entre
  /// en comptabilité, la tenue étant en base caisse.
  String? dateAcompte;

  Engagement({
    required this.id, required this.sens, required this.num,
    required this.tiers, required this.montant, required this.statut,
    required this.echeance, this.description = '',
    this.dateReglement, this.categorie = 'Autres',
    this.acompte = 0, this.dateAcompte,
  });

  bool get estCreance => sens == 'creance';

  /// Validé ET daté : les deux conditions pour compter en comptabilité.
  bool get regle => statut == 'paye' && dateReglement != null;

  /// Acompte réellement pris en compte : il lui faut un montant ET une date,
  /// sans quoi on ne saurait pas à quel mois le rattacher.
  bool get aAcompte => acompte > 0 && dateAcompte != null;

  /// Solde restant dû après déduction de l'acompte.
  double get reste {
    final r = montant - acompte;
    return r < 0 ? 0 : r;
  }

  /// Part qui entre en comptabilité à la validation : le solde seulement,
  /// l'acompte ayant déjà été compté au mois où il a été versé.
  double get montantAuReglement => aAcompte ? reste : montant;

  Map<String, dynamic> toJson() => {
    'id': id, 'sens': sens, 'num': num, 'tiers': tiers,
    'description': description, 'montant': montant, 'statut': statut,
    'echeance': echeance, 'dateReglement': dateReglement, 'categorie': categorie,
    'acompte': acompte, 'dateAcompte': dateAcompte,
  };

  factory Engagement.fromJson(Map<String, dynamic> j) => Engagement(
    id: j['id'], sens: j['sens'], num: j['num'], tiers: j['tiers'],
    description: j['description'] ?? '', montant: _toDouble(j['montant']),
    statut: j['statut'], echeance: j['echeance'], dateReglement: j['dateReglement'],
    categorie: j['categorie'] ?? 'Autres',
    // Rétro-compatible : engagements enregistrés avant les acomptes.
    acompte: j['acompte'] == null ? 0 : _toDouble(j['acompte']),
    dateAcompte: j['dateAcompte'],
  );
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

/// Clause de garantie par défaut, affichée en bas de la dernière page des
/// documents. Éditable dans les Paramètres (`AppSettings.warranty`) ; sert
/// aussi de valeur de repli pour les anciennes sauvegardes et la pagination.
const kDefaultWarranty =
    'Tout produit, sauf mention contraire, bénéficie d\'une période de garantie '
    'contre tout vice de fabrication (retour atelier sans frais de réparation ou '
    'échange standard dans la limite des stocks disponibles) soumise à '
    'l\'expertise constructeur, à compter de la date de facturation et à '
    'condition qu\'il soit tenu en bon état et que les étiquettes de code '
    'ne soient pas retirées ou déchirées.';

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
  /// Signature électronique du manager, image PNG encodée en base64.
  /// Vide = aucune signature : la case du document reste alors vierge.
  String signature;
  /// Légende libre affichée sous la signature (ex. « La Direction »).
  String signatureLabel;
  /// Clause de garantie affichée en bas de la dernière page. Personnalisable.
  String warranty;

  // ── Accès à l'application ──────────────────────────────
  /// Identifiant de connexion du manager.
  String username;
  /// Sel du mot de passe. Vide tant que le mot de passe par défaut est en place.
  String passwordSalt;
  /// Empreinte SHA-256 salée. Le mot de passe en clair n'est jamais conservé.
  String passwordHash;

  AppSettings({
    required this.company, required this.address, required this.bp,
    required this.rccm, required this.regime, required this.tel,
    required this.email, required this.prefix,
    required this.startNum, required this.tva, required this.conditions,
    this.signature = '', this.signatureLabel = '',
    this.warranty = kDefaultWarranty,
    this.username = kDefaultUsername,
    this.passwordSalt = '', this.passwordHash = '',
  });

  /// Vrai tant que le manager n'a pas défini son propre mot de passe : l'app
  /// accepte alors l'accès d'usine et affiche une alerte dans les Paramètres.
  bool get usesDefaultPassword => passwordHash.isEmpty;

  /// Vérifie un mot de passe saisi. Tant qu'aucun mot de passe n'a été défini,
  /// seul l'accès par défaut est accepté.
  bool checkPassword(String password) => usesDefaultPassword
      ? secureEquals(password, kDefaultPassword)
      : secureEquals(hashPassword(password, passwordSalt), passwordHash);

  /// Définit un nouveau mot de passe : nouveau sel, nouvelle empreinte.
  void setPassword(String password) {
    passwordSalt = newSalt();
    passwordHash = hashPassword(password, passwordSalt);
  }

  /// Ligne légale affichée en pied de page des documents.
  String get footerLine =>
      '$company $address - $bp - RCCM: $rccm '
      'Régime d\'imposition $regime - Tel: $tel - Email: $email';

  Map<String, dynamic> toJson() => {
    'company': company, 'address': address, 'bp': bp, 'rccm': rccm,
    'regime': regime, 'tel': tel, 'email': email, 'prefix': prefix,
    'startNum': startNum, 'tva': tva, 'conditions': conditions,
    'signature': signature, 'signatureLabel': signatureLabel,
    'warranty': warranty,
    'username': username,
    'passwordSalt': passwordSalt, 'passwordHash': passwordHash,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    company: j['company'], address: j['address'], bp: j['bp'], rccm: j['rccm'],
    regime: j['regime'], tel: j['tel'], email: j['email'], prefix: j['prefix'],
    startNum: j['startNum'], tva: (j['tva'] as num).toDouble(), conditions: j['conditions'],
    // Rétro-compatible : les sauvegardes antérieures n'ont pas ces clés.
    signature: j['signature'] ?? '', signatureLabel: j['signatureLabel'] ?? '',
    warranty: j['warranty'] ?? kDefaultWarranty,
    // Sauvegarde antérieure à la connexion : on repart de l'accès par défaut.
    username: j['username'] ?? kDefaultUsername,
    passwordSalt: j['passwordSalt'] ?? '', passwordHash: j['passwordHash'] ?? '',
  );
}

// ── Document Line Item ───────────────────────────────────
class LineItem {
  String ref;
  String designation;
  int qte;
  double pu;

  LineItem({required this.ref, required this.designation, required this.qte, required this.pu});

  double get total => qte * pu;

  Map<String, dynamic> toJson() => {
    'ref': ref, 'designation': designation, 'qte': qte, 'pu': pu,
  };

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    ref: j['ref'], designation: j['designation'], qte: j['qte'],
    pu: (j['pu'] as num).toDouble(),
  );
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

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'label': label,
    'amount': amount, 'category': category, 'factureNumero': factureNumero,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'], date: DateTime.parse(j['date']), label: j['label'],
    amount: (j['amount'] as num).toDouble(), category: j['category'],
    factureNumero: j['factureNumero'],
  );

  static const categories = [
    'Achat matériel', 'Transport', 'Sous-traitance',
    'Loyer & charges', 'Salaires', 'Autres',
  ];
}

// ── Nav Screen enum ──────────────────────────────────────
enum NavScreen {
  dashboard, documents, clients, projets, suivi, activites, rapports, parametres, gantt, documentCreate,
}
