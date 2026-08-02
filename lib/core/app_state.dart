import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';
import 'data.dart';
import 'theme.dart';
import 'comptabilite.dart';
import 'utils.dart';
import 'persistence.dart';
import 'migration.dart';

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
  late List<ActivityItem> activities;
  final Set<String> _dimePaidMonths = {};
  final Map<String, String> _dimePaidDates = {};

  /// Dernier mois vu par l'app — sert à détecter le passage au mois suivant.
  String _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
  /// Les activités générées par l'app se numérotent au-dessus des ids métier.
  int _nextActivityId = 1000;
  /// Compteur pour les ids de règlement : une horloge de départ, ensuite
  /// simplement incrémentée. Un nouvel horodatage à chaque appel collisionne
  /// dès que deux règlements sont ajoutés coup sur coup, la résolution de
  /// l'horloge n'étant pas garantie à la microseconde près.
  int _nextReglementId = DateTime.now().microsecondsSinceEpoch;

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
    engagements = [
      ...SampleData.initialEngagements,
      ...SampleData.initialEngagementsSortants,
    ];
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
  /// tâches, notes, activités.
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
    'activities': activities.map((a) => a.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'settings': settings.toJson(),
    'dimePaidMonths': _dimePaidMonths.toList(),
    'dimePaidDates': _dimePaidDates,
    'moisCourant': _moisCourant,
    'nextActivityId': _nextActivityId,
    'version': 2,
  };

  void loadFromJson(Map<String, dynamic> brut) {
    // Capturé avant conversion : `migrerV1versV2` rend `brut` inchangé s'il
    // est déjà en v2 (`j['version'] == 2`), donc c'est le seul moment où l'on
    // peut encore distinguer « rien à migrer » de « migration effectuée ».
    final migration = brut['version'] != 2;
    if (migration) {
      // Filet de sécurité (spec § 8) : la sauvegarde v1 brute est conservée
      // avant toute réécriture, pour que la conversion reste réversible en
      // cas d'anomalie découverte tardivement. Fire-and-forget, comme
      // `_persist` : une erreur d'écriture ne doit jamais empêcher
      // l'application de démarrer.
      _writeChain = _writeChain
          .then((_) => _store.writeBackup(jsonEncode(brut)))
          .catchError((_) {});
    }
    final j = migrerV1versV2(brut);
    // La migration marque les rapprochements incertains (§ 8.1 de la spec) :
    // on les retire du JSON — ils ne doivent pas être persistés — et on les
    // journalise pour que le manager puisse les vérifier.
    final ambigus = <String>[];
    for (final e in (j['engagements'] as List).cast<Map<String, dynamic>>()) {
      if (e.remove('fusionAmbigue') == true) {
        ambigus.add('${e['tiers']} · ${e['documentNumero']}');
      }
    }
    _restoring = true;
    clients = (j['clients'] as List).map((e) => Client.fromJson(e)).toList();
    final docs = (j['documents'] as Map).cast<String, dynamic>();
    documents = {
      'proforma': (docs['proforma'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
      'facture': (docs['facture'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
      'bl': (docs['bl'] as List? ?? []).map((e) => DocumentItem.fromJson(e)).toList(),
    };
    engagements = (j['engagements'] as List).map((e) => Engagement.fromJson(e)).toList();
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

    for (final a in ambigus) {
      _logActivity(
        'comptabilite',
        'Rapprochement à vérifier',
        '$a — une créance saisie à la main a été rattachée à cette facture '
        'sur la seule concordance du client et du montant.',
        AppColors.orange,
      );
    }

    // La conversion v1 → v2 (et les activités de rapprochement ci-dessus) ne
    // doivent pas rester seulement en mémoire : `_logActivity` n'appelle pas
    // `_emit()`, donc sans cet appel explicite le fichier resterait en v1
    // jusqu'à la prochaine mutation, et la migration se répéterait à chaque
    // démarrage. Rien à écrire si la sauvegarde était déjà en v2.
    if (migration) _persist();
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

  /// Vide toutes les données. Exposé pour les tests, qui ont besoin d'un état
  /// nu sans passer par le jeu de démonstration.
  void viderDonnees() {
    _clearData();
    notifyListeners();
  }

  int _prochainId() => _nextReglementId++;

  Engagement? _engagement(int id) {
    final m = engagements.where((e) => e.id == id);
    return m.isEmpty ? null : m.first;
  }

  /// Enregistre un mouvement d'argent réel sur un engagement.
  ///
  /// C'est le SEUL geste qui fait entrer une somme en comptabilité, au mois de
  /// `date`. Un montant nul, un engagement annulé ou déjà soldé sont refusés
  /// en silence ; un montant supérieur au reste dû est écrêté.
  void ajouterReglement(int engagementId, double montant, DateTime date,
      {String moyen = 'especes'}) {
    final e = _engagement(engagementId);
    if (e == null || e.annule || montant <= 0 || e.reste <= 0) return;

    final effectif = montant > e.reste ? e.reste : montant;
    e.reglements.add(Reglement(
      id: _prochainId(), date: date, montant: effectif, moyen: moyen));

    _logActivity(
      'paiement',
      e.estEntrant
          ? 'Encaissement — ${Fmt.money(effectif)}'
          : 'Décaissement — ${Fmt.money(effectif)}',
      // La date du règlement, et non celle de la saisie : c'est elle qui
      // décide du mois d'imputation en comptabilité de caisse. L'horodatage
      // de l'activité, lui, est celui du jour où l'on saisit.
      e.solde
          ? '${e.tiers} — soldé le ${Fmt.jour(date)}'
          : '${e.tiers} — ${Fmt.money(effectif)} le ${Fmt.jour(date)}, reste ${Fmt.money(e.reste)}',
      e.estEntrant ? AppColors.green : AppColors.orange,
    );
    _emit();
  }

  /// Retire un règlement : la somme ressort de la comptabilité.
  void supprimerReglement(int engagementId, int reglementId) {
    final e = _engagement(engagementId);
    if (e == null) return;
    e.reglements.removeWhere((r) => r.id == reglementId);
    _emit();
  }

  /// Annule un engagement : il sort des montants attendus, et n'accepte plus
  /// de règlement. Les règlements déjà passés restent en comptabilité — ils
  /// ont réellement eu lieu.
  void annulerEngagement(int id) {
    final e = _engagement(id);
    if (e == null) return;
    e.annule = true;
    _emit();
  }

  void reactiverEngagement(int id) {
    final e = _engagement(id);
    if (e == null) return;
    e.annule = false;
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

    final rows = Comptabilite.bilanMensuel(
        engagements, _dimePaidMonths, _dimePaidDates);

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
        projetId: p.projetId,
        // Copie profonde : chaque document possède ses lignes. Le partage
        // d'instances ne survivrait pas à un rechargement depuis le disque.
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
      // Le BL ne porte aucun montant.
      documents['bl']!.add(DocumentItem(
        id: now + 1, numero: blNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: 0, statut: 'cours',
        projetId: p.projetId,
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
      // La facture EST une créance sur le client : l'engagement naît du même
      // geste, pour qu'aucune saisie manuelle ne puisse le dédoubler.
      engagements.insert(0, Engagement(
        id: now + 2,
        sens: 'entrant',
        projetId: p.projetId,
        documentNumero: factureNum,
        clientId: p.clientId,
        tiers: p.client,
        description: p.objet,
        montant: p.lines.fold(0.0, (s, l) => s + l.total),
        echeance: Comptabilite.parseJour(p.date) ?? DateTime.now(),
      ));
      _logActivity('facture', 'Proforma ${p.numero} validée',
          'Facture et BL générés — ${p.client}', AppColors.primary);
    }
    _emit();
    return !alreadyGenerated;
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
