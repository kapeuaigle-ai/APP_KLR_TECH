import 'dart:convert';
import 'package:flutter/material.dart';
import 'models.dart';
import 'data.dart';
import 'theme.dart';
import 'comptabilite.dart';
import 'utils.dart';
import 'persistence.dart';
import 'migration.dart';
import 'avancement.dart';

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
  late List<Projet> projets;
  final Set<String> _dimePaidMonths = {};
  final Map<String, String> _dimePaidDates = {};

  /// Dernier mois vu par l'app — sert à détecter le passage au mois suivant.
  String _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
  /// Les activités générées par l'app se numérotent au-dessus des ids métier.
  int _nextActivityId = 1000;
  /// Compteur UNIQUE pour tous les ids métier de l'application (engagements,
  /// règlements, clients, documents, projets, tâches, notes) — voir
  /// `nextId()`. Un simple entier croissant, jamais dérivé de l'horloge :
  /// `DateTime.now().millisecondsSinceEpoch` collisionne dès que plusieurs
  /// ids sont mintés dans la même milliseconde, ce qui arrive en pratique
  /// (résolution de l'horloge non garantie, boucles de saisie rapide) —
  /// défaut 2 de la revue Lot A. Valeur de secours ; `_seed()` et
  /// `loadFromJson` l'amènent tous deux au-dessus de tout id déjà en usage
  /// avant que quiconque puisse en réclamer un.
  int _nextId = 1;

  // ── Persistance ────────────────────────────────────────
  final Store _store;
  /// Vrai pendant le chargement/réinitialisation : bloque les écritures pour
  /// ne pas réécrire ce qu'on vient juste de lire.
  bool _restoring = false;
  /// File d'écriture : chaînée pour préserver l'ordre et éviter les courses.
  Future<void> _writeChain = Future.value();

  /// Vrai si le dernier `init()` a refusé la sauvegarde sur disque parce
  /// qu'elle porte une version plus récente que celle que sait lire cette
  /// version de l'application (voir `SauvegardeVersionRefuseeException`).
  /// Le fichier sur disque n'a PAS été touché ; l'application continue sur
  /// son état de démarrage (données d'exemple) plutôt que de deviner. L'UI
  /// lit ce drapeau pour avertir le manager au lieu de le laisser croire,
  /// silencieusement, qu'il regarde ses vraies données.
  bool sauvegardeRefusee = false;
  /// La version trouvée dans le fichier refusé, pour le message affiché.
  dynamic versionSauvegardeRefusee;

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
      conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
    );
    tasks = SampleData.initialTasks;
    notes = SampleData.initialNotes;
    engagements = [
      ...SampleData.initialEngagements,
      ...SampleData.initialEngagementsSortants,
    ];
    activities = [];
    projets = [];
    _dimePaidMonths.clear();
    _dimePaidDates.clear();
    _moisCourant = Comptabilite.monthKeyFromDate(DateTime.now());
    _nextActivityId = 1000;
    _seedNextId();
  }

  /// Charge la sauvegarde si elle existe, puis rattrape les clôtures des mois
  /// écoulés depuis la dernière ouverture. À appeler une fois au démarrage.
  Future<void> init() async {
    final raw = await _store.read();
    if (raw != null) {
      try {
        loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      } on SauvegardeVersionRefuseeException catch (e) {
        // Fichier refusé (défaut 1) : ni migré, ni écrit — voir
        // `sauvegardeRefusee`. On garde le seed déjà en place, et on
        // surface la situation pour que l'UI avertisse le manager au lieu
        // de continuer en silence sur des données de démonstration.
        sauvegardeRefusee = true;
        versionSauvegardeRefusee = e.versionTrouvee;
      } catch (_) {
        // Sauvegarde illisible : on garde le seed déjà en place.
      }
    }
    verifierCloture();
  }

  /// Prochain id métier, jamais réutilisé (voir `_nextId`).
  int nextId() => _nextId++;

  /// Amène `_nextId` au-dessus de tout id déjà présent dans l'état courant.
  ///
  /// [compteurPersiste] est le compteur déjà persisté (0 si aucun) : un
  /// fichier hérité peut avoir un compteur en avance sur le plus grand id
  /// visible (des enregistrements ont pu être supprimés depuis) — dans ce
  /// cas, c'est LUI qui fait foi, pas le maximum recalculé. Mais l'inverse
  /// compte plus : un fichier corrigé à la main ou fusionné dont les ids
  /// dépassent le compteur stocké ne doit JAMAIS faire redistribuer un id
  /// déjà pris — c'est ce recalcul par balayage qui le garantit,
  /// indépendamment de ce que dit le fichier.
  void _seedNextId([int compteurPersiste = 0]) {
    var maxId = compteurPersiste;
    void considerer(int id) {
      if (id > maxId) maxId = id;
    }
    for (final c in clients) {
      considerer(c.id);
    }
    for (final liste in documents.values) {
      for (final d in liste) {
        considerer(d.id);
      }
    }
    for (final e in engagements) {
      considerer(e.id);
      for (final r in e.reglements) {
        considerer(r.id);
      }
    }
    for (final p in projets) {
      considerer(p.id);
    }
    for (final t in tasks) {
      considerer(t.id);
    }
    for (final n in notes) {
      considerer(n.id);
    }
    // Les activités ont leur propre compteur (`_nextActivityId`, déjà
    // persisté correctement) — mais leurs ids partagent le même espace de
    // noms que tout le reste si jamais ils sont comparés ou affichés
    // ensemble ; on les inclut ici par prudence, même si `nextId()` ne leur
    // en distribue jamais.
    for (final a in activities) {
      considerer(a.id);
    }
    _nextId = maxId + 1;
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
    projets = [];
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
    'projets': projets.map((p) => p.toJson()).toList(),
    'tasks': tasks.map((t) => t.toJson()).toList(),
    'notes': notes.map((n) => n.toJson()).toList(),
    'settings': settings.toJson(),
    'dimePaidMonths': _dimePaidMonths.toList(),
    'dimePaidDates': _dimePaidDates,
    'moisCourant': _moisCourant,
    'nextActivityId': _nextActivityId,
    'nextId': _nextId,
    'version': kVersionSauvegarde,
  };

  void loadFromJson(Map<String, dynamic> brut) {
    // Routage par SEUIL, pas par égalité stricte (défaut 1, revue Lot A) :
    // une sauvegarde à la version v traverse chaque étape à partir de v, donc
    // < 2 traverse v1→v2→v3→v4, 2 traverse v2→v3→v4, etc. L'égalité stricte
    // prenait toute version inconnue (une v5 future, une chaîne "4", un champ
    // corrompu) pour un v1 brut, la détruisait, puis écrivait la destruction
    // sur le disque via `_persist()` plus bas.
    //
    // Absence de clé `version` = v1 : c'est réellement l'allure d'un vrai
    // fichier v1, jamais autre chose — le seul « inconnu » qu'il est sûr de
    // deviner. Toute AUTRE valeur qui n'est pas un entier reconnu (chaîne,
    // map, ou entier supérieur à la version courante) est REFUSÉE : on lève,
    // on ne migre rien, on n'écrit rien. Voir `SauvegardeVersionRefuseeException`.
    final versionOrigine = brut['version'];
    final int origine;
    if (versionOrigine == null) {
      origine = 1;
    } else if (versionOrigine is int) {
      if (versionOrigine > kVersionSauvegarde) {
        throw SauvegardeVersionRefuseeException(versionOrigine);
      }
      // Un entier aberrant (0, négatif) reste « en dessous de tout seuil
      // connu » — même traitement que l'absence de clé, chaîne complète.
      origine = versionOrigine < 1 ? 1 : versionOrigine;
    } else {
      // Un vrai fichier v1 n'a jamais cette clé du tout ; une valeur non
      // entière ne peut venir que d'une corruption. On ne la prend pas pour
      // du v1 sous prétexte qu'elle n'est « pas reconnue » — fail closed.
      throw SauvegardeVersionRefuseeException(versionOrigine);
    }

    final migration = origine != kVersionSauvegarde;
    // Le filet de sécurité (spec § 8) ne couvre que la conversion v1 → v2,
    // seule à restructurer des données au point de ne plus pouvoir les
    // reconstituer depuis la sauvegarde migrée (quatre mécanismes d'argent
    // fondus en Engagement + Reglement). v2 → v3 et v3 → v4 ne font que
    // recalculer/déplacer des champs à partir de données déjà présentes :
    // rien n'y est perdu, donc rien à sauvegarder à part.
    if (origine < 2) {
      // Filet de sécurité (spec § 8) : la sauvegarde v1 brute est conservée
      // avant toute réécriture, pour que la conversion reste réversible en
      // cas d'anomalie découverte tardivement. Fire-and-forget, comme
      // `_persist` : une erreur d'écriture ne doit jamais empêcher
      // l'application de démarrer.
      _writeChain = _writeChain
          .then((_) => _store.writeBackup(jsonEncode(brut)))
          .catchError((_) {});
    }
    // Chaînage à seuils : chaque étape ne s'exécute que si `origine` est
    // strictement en dessous de sa version cible. `j` garde la même
    // référence que `brut` si aucune étape ne s'exécute (v4 → round-trip
    // sans copie, condition du test « zéro écriture »).
    var j = brut;
    if (origine < 2) j = migrerV1versV2(j);
    if (origine < 3) j = migrerV2versV3(j);
    if (origine < 4) j = migrerV3versV4(j);
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
    projets = (j['projets'] as List? ?? []).map((e) => Projet.fromJson(e)).toList();
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
    // Recalculé par balayage, jamais simplement recopié : voir `_seedNextId`
    // — le compteur restauré ne suffit pas seul, une sauvegarde corrigée à
    // la main ou fusionnée peut porter des ids au-dessus de lui.
    final compteurPersiste = j['nextId'];
    _seedNextId(compteurPersiste is int ? compteurPersiste : 0);
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

  /// Supprime un client et délie tout ce qui le désignait : `clientId` est
  /// un `int?` (« null = aucun »), même convention que `projetId` — voir
  /// `deleteProjet`. Le nom dénormalisé (`Projet.client`, `Engagement.tiers`)
  /// reste : il enregistre qui était la contrepartie, l'id seul ne pointe
  /// plus vers rien.
  void deleteClient(int id) {
    final match = clients.where((x) => x.id == id);
    final nom = match.isNotEmpty ? match.first.name : '—';
    clients.removeWhere((x) => x.id == id);
    for (final p in projets) {
      if (p.clientId == id) p.clientId = null;
    }
    for (final e in engagements) {
      if (e.clientId == id) e.clientId = null;
    }
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
      id: nextId(), date: date, montant: effectif, moyen: moyen));

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

  /// Rattache (ou détache, si `projetId` est nul) un engagement existant à un
  /// projet. C'est le seul moyen de lier un engagement créé avant que son
  /// projet n'existe — la création elle-même propose déjà le choix.
  void rattacherProjetEngagement(int id, int? projetId) {
    final e = _engagement(id);
    if (e == null) return;
    e.projetId = projetId;
    _emit();
  }

  // ── Projets ────────────────────────────────────────────
  void addProjet(Projet p) {
    projets.insert(0, p);
    _logActivity('projet', 'Projet créé — ${p.nom}',
        p.client.isEmpty ? 'Projet interne' : p.client, AppColors.primary);
    _emit();
  }

  void updateProjet(Projet p) {
    final i = projets.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    projets[i] = p;
    _emit();
  }

  /// Annule un projet : il reste avec tout son historique, mais sort du
  /// Kanban et du Gantt (§ 6.4/7 de la conception) — même logique que
  /// `annulerEngagement`, appliquée à un projet plutôt qu'à un engagement.
  void annulerProjet(int id) {
    final p = _projet(id);
    if (p == null) return;
    p.annule = true;
    _emit();
  }

  void reactiverProjet(int id) {
    final p = _projet(id);
    if (p == null) return;
    p.annule = false;
    _emit();
  }

  /// Repousse la fin prévue d'un projet — l'action « Reporter l'échéance »
  /// du Kanban, qui fait sortir un projet d'« En révision » vers « En
  /// cours ». Refuse silencieusement une date antérieure au début, comme le
  /// formulaire de création/édition : `Projet.periodeValide` encode déjà
  /// cette règle, pas de comparaison de dates dupliquée ici.
  void reporterEcheance(int id, DateTime nouvelleFin) {
    final p = _projet(id);
    if (p == null) return;
    final ancienneFin = p.finPrevue;
    p.finPrevue = nouvelleFin;
    if (!p.periodeValide) {
      p.finPrevue = ancienneFin;
      return;
    }
    _emit();
  }

  /// Supprime un projet et délie tout ce qui le désignait : un document ou un
  /// engagement pointant vers un projet disparu produirait un calcul faux.
  void deleteProjet(int id) {
    projets.removeWhere((p) => p.id == id);
    for (final liste in documents.values) {
      for (final d in liste) {
        if (d.projetId == id) d.projetId = null;
      }
    }
    for (final e in engagements) {
      if (e.projetId == id) e.projetId = null;
    }
    _emit();
  }

  List<DocumentItem> proformasDuProjet(int projetId) =>
      documents['proforma']!.where((d) => d.projetId == projetId).toList();

  List<Engagement> engagementsDuProjet(int projetId) =>
      engagements.where((e) => e.projetId == projetId).toList();

  /// Mode d'avancement d'un projet. Simple relais vers `Projet.mode` : le
  /// type n'est plus un registre qu'il faut résoudre, mais un champ direct
  /// du projet. Conservé comme méthode (et non inliné chez ses appelants,
  /// dans gantt_screen.dart et projets_screen.dart) parce que plusieurs
  /// écrans y passent encore par `AppState`, jamais par `Projet` directement.
  ModeAvancement modeDuProjet(Projet p) => p.mode;

  /// Types déjà utilisés par les projets enregistrés, du plus récent (tête de
  /// `projets`, qui est en LIFO — voir `addProjet`) au plus ancien, sans
  /// doublon. Alimente les suggestions de la boîte « Nouveau projet » : il
  /// n'existe plus de registre à consulter, seulement l'historique déjà
  /// tapé par le manager.
  List<String> suggestionsTypeProjet() {
    final vus = <String>{};
    final res = <String>[];
    for (final p in projets) {
      if (p.type.isEmpty || !vus.add(p.type)) continue;
      res.add(p.type);
    }
    return res;
  }

  Projet? _projet(int id) {
    final m = projets.where((p) => p.id == id);
    return m.isEmpty ? null : m.first;
  }

  void ajouterJalon(int projetId, Jalon j) {
    final p = _projet(projetId);
    if (p == null) return;
    p.jalons.add(j);
    _emit();
  }

  /// Marque un jalon comme réalisé à `date`, ou le démarque si `date` est nul.
  void marquerJalon(int projetId, int index, DateTime? date) {
    final p = _projet(projetId);
    if (p == null || index < 0 || index >= p.jalons.length) return;
    p.jalons[index].realisee = date;
    _emit();
  }

  void supprimerJalon(int projetId, int index) {
    final p = _projet(projetId);
    if (p == null || index < 0 || index >= p.jalons.length) return;
    p.jalons.removeAt(index);
    _emit();
  }

  void setAvancementManuel(int projetId, double valeur) {
    final p = _projet(projetId);
    if (p == null) return;
    p.avancementManuel = valeur.clamp(0.0, 1.0);
    _emit();
  }

  /// Enregistre la quantité livrée d'une ligne de proforma.
  ///
  /// La proforma est la SOURCE DE VÉRITÉ du livré : la facture et le BL,
  /// figés à la validation, ne bougent pas. Le BL imprimé continue d'afficher
  /// les quantités commandées (§ 12 de la conception).
  void setQuantiteLivree(int proformaId, int indexLigne, int quantite) {
    final m = documents['proforma']!.where((d) => d.id == proformaId);
    if (m.isEmpty) return;
    final lignes = m.first.lines;
    if (indexLigne < 0 || indexLigne >= lignes.length) return;

    final l = lignes[indexLigne];
    l.qteLivree = quantite < 0 ? 0 : (quantite > l.qte ? l.qte : quantite);
    _emit();
  }

  Avancement avancementProjet(int projetId, {DateTime? now}) {
    final p = projets.firstWhere((x) => x.id == projetId);
    return Avancement.calculer(
      projet: p,
      mode: modeDuProjet(p),
      proformas: proformasDuProjet(projetId),
      engagements: engagementsDuProjet(projetId),
      now: now ?? DateTime.now(),
    );
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
        'Revenu ${Fmt.money(r.revenu)} · Dépenses ${Fmt.money(r.depenses)} · '
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
      // Trois ids distincts du compteur partagé (défaut 2, revue Lot A) : les
      // minter depuis l'horloge (`DateTime.now().millisecondsSinceEpoch`)
      // collisionnait dès que plusieurs proformas étaient validées dans la
      // même milliseconde — reproduit en validant 500 proformas en boucle,
      // seulement 498 ids distincts obtenus. Deux engagements partageant un
      // id, `deleteEngagement`/`ajouterReglement` ne pouvaient plus les
      // distinguer et agissaient sur les deux à la fois.
      // Montant de la facture ET de l'engagement : volontairement LA MÊME
      // expression. Les faire diverger (l'un recopiant `p.montant`, l'autre
      // resommant les lignes) est exactement comment le bug TTC/HT est né —
      // la facture affichait un montant, la créance en attendait un autre, et
      // l'écart disparaissait sans trace au premier règlement complet. Ne pas
      // les re-séparer.
      final montantHt = p.lines.fold(0.0, (s, l) => s + l.total);
      documents['facture']!.add(DocumentItem(
        id: nextId(), numero: factureNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: montantHt, statut: 'cours',
        projetId: p.projetId,
        // Copie profonde : chaque document possède ses lignes. Le partage
        // d'instances ne survivrait pas à un rechargement depuis le disque.
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
      // Le BL ne porte aucun montant.
      documents['bl']!.add(DocumentItem(
        id: nextId(), numero: blNum, date: p.date,
        dateAffichee: p.dateAffichee,
        clientId: p.clientId, client: p.client, clientAddr: p.clientAddr,
        objet: p.objet, montant: 0, statut: 'cours',
        projetId: p.projetId,
        lines: p.lines.map((l) => l.copie()).toList(),
      ));
      // La facture EST une créance sur le client : l'engagement naît du même
      // geste, pour qu'aucune saisie manuelle ne puisse le dédoubler.
      engagements.insert(0, Engagement(
        id: nextId(),
        sens: 'entrant',
        projetId: p.projetId,
        documentNumero: factureNum,
        clientId: p.clientId,
        tiers: p.client,
        description: p.objet,
        montant: montantHt,
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
