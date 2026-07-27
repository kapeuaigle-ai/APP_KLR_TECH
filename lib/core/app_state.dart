import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';
import 'data.dart';
import 'theme.dart';
import 'comptabilite.dart';
import 'utils.dart';
import 'persistence.dart';

class AppState extends ChangeNotifier {
  NavScreen _screen = NavScreen.dashboard;
  String _docType = 'proforma';
  bool _creating = false;

  late List<Client> clients;
  late Map<String, List<DocumentItem>> documents;
  late AppSettings settings;
  late List<Task> tasks;
  late List<Note> notes;
  late List<Engagement> engagements;
  late List<Expense> expenses;
  late List<ActivityItem> activities;
  final Set<String> _dimePaidMonths = {};
  final Map<String, String> _dimePaidDates = {};

  /// Dernier mois vu par l'app — sert à détecter le passage au mois suivant.
  String _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
  /// Les activités générées par l'app se numérotent au-dessus des ids métier.
  int _nextActivityId = 1000;

  // ── Persistance ────────────────────────────────────────
  final Store _store;
  /// Vrai pendant le chargement/réinitialisation : bloque les écritures pour
  /// ne pas réécrire ce qu'on vient juste de lire.
  bool _restoring = false;
  /// File d'écriture : chaînée pour préserver l'ordre et éviter les courses.
  Future<void> _writeChain = Future.value();

  AppState({Store? store}) : _store = store ?? const NoopStore() {
    _seed();
  }

  /// État de départ (premier lancement) : données d'exemple, fil d'activité
  /// vide. Réutilisé tel quel par la réinitialisation.
  void _seed() {
    clients = List.from(SampleData.clients);
    documents = {
      'proforma': List.from(SampleData.documents['proforma']!),
      'facture': List.from(SampleData.documents['facture']!),
      'bl': List.from(SampleData.documents['bl']!),
    };
    settings = AppSettings(
      company: 'KLR TECH SARL',
      address: 'Abidjan Riviera 2 Lot 128 ilot 307',
      bp: '28 BP 994 Abidjan 28',
      rccm: 'CI-ABJ-03-2021-B1308160',
      regime: 'TEE',
      tel: '0708714557',
      email: 'klr.tech8@gmail.com',
      prefix: 'KLR',
      startNum: '01',
      tva: 5,
      conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
    );
    tasks = SampleData.initialTasks;
    notes = SampleData.initialNotes;
    engagements = SampleData.initialEngagements;
    expenses = List.from(SampleData.initialExpenses);
    activities = [];
    _dimePaidMonths.clear();
    _dimePaidDates.clear();
    _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
    _nextActivityId = 1000;
  }

  /// Charge la sauvegarde si elle existe, puis rattrape les clôtures des mois
  /// écoulés depuis la dernière ouverture. À appeler une fois au démarrage.
  Future<void> init() async {
    final raw = await _store.read();
    if (raw != null) {
      try {
        loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Sauvegarde illisible : on garde le seed déjà en place.
      }
    }
    verifierCloture();
  }

  /// Vide toutes les données métier — clients, documents, engagements,
  /// dépenses, tâches, notes, activités.
  ///
  /// Les RÉGLAGES sont conservés (entreprise, numérotation, conditions,
  /// garantie, signature, accès) : ils relèvent de la configuration, pas des
  /// données. Le manager repart d'une application vierge sans avoir à tout
  /// reparamétrer ni à retrouver son mot de passe.
  void _clearData() {
    clients = [];
    documents = {'proforma': [], 'facture': [], 'bl': []};
    tasks = [];
    notes = [];
    engagements = [];
    expenses = [];
    activities = [];
    _dimePaidMonths.clear();
    _dimePaidDates.clear();
    _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
    _nextActivityId = 1000;
  }

