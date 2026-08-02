/// Migration des sauvegardes : v1 (quatre mécanismes d'argent) → v2
/// (Engagement + Reglement).
///
/// Travaille sur le JSON brut, jamais sur les modèles : les classes v1
/// n'existent plus, et une migration liée au code courant se casserait à
/// chaque évolution ultérieure du modèle.
library;

/// Convertit une sauvegarde v1 en v2. Une sauvegarde déjà en v2 est rendue
/// telle quelle, sans copie.
Map<String, dynamic> migrerV1versV2(Map<String, dynamic> j) {
  if (j['version'] == 2) return j;

  final generateur = _Ids();
  final engagements = <Map<String, dynamic>>[];

  // ── 1. Les engagements v1 (créances et dettes) ──────────
  final v1Engagements = (j['engagements'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  for (final e in v1Engagements) {
    engagements.add(_depuisEngagementV1(e, generateur));
  }

  // ── 2. Les dépenses : sortants réglés le jour même ──────
  for (final d in (j['expenses'] as List? ?? []).cast<Map<String, dynamic>>()) {
    engagements.add(_depuisDepenseV1(d, generateur));
  }

  // ── 3. Les factures, sauf celles déjà couvertes (§ 8.1) ─
  final documents = (j['documents'] as Map? ?? {}).cast<String, dynamic>();
  final factures = (documents['facture'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  final creancesAppariees = <int>{};

  for (final f in factures) {
    final apparie = _apparier(f, v1Engagements, engagements, creancesAppariees);
    if (apparie != null) {
      // Fusion : la créance saisie à la main EST cette facture.
      apparie['documentNumero'] = f['numero'];
      apparie['clientId'] = f['clientId'];
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
  // Le montant retenu est la SOMME DES LIGNES, et non `f['montant']` : c'est
  // ce que `Comptabilite.factureHt` utilisait en v1. Prendre l'autre ferait
  // diverger le bilan après migration.
  final montant = (f['lines'] as List? ?? []).fold<double>(
      0.0, (s, l) => s + (l['qte'] as num) * _double(l['pu']));
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
  List<Map<String, dynamic>> v1Engagements,
  List<Map<String, dynamic>> v2Engagements,
  Set<int> dejaAppariees,
) {
  final numero = _normaliser(facture['numero'] ?? '');
  if (numero.isEmpty) return null;

  // 1. La référence libre contient le numéro de facture : cas certain.
  for (var i = 0; i < v1Engagements.length; i++) {
    final e = v1Engagements[i];
    if (e['sens'] != 'creance' || dejaAppariees.contains(i)) continue;
    if (_normaliser(e['num'] ?? '').contains(numero)) {
      dejaAppariees.add(i);
      return v2Engagements[i];
    }
  }

  // 2. Même client ET même montant : cas ambigu, fusionné et journalisé.
  //    Jamais sur le seul montant — deux factures de 500 000 F à des clients
  //    différents ne doivent pas fusionner.
  final montant = (facture['lines'] as List? ?? []).fold<double>(
      0.0, (s, l) => s + (l['qte'] as num) * _double(l['pu']));
  final client = _normaliser(facture['client'] ?? '');
  if (client.isEmpty) return null;

  for (var i = 0; i < v1Engagements.length; i++) {
    final e = v1Engagements[i];
    if (e['sens'] != 'creance' || dejaAppariees.contains(i)) continue;
    if (_normaliser(e['tiers'] ?? '') == client && _double(e['montant']) == montant) {
      dejaAppariees.add(i);
      final fusionne = v2Engagements[i];
      fusionne['fusionAmbigue'] = true; // lu par AppState pour journaliser
      return fusionne;
    }
  }
  return null;
}

// ── Outils ────────────────────────────────────────────────

class _Ids {
  int _n = DateTime.now().millisecondsSinceEpoch;
  int suivant() => _n++;
}

Map<String, dynamic> _reglement(int id, DateTime date, double montant) => {
  'id': id, 'date': date.toIso8601String(),
  'montant': montant, 'moyen': 'especes',
};

double _double(dynamic v) => (v as num).toDouble();

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
