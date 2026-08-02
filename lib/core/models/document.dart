import 'commun.dart';

// ── Document ─────────────────────────────────────────────
class DocumentItem {
  final int id;
  final String numero;
  final String date;
  /// null = aucun client identifié (saisie libre du nom sans sélection dans
  /// l'autocomplete). Même convention que `Engagement.clientId` et
  /// `Projet.clientId` : « inconnu » se dit `null`, jamais un id inventé.
  final int? clientId;
  final String client;
  final String clientAddr;
  final String objet;
  final double montant;
  String statut; // 'cours' | 'validee' | 'annulee'
  /// Date telle qu'elle apparaît SUR le document (saisie libre par le manager).
  /// Distincte de [date], qui reste la date de création et sert au compteur
  /// journalier de la numérotation. Vide = aucune date imprimée.
  String dateAffichee;
  /// Projet auquel ce document se rattache. null = hors projet. Délié
  /// automatiquement si le projet est supprimé (voir AppState.deleteProjet).
  int? projetId;
  // Lignes du document — permettent de régénérer le PDF depuis la liste.
  final List<LineItem> lines;

  DocumentItem({
    required this.id, required this.numero, required this.date,
    required this.clientId, required this.client, required this.objet,
    required this.montant, required this.statut,
    this.clientAddr = '', this.lines = const [],
    this.dateAffichee = '', this.projetId,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'numero': numero, 'date': date, 'clientId': clientId,
    'client': client, 'clientAddr': clientAddr, 'objet': objet,
    'montant': montant, 'statut': statut,
    'lines': lines.map((l) => l.toJson()).toList(),
    'dateAffichee': dateAffichee, 'projetId': projetId,
  };

  factory DocumentItem.fromJson(Map<String, dynamic> j) => DocumentItem(
    id: j['id'], numero: j['numero'], date: j['date'], clientId: j['clientId'],
    client: j['client'], clientAddr: j['clientAddr'] ?? '', objet: j['objet'],
    montant: (j['montant'] as num).toDouble(), statut: j['statut'],
    lines: (j['lines'] as List? ?? []).map((l) => LineItem.fromJson(l)).toList(),
    dateAffichee: j['dateAffichee'] ?? '', projetId: j['projetId'],
  );
}

// ── Document Line Item ───────────────────────────────────
class LineItem {
  String ref;
  String designation;
  int qte;
  double pu;
  /// Quantité réellement livrée. Indicateur d'avancement INTERNE : le BL
  /// imprimé continue d'afficher `qte`. Voir § 12 de la conception.
  int qteLivree;

  LineItem({required this.ref, required this.designation, required this.qte,
      required this.pu, this.qteLivree = 0});

  double get total => qte * pu;
  double get totalLivre => qteLivree * pu;

  Map<String, dynamic> toJson() => {
    'ref': ref, 'designation': designation, 'qte': qte, 'pu': pu,
    'qteLivree': qteLivree,
  };

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
    ref: j['ref'], designation: j['designation'], qte: j['qte'],
    pu: toDouble(j['pu']), qteLivree: j['qteLivree'] ?? 0,
  );

  /// Copie indépendante. Indispensable : sans elle, facture et BL
  /// partageraient les objets de la proforma en mémoire mais plus après
  /// rechargement, et `qteLivree` se comporterait différemment avant et
  /// après un redémarrage.
  LineItem copie() => LineItem(
      ref: ref, designation: designation, qte: qte, pu: pu, qteLivree: qteLivree);
}
