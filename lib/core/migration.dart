/// Migration des sauvegardes : v1 (quatre mécanismes d'argent) → v2
/// (Engagement + Reglement) → v3 (suppression de la TVA, montant des
/// documents réaligné sur la somme de leurs lignes) → v4 (le registre
/// `settings.typesProjet` disparaît, chaque projet porte directement son
/// libellé et son mode).
///
/// Travaille sur le JSON brut, jamais sur les modèles : les classes v1
/// n'existent plus, et une migration liée au code courant se casserait à
/// chaque évolution ultérieure du modèle.
library;

/// Version courante du format de sauvegarde — SOURCE UNIQUE : `AppState.
/// toJson()` l'écrit, `AppState.loadFromJson` route dessus. Une 5ᵉ migration
/// n'a qu'à ajouter sa fonction `migrerV4versV5`, l'appeler depuis le
/// chaînage à seuils de `loadFromJson`, et incrémenter ce nombre ici — pas de
/// second endroit à retrouver.
const kVersionSauvegarde = 4;

/// Levée par `AppState.loadFromJson` quand la version de la sauvegarde n'est
/// pas un entier reconnu par cette version de l'application : soit un entier
/// SUPÉRIEUR à [kVersionSauvegarde] (fichier écrit par une version plus
/// récente de l'app — le migrer serait deviner sa forme), soit une valeur qui
/// n'est même pas un entier (chaîne, map, corruption) — jamais l'allure d'un
/// vrai fichier v1, qui n'a simplement AUCUNE clé `version`. Dans les deux
/// cas, deviner « v1 » referait exactement l'erreur du routage par égalité
/// stricte que ce chaînage à seuils remplace : un v5 pris pour un v1 voit son
/// `sens` retourné et ses `reglements` supprimés (défaut 1, revue Lot A).
/// On refuse, on ne migre rien, on n'écrit rien.
class SauvegardeVersionRefuseeException implements Exception {
  final dynamic versionTrouvee;
  const SauvegardeVersionRefuseeException(this.versionTrouvee);
  @override
  String toString() =>
      'Sauvegarde de version incompatible ($versionTrouvee) — cette version '
      'de l\'application ne sait lire que jusqu\'à v$kVersionSauvegarde.';
}