  /// Réinitialise l'application : plus aucune donnée de démonstration.
  ///
  /// L'état vide est ÉCRIT sur le disque (et non simplement effacé) : sans
  /// cela, le prochain démarrage ne trouverait pas de sauvegarde et
  /// réafficherait les données d'exemple semées au constructeur.
  Future<void> resetData() async {
    _clearData();
    notifyListeners();
    _persist();
    await flush();
  }

  // ── Sérialisation ──────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'clients': clients.map((c) => c.toJson()).toList(),
    'documents': {
      for (final k in documents.keys) k: documents[k]!.map((d) => d.toJson()).toList(),
    },
    'engagements': engagements.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'activities': activities.map((a) => a.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'settings': settings.toJson(),
    'dimePaidMonths': _dimePaidMonths.toList(),
    'dimePaidDates': _dimePaidDates,
    'moisCourant': _moisCourant,
    'nextActivityId': _nextActivityId,
  };

  void loadFromJson(Map<String, dynamic> j) {
    _restoring = true;
    clients = (j['clients'] as List).map((e) => Client.fromJson(e)).toList();
    final docs = (j['documents'] as Map).cast<String, dynamic>();
    documents = {
      'proforma': (docs['proforma'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
      'facture': (docs['facture'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
      'bl': (docs['bl'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
    };
    engagements = (j['engagements'] as List).map((e) => Engagement.fromJson(e)).toList();
    expenses = (j['expenses'] as List).map((e) => Expense.fromJson(e)).toList();
    activities = (j['activities'] as List).map((e) => ActivityItem.fromJson(e)).toList();
    tasks = (j['tasks'] as List).map((e) => Task.fromJson(e)).toList();
    notes = (j['notes'] as List).map((e) => Note.fromJson(e)).toList();
    settings = AppSettings.fromJson((j['settings'] as Map).cast<String, dynamic>());
    _dimePaidMonths
      ..clear()
      ..addAll((j['dimePaidMonths'] as List).cast<String>());
    _dimePaidDates
      ..clear()
      ..addAll((j['dimePaidDates'] as Map).cast<String, String>());
    _moisCourant = j['moisCourant'] ?? _moisCourant;
    _nextActivityId = j['nextActivityId'] ?? _nextActivityId;
    _restoring = false;
  }

  /// Écrit l'état courant sur le store. Fire-and-forget, mais chaîné : la
  /// dernière écriture programmée porte l'état le plus récent.
  void _persist() {
    if (_restoring) return;
    final data = jsonEncode(toJson());
    _writeChain = _writeChain.then((_) => _store.write(data)).catchError((_) {});
  }

  /// Attend la fin des écritures en attente (utilisé par les tests).
  Future<void> flush() => _writeChain;

  /// Notifie l'UI ET persiste : à utiliser pour toute mutation de données.
  void _emit() {
    notifyListeners();
    _persist();
  }

  NavScreen get screen => _screen;
  String get docType => _docType;
  bool get creating => _creating;
  Set<String> get dimePaidMonths => _dimePaidMonths;
  Map<String, String> get dimePaidDates => _dimePaidDates;
  String get moisCourant => _moisCourant;

  // Navigation et bascules d'UI : état volatil, pas de persistance.
  void navigate(NavScreen s) {
    _screen = s;
    _creating = false;
    verifierCloture();
    notifyListeners();
  }

  void setDocType(String t) { _docType = t; notifyListeners(); }
  void setCreating(bool v) {
    _creating = v;
    if (!v) _editingProforma = null; // sortie de l'écran : on quitte l'édition
    notifyListeners();
  }

  /// Proforma en cours de modification, `null` en création. Volatil : c'est un
  /// état d'écran, pas une donnée.
  DocumentItem? _editingProforma;
  DocumentItem? get editingProforma => _editingProforma;

  /// Ouvre l'écran document sur une proforma existante, pour la modifier.
  void startEditProforma(DocumentItem doc) {
    _editingProforma = doc;
    _creating = true;
    notifyListeners();
  }

  // ── Activités ──────────────────────────────────────────
  void _logActivity(String type, String titre, String desc, Color color,
      {String? quand}) {
    activities.insert(0, ActivityItem(
      id: _nextActivityId++,
      type: type, titre: titre, desc: desc,
      auteur: settings.company, initiales: settings.prefix,
      time: quand ?? Fmt.jour(DateTime.now()),
      color: color,
    ));
  }

  // ── Clients ────────────────────────────────────────────
  void addClient(Client c) {
    clients.add(c);
    _logActivity('client', 'Nouveau client — ${c.name}',
        c.contact.isNotEmpty ? c.contact : c.email, AppColors.blue);
    _emit();
  }

  void updateClient(Client c) {
    final idx = clients.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      clients[idx] = c;
      _logActivity('client', 'Client modifié — ${c.name}', c.email, AppColors.blue);
      _emit();
    }
  }

  void deleteClient(int id) {
    final match = clients.where((x) => x.id == id);
    final nom = match.isNotEmpty ? match.first.name : '—';
    clients.removeWhere((x) => x.id == id);
    _logActivity('client', 'Client supprimé — $nom', '', AppColors.text3);
    _emit();
  }

  // ── Engagements : dettes & créances ────────────────────
  void addEngagement(Engagement e) {
    engagements.insert(0, e);
    _emit();
  }

  void deleteEngagement(int id) {
    engagements.removeWhere((e) => e.id == id);
    _emit();
  }

  /// Valide un engagement : la créance est encaissée, la dette est payée.
  /// C'est ce geste qui le fait entrer en comptabilité — au mois de `date`,
  /// en revenu pour une créance, en dépense pour une dette.
  void validerEngagement(int id, String date) {
    final match = engagements.where((e) => e.id == id);
    if (match.isEmpty) return;
    final e = match.first;
    e.statut = 'paye';
    e.dateReglement = date;
    // Avec un acompte, seul le solde entre ici : l'acompte a déjà été compté
    // au mois de son versement.
    _logActivity(
      'paiement',
      e.estCreance
          ? 'Créance encaissée — ${Fmt.money(e.montantAuReglement)}'
          : 'Dette payée — ${Fmt.money(e.montantAuReglement)}',
      e.aAcompte
          ? '${e.tiers} · ${e.num} — solde le $date (acompte ${Fmt.money(e.acompte)} déjà compté)'
          : '${e.tiers} · ${e.num} — entrée en comptabilité le $date',
      e.estCreance ? AppColors.green : AppColors.orange,
    );
    _emit();
  }

  /// Enregistre (ou corrige) l'acompte déjà versé sur un engagement en cours.
  /// L'acompte entre en comptabilité au mois de `date` ; le solde suivra à la
  /// validation. Un montant nul ou négatif retire l'acompte.
  void setAcompte(int id, double montant, String date) {
    final match = engagements.where((e) => e.id == id);
    if (match.isEmpty) return;
    final e = match.first;

    if (montant <= 0) {
      e.acompte = 0;
      e.dateAcompte = null;
      _emit();
      return;
    }
    // Un acompte ne peut pas dépasser le montant de l'engagement.
    e.acompte = montant > e.montant ? e.montant : montant;
    e.dateAcompte = date;
    _logActivity(
      'paiement',
      e.estCreance
          ? 'Acompte encaissé — ${Fmt.money(e.acompte)}'
          : 'Acompte versé — ${Fmt.money(e.acompte)}',
      '${e.tiers} · ${e.num} — reste ${Fmt.money(e.reste)}',
      e.estCreance ? AppColors.green : AppColors.orange,
    );
    _emit();
  }

  /// Annule la validation : l'engagement ressort de la comptabilité.
  void annulerValidationEngagement(int id) {
    final match = engagements.where((e) => e.id == id);
    if (match.isEmpty) return;
    match.first.statut = 'cours';
    match.first.dateReglement = null;
    _emit();
  }

  // ── Clôture mensuelle ──────────────────────────────────
  /// Archive dans Activités le bilan de chaque mois écoulé, puis bascule la
  /// Comptabilité sur le mois suivant.
  ///
  /// Appelée au démarrage (après chargement) et à chaque navigation. Avec la
  /// persistance, `_moisCourant` est restauré depuis la sauvegarde : les mois
  /// passés pendant que l'app était fermée sont donc rattrapés au lancement.
  /// `maintenant` n'est là que pour les tests.
  void verifierCloture({DateTime? maintenant}) {
    final now = maintenant ?? DateTime.now();
    final aClore = Comptabilite.moisAClore(_moisCourant, now);
    if (aClore.isEmpty) return;

    final rows = Comptabilite.bilanMensuel(documents['facture'] ?? [],
        expenses, engagements, _dimePaidMonths, _dimePaidDates);

    // Du plus ancien au plus récent, mais insérées en tête : on parcourt à
    // l'envers pour que le mois le plus récent finisse en haut du fil.
    for (final k in aClore.reversed) {
      final r = Comptabilite.ligneMois(k, rows);
      if (r == null) continue; // mois sans aucun mouvement : rien à archiver
      _logActivity(
        'comptabilite',
        'Comptabilité clôturée — ${r.label}',
        'Revenu ${Fmt.money(r.revenuHt)} · Dépenses ${Fmt.money(r.depenses)} · '
        'Bénéfice ${Fmt.money(r.benefice)} · Dîme ${Fmt.money(r.dime)}',
        AppColors.emerald,
        quand: Fmt.jour(now),
      );
    }

    _moisCourant = Comptabilite.monthKeyFromDate(now);
    _emit();
  }

  // ── Tâches ─────────────────────────────────────────────
  void toggleTask(int id) {
    final t = tasks.firstWhere((x) => x.id == id);
    t.done = !t.done;
    _emit();
  }

  void deleteTask(int id) {
    tasks.removeWhere((x) => x.id == id);
    _emit();
  }

  void addTask(Task t) {
    tasks.add(t);
    _emit();
  }

  // ── Notes ──────────────────────────────────────────────
  void saveNote(Note n) {
    final idx = notes.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      notes[idx] = n;
    } else {
      notes.add(n);
    }
    _emit();
  }

  void deleteNote(int id) {
    notes.removeWhere((x) => x.id == id);
    _emit();
  }

  // ── Paramètres ─────────────────────────────────────────
  void updateSettings(AppSettings s) {
    settings = s;
    _emit();
  }

  // ── Connexion ──────────────────────────────────────────
  /// État volatil : jamais persisté, l'app redemande donc les accès à chaque
  /// démarrage.
  bool _authenticated = false;
  bool get authenticated => _authenticated;

  /// Vérifie les accès saisis. Retourne false si l'identifiant ou le mot de
  /// passe ne correspond pas (message unique côté écran : ne pas indiquer
  /// lequel des deux est faux).
  bool login(String username, String password) {
    final ok = username.trim().toLowerCase() == settings.username.toLowerCase() &&
        settings.checkPassword(password);
    if (ok) {
      _authenticated = true;
      notifyListeners();
    }
    return ok;
  }

  void logout() {
    _authenticated = false;
    _screen = NavScreen.dashboard;
    _creating = false;
    notifyListeners();
  }

  /// Change l'identifiant et/ou le mot de passe. Retourne false si le mot de
  /// passe actuel est faux — dans ce cas rien n'est modifié.
  bool changeCredentials({
    required String currentPassword,
    String? newUsername,
    String? newPassword,
  }) {
    if (!settings.checkPassword(currentPassword)) return false;
    if (newUsername != null && newUsername.trim().isNotEmpty) {
      settings.username = newUsername.trim();
    }
    if (newPassword != null && newPassword.isNotEmpty) {
      settings.setPassword(newPassword);
    }
    _emit();
    return true;
  }

  // ── Documents ──────────────────────────────────────────
  void addDocument(String type, DocumentItem doc) {
    documents[type]?.add(doc);
    if (type == 'proforma') {
      _logActivity('document', 'Proforma ${doc.numero} créée',
          '${doc.client} — ${Fmt.money(doc.montant)}', AppColors.primary);
    }
    _emit();
  }

  /// Enregistre une proforma générée depuis l'écran de création, ou met à jour
  /// celle déjà enregistrée dans la même session (même id) sans la dupliquer ni
  /// re-journaliser. C'est ce geste qui « consomme » le numéro du jour : générer
  /// le PDF (télécharger/imprimer) ou cliquer Enregistrer passe par ici.
  void saveOrUpdateProforma(DocumentItem doc) {
    final list = documents['proforma']!;
    final idx = list.indexWhere((d) => d.id == doc.id);
    if (idx >= 0) {
      list[idx] = doc; // même document : on rafraîchit son contenu
    } else {
      list.add(doc);
      _logActivity('document', 'Proforma ${doc.numero} créée',
          '${doc.client} — ${Fmt.money(doc.montant)}', AppColors.primary);
    }
    _emit();
  }

  void setDocumentStatus(String type, int id, String statut) {
    final doc = documents[type]?.where((d) => d.id == id);
    if (doc != null && doc.isNotEmpty) {
      doc.first.statut = statut;
      _emit();
    }
  }

  /// Valide une proforma : elle devient une offre acceptée, et la facture
  /// et le bon de livraison associés sont générés automatiquement avec le
  /// même numéro et les mêmes informations. Retourne true si la facture et
  /// le BL ont été créés (false s'ils existaient déjà).
  bool validateProforma(int id) {
    final matches = documents['proforma']!.where((d) => d.id == id);
    if (matches.isEmpty) return false;
    final p = matches.first;
    p.statut = 'validee';

    // Facture et BL appariés à la proforma : même compteur + date, lettre P→F/B.
    final factureNum = DocNumero.retype(p.numero, 'facture');
    final blNum = DocNumero.retype(p.numero, 'bl');
    // Anti-doublon sur les deux générations de numérotation : les proformas
    // validées avant la refonte ont produit une facture au numéro identique
    // (p.numero), les nouvelles une facture au numéro décliné (factureNum).
    final alreadyGenerated = documents['facture']!
        .any((d) => d.numero == factureNum || d.numero == p.numero);
    if (!alreadyGenerated) {
      final now = DateTime.now().millisecondsSinceEpoch;
      documents['facture']!.add(DocumentItem(
        id: now, numero: factureNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: p.montant, statut: 'cours',
        lines: p.lines,
      ));
      // Le BL ne porte aucun montant.
      documents['bl']!.add(DocumentItem(
        id: now + 1, numero: blNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: 0, statut: 'cours',
        lines: p.lines,
      ));
      _logActivity('facture', 'Proforma ${p.numero} validée',
          'Facture et BL générés — ${p.client}', AppColors.primary);
    }
    _emit();
    return !alreadyGenerated;
  }

  // ── Comptabilité : dépenses ────────────────────────────
  void addExpense(Expense e) {
    expenses.add(e);
    _logActivity('comptabilite', 'Dépense — ${e.label}',
        '${e.category} · ${Fmt.money(e.amount)}', AppColors.red);
    _emit();
  }

  void deleteExpense(int id) {
    expenses.removeWhere((e) => e.id == id);
    _emit();
  }

  // ── Comptabilité : encaissement des factures ───────────
  void setFactureEncaissee(int id, bool encaissee, {String? date}) {
    final f = documents['facture']?.where((d) => d.id == id);
    if (f != null && f.isNotEmpty) {
      f.first.encaissee = encaissee;
      f.first.dateEncaissement = encaissee ? date : null;
      _emit();
    }
  }

  // ── Comptabilité : versement de la dîme ────────────────
  void setDimePaid(String monthKey, bool paid, {String? date}) {
    if (paid) {
      _dimePaidMonths.add(monthKey);
      if (date != null) _dimePaidDates[monthKey] = date;
    } else {
      _dimePaidMonths.remove(monthKey);
      _dimePaidDates.remove(monthKey);
    }
    _emit();
  }
}