/// Convertit une sauvegarde v1 en v2. Une sauvegarde déjà en v2 est rendue
/// telle quelle, sans copie.
Map<String, dynamic> migrerV1versV2(Map<String, dynamic> j) {
  if (j['version'] == 2) return j;

  final generateur = _Ids();
  final engagements = <Map<String, dynamic>>[];

  // ── 1. Les engagements v1 (créances et dettes) ──────────
  // On conserve la correspondance v1 ⇄ v2 explicitement, par paires : un
  // appariement par index se romprait en silence si quelqu'un ajoutait plus
  // tard un filtre à cette boucle, et `_apparier` fusionnerait alors une
  // facture dans le mauvais engagement.
  final v1Engagements = (j['engagements'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final paires = <({Map<String, dynamic> v1, Map<String, dynamic> v2})>[];
  for (final e in v1Engagements) {
    final converti = _depuisEngagementV1(e, generateur);
    engagements.add(converti);
    paires.add((v1: e, v2: converti));
  }

  // ── 2. Les dépenses : sortants réglés le jour même ──────
  for (final d in (j['expenses'] as List? ?? []).cast<Map<String, dynamic>>()) {
    engagements.add(_depuisDepenseV1(d, generateur));
  }

  // ── 3. Les factures, sauf celles déjà couvertes (§ 8.1) ─
  final documents = (j['documents'] as Map? ?? {}).cast<String, dynamic>();
  final factures = (documents['facture'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final creancesAppariees = <Map<String, dynamic>>{};

  for (final f in factures) {
    final apparie = _apparier(f, paires, creancesAppariees);
    if (apparie != null) {
      // Fusion : la créance saisie à la main EST cette facture.
      apparie['documentNumero'] = f['numero'];
      apparie['clientId'] = f['clientId'];
      _fusionnerPaiement(apparie, f, generateur);
      continue;
    }
    engagements.add(_depuisFactureV1(f, generateur));
  }

  // ── 4. Nettoyage des documents ──────────────────────────
  // Copie défensive de chaque document : une Map littérale sans aucune
  // valeur `null` s'infère `Map<String, Object>` (non nullable) en Dart, ce
  // qui interdit d'y écrire `null` en place. `jsonDecode` produit toujours
  // du `Map<String, dynamic>`, donc cette copie est un no-op sur de vraies
  // données ; elle protège seulement contre ce piège d'inférence.
  for (final type in ['proforma', 'facture', 'bl']) {
    final liste = (documents[type] as List? ?? []).cast<Map<String, dynamic>>();
    documents[type] = liste.map((d) {
      final dd = Map<String, dynamic>.from(d);
      dd.remove('encaissee');
      dd.remove('dateEncaissement');
      dd['projetId'] = null;
      dd['lines'] = (d['lines'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((l) {
            final ll = Map<String, dynamic>.from(l);
            ll['qteLivree'] = 0;
            return ll;
          })
          .toList();
      return dd;
    }).toList();
  }

  final v2 = Map<String, dynamic>.from(j);
  v2['version'] = 2;
  v2['engagements'] = engagements;
  v2['documents'] = documents;
  v2['projets'] = <Map<String, dynamic>>[];
  v2.remove('expenses');
  return v2;
}

/// Convertit une sauvegarde v2 en v3. Une sauvegarde déjà en v3 est rendue
/// telle quelle, sans copie.
///
/// v3 retire la TVA (jamais appliquée en pratique : le régime du manager n'y
/// est pas assujetti) et corrige le bug qu'elle cachait : `DocumentItem.montant`
/// valait le TTC pour une proforma/facture créée depuis l'écran, alors que la
/// comptabilité (`Comptabilite.montantFacture`, l'engagement créé à la validation)
/// a toujours sommé les lignes (HT). L'écart ne se voyait nulle part — jusqu'à
/// ce qu'un client règle une facture en entier : `ajouterReglement` écrête le
/// paiement au `reste` de l'engagement (HT), et la différence avec le TTC
/// affiché disparaissait sans laisser de trace.
///
/// Cette migration réaligne chaque document (proforma, facture) sur la somme
/// de ses lignes, seule vérité désormais. Un bon de livraison garde
/// `montant: 0` par convention (voir `AppState.validateProforma`) : il est
/// donc exclu, pour ne pas lui donner un prix qu'il ne doit pas avoir. Les
/// engagements ne bougent pas : ils étaient déjà en HT (§ `_montantFacture`
/// ci-dessus, déjà la somme des lignes depuis toujours).
Map<String, dynamic> migrerV2versV3(Map<String, dynamic> j) {
  if (j['version'] == 3) return j;

  final v3 = Map<String, dynamic>.from(j);
  v3['version'] = 3;

  final settingsBrut = v3['settings'];
  if (settingsBrut is Map) {
    final settings = Map<String, dynamic>.from(settingsBrut);
    settings.remove('tva');
    v3['settings'] = settings;
  }

  final documentsBrut = v3['documents'];
  if (documentsBrut is Map) {
    final documents = Map<String, dynamic>.from(documentsBrut);
    for (final type in ['proforma', 'facture']) {
      final liste = (documents[type] as List? ?? []).cast<Map<String, dynamic>>();
      documents[type] = liste.map((d) {
        final dd = Map<String, dynamic>.from(d);
        dd['montant'] = _sommeLignes(d);
        return dd;
      }).toList();
    }
    v3['documents'] = documents;
  }

  return v3;
}

/// Convertit une sauvegarde v3 en v4. Une sauvegarde déjà en v4 est rendue
/// telle quelle, sans copie.
///
/// v4 retire le registre `settings.typesProjet` : chaque projet portait un
/// `typeId` qui pointait dedans, pour deux informations que ce registre
/// confondait dans une seule entité — un libellé libre et un mode
/// d'avancement. Le manager n'a besoin d'aucun registre pour un libellé qu'il
/// ne tape qu'une fois par projet ; seul le mode compte pour le calcul
/// (`avancement.dart`). Chaque projet porte désormais directement `type`
/// (chaîne libre) et `mode` (le nom de l'enum `ModeAvancement`).
///
/// Un `typeId` qui ne correspond à aucun type du registre — déjà toléré
/// avant cette version, `AppState.modeDuProjet` retombait alors sur
/// `quantites` — devient `type: ''` et `mode: 'quantites'` : rien à
/// retrouver pour un type qui n'existait déjà plus.
Map<String, dynamic> migrerV3versV4(Map<String, dynamic> j) {
  if (j['version'] == 4) return j;

  final v4 = Map<String, dynamic>.from(j);
  v4['version'] = 4;

  final settingsBrut = v4['settings'];
  final typesBruts = settingsBrut is Map
      ? (settingsBrut['typesProjet'] as List? ?? []).whereType<Map>().toList()
      : const <Map>[];

  Map? typeParId(dynamic id) {
    for (final t in typesBruts) {
      if (t['id'] == id) return t;
    }
    return null;
  }

  final projetsBruts = (v4['projets'] as List? ?? []).cast<Map<String, dynamic>>();
  v4['projets'] = projetsBruts.map((p) {
    final pp = Map<String, dynamic>.from(p);
    final t = typeParId(pp['typeId']);
    pp['type'] = t == null ? '' : (t['libelle'] ?? '');
    pp['mode'] = t == null ? 'quantites' : (t['mode'] ?? 'quantites');
    pp.remove('typeId');
    return pp;
  }).toList();

  if (settingsBrut is Map) {
    final settings = Map<String, dynamic>.from(settingsBrut);
    settings.remove('typesProjet');
    v4['settings'] = settings;
  }

  return v4;
}

/// Somme des lignes d'un document brut — même calcul que `_montantFacture`
/// ci-dessus, sous un nom neutre : cette fois appliqué à tout document
/// facturable (proforma ou facture), pas seulement à une facture v1.
double _sommeLignes(Map<String, dynamic> d) => (d['lines'] as List? ?? [])
    .whereType<Map>()
    .fold<double>(0.0, (s, l) => s + _double(l['qte']) * _double(l['pu']));

// ── Conversions unitaires ─────────────────────────────────

Map<String, dynamic> _depuisEngagementV1(Map<String, dynamic> e, _Ids ids) {
  final reglements = <Map<String, dynamic>>[];
  final montant = _double(e['montant']);
  final acompte = e['acompte'] == null ? 0.0 : _double(e['acompte']);
  // Une date illisible vaut une date absente : v1 excluait déjà des comptes
  // un acompte sans date. Surtout, la migration s'exécute au chargement de
  // l'application — un enregistrement malformé doit être ignoré, jamais faire
  // échouer l'ouverture de toute la sauvegarde.
  final dAcompte = _jour(e['dateAcompte']);
  final aAcompte = acompte > 0 && dAcompte != null;

  if (aAcompte) {
    reglements.add(_reglement(ids.suivant(), dAcompte, acompte));
  }
  final dReglement = _jour(e['dateReglement']);
  if (e['statut'] == 'paye' && dReglement != null) {
    // Le solde seulement : l'acompte a déjà été porté à sa propre date.
    final solde = aAcompte ? montant - acompte : montant;
    if (solde > 0) {
      reglements.add(_reglement(ids.suivant(), dReglement, solde));
    }
  }

  return {
    'id': ids.suivant(),
    'sens': e['sens'] == 'creance' ? 'entrant' : 'sortant',
    'projetId': null,
    'documentNumero': null,
    'clientId': null,
    'tiers': e['tiers'] ?? '',
    // `num` v1 était une référence libre ; elle rejoint la description pour
    // ne pas être perdue.
    'description': _joindre(e['description'], e['num']),
    'montant': montant,
    'echeance': (_jour(e['echeance']) ?? DateTime(2026)).toIso8601String(),
    'categorie': e['categorie'] ?? 'Autres',
    'reglements': reglements,
    'annule': false,
  };
}

Map<String, dynamic> _depuisDepenseV1(Map<String, dynamic> d, _Ids ids) {
  // Une date illisible ne fait pas disparaître la dépense : elle ressort
  // comme un engagement sortant sans règlement, l'argent reste visible en
  // « reste dû » au lieu d'être perdu ou de bloquer le chargement.
  final date = _iso(d['date']);
  final montant = _double(d['amount']);
  return {
    'id': ids.suivant(),
    'sens': 'sortant',
    'projetId': null,
    'documentNumero': d['factureNumero'],
    'clientId': null,
    'tiers': '',
    'description': d['label'] ?? '',
    'montant': montant,
    'echeance': (date ?? DateTime(2026)).toIso8601String(),
    'categorie': d['category'] ?? 'Autres',
    'reglements': date != null
        ? [_reglement(ids.suivant(), date, montant)]
        : <Map<String, dynamic>>[],
    'annule': false,
  };
}

Map<String, dynamic> _depuisFactureV1(Map<String, dynamic> f, _Ids ids) {
  final montant = _montantFacture(f);
  final encaissee = f['encaissee'] == true;
  final dateEnc = _jour(f['dateEncaissement']);

  return {
    'id': ids.suivant(),
    'sens': 'entrant',
    'projetId': null,
    'documentNumero': f['numero'],
    'clientId': f['clientId'],
    'tiers': f['client'] ?? '',
    'description': f['objet'] ?? '',
    'montant': montant,
    'echeance': (_jour(f['date']) ?? DateTime(2026)).toIso8601String(),
    'categorie': 'Autres',
    'reglements': encaissee && dateEnc != null
        ? [_reglement(ids.suivant(), dateEnc, montant)]
        : <Map<String, dynamic>>[],
    'annule': false,
  };
}

/// Règle de fusion du § 8.1 : retrouve l'engagement v2 issu d'une créance v1
/// qui désigne déjà cette facture, pour ne pas créer de doublon.
Map<String, dynamic>? _apparier(
  Map<String, dynamic> facture,
  List<({Map<String, dynamic> v1, Map<String, dynamic> v2})> paires,
  Set<Map<String, dynamic>> dejaAppariees,
) {
  final numero = _normaliser(facture['numero'] ?? '');
  if (numero.isEmpty) return null;

  // 1. La référence libre contient le numéro de facture : cas certain.
  for (final p in paires) {
    if (p.v1['sens'] != 'creance' || dejaAppariees.contains(p.v2)) continue;
    if (_normaliser(p.v1['num'] ?? '').contains(numero)) {
      dejaAppariees.add(p.v2);
      return p.v2;
    }
  }

  // 2. Même client ET même montant : cas ambigu, fusionné et journalisé.
  //    Jamais sur le seul montant — deux factures de 500 000 F à des clients
  //    différents ne doivent pas fusionner.
  final montant = _montantFacture(facture);
  final client = _normaliser(facture['client'] ?? '');
  if (client.isEmpty) return null;

  for (final p in paires) {
    if (p.v1['sens'] != 'creance' || dejaAppariees.contains(p.v2)) continue;
    if (_normaliser(p.v1['tiers'] ?? '') == client &&
        _double(p.v1['montant']) == montant) {
      dejaAppariees.add(p.v2);
      p.v2['fusionAmbigue'] = true; // lu par AppState pour journaliser
      return p.v2;
    }
  }
  return null;
}

/// Concilie l'argent au moment d'une fusion facture/créance (§ 8.1).
///
/// Sans cette étape, un encaissement réel de la facture disparaît en silence
/// dès que la créance appariée n'en porte aucune trace : c'est le bug
/// critique corrigé ici. Trois cas :
///
/// 1. la créance porte déjà un ou plusieurs règlements (acompte et/ou statut
///    'paye') : la même somme a probablement été saisie deux fois en v1 — on
///    garde les règlements de la créance, on n'ajoute rien de la facture, et
///    on journalise pour que le manager vérifie, même sur une fusion certaine
///    (branche 1) ;
/// 2. la créance n'a aucun règlement et la facture a été encaissée : c'est
///    l'encaissement qui, sans conciliation, se perdrait — on l'ajoute, à la
///    date et au montant de la facture, et on journalise aussi (l'argent
///    associé à cette fusion mérite une vérification) ;
/// 3. ni l'une ni l'autre n'a enregistré de paiement : rien à faire, le
///    comportement d'avant cette correction était déjà le bon.
///
/// Dans tous les cas de fusion, le montant attendu conservé est le plus
/// grand des deux : une créance saisie à la main a pu être arrondie, et
/// sous-estimer ce qui reste dû serait dangereux.
void _fusionnerPaiement(
  Map<String, dynamic> apparie,
  Map<String, dynamic> facture,
  _Ids ids,
) {
  final montantFacture = _montantFacture(facture);
  if (montantFacture > _double(apparie['montant'])) {
    apparie['montant'] = montantFacture;
  }

  if (facture['encaissee'] != true) return; // cas 3 : rien à réconcilier

  final reglements = (apparie['reglements'] as List).cast<Map<String, dynamic>>();
  if (reglements.isNotEmpty) {
    // Cas 1 : ne pas compter deux fois le même argent.
    apparie['fusionAmbigue'] = true;
    return;
  }

  // Cas 2 : l'encaissement de la facture est la seule trace de ce paiement.
  final dateEnc = _jour(facture['dateEncaissement']);
  if (dateEnc != null) {
    reglements.add(_reglement(ids.suivant(), dateEnc, montantFacture));
  }
  apparie['fusionAmbigue'] = true;
}

/// Montant d'une facture : la SOMME DE SES LIGNES, et non son champ
/// `montant`. C'est ce que `Comptabilite.montantFacture` calculait en v1 ; prendre
/// l'autre ferait diverger le bilan après migration.
double _montantFacture(Map<String, dynamic> f) => (f['lines'] as List? ?? [])
    .whereType<Map>()
    .fold<double>(0.0, (s, l) => s + _double(l['qte']) * _double(l['pu']));

// ── Outils ────────────────────────────────────────────────

class _Ids {
  // Microsecondes, et non millisecondes : le reste de l'application mint ses
  // identifiants en millisecondes, et le compteur prend ici de l'avance d'une
  // unité par enregistrement converti.
  int _n = DateTime.now().microsecondsSinceEpoch;
  int suivant() => _n++;
}

Map<String, dynamic> _reglement(int id, DateTime date, double montant) => {
  'id': id, 'date': date.toIso8601String(),
  'montant': montant, 'moyen': 'especes',
};

/// JSON → double, tolérant. Une valeur absente ou d'un type inattendu vaut 0.
/// Même règle que pour les dates : un champ corrompu doit dégrader
/// l'enregistrement concerné, jamais empêcher l'ouverture de la sauvegarde.
double _double(dynamic v) => v is num ? v.toDouble() : 0.0;

/// 'dd/MM/yyyy' → DateTime, ou null si inexploitable.
DateTime? _jour(dynamic s) {
  if (s is! String) return null;
  final p = s.split('/');
  if (p.length != 3) return null;
  final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

/// ISO 8601 → DateTime, ou null si la chaîne est inexploitable.
DateTime? _iso(dynamic s) => s is String ? DateTime.tryParse(s) : null;

String _normaliser(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'[\s\-_/]'), '');

String _joindre(dynamic description, dynamic num) {
  final d = (description ?? '').toString().trim();
  final n = (num ?? '').toString().trim();
  if (d.isEmpty) return n;
  if (n.isEmpty) return d;
  return '$d ($n)';
}
