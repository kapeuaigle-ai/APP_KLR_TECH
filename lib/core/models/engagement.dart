import 'commun.dart';

/// Catégories analytiques d'un décaissement. Remplace `Expense.categories`.
const kCategoriesDepense = [
  'Achat matériel', 'Transport', 'Sous-traitance',
  'Loyer & charges', 'Salaires', 'Autres',
];

/// Un mouvement d'argent réel, daté. Partiel ou total.
///
/// C'est le SEUL objet qui fait bouger la comptabilité : un règlement d'un
/// engagement entrant est un encaissement, celui d'un sortant un décaissement.
class Reglement {
  final int id;
  DateTime date;
  double montant;
  String moyen; // 'especes' | 'virement' | 'mobile' | 'cheque'

  Reglement({
    required this.id, required this.date, required this.montant,
    this.moyen = 'especes',
  });

  static const moyens = ['especes', 'virement', 'mobile', 'cheque'];

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(),
    'montant': montant, 'moyen': moyen,
  };

  factory Reglement.fromJson(Map<String, dynamic> j) => Reglement(
    id: j['id'], date: DateTime.parse(j['date']),
    montant: toDouble(j['montant']), moyen: j['moyen'] ?? 'especes',
  );
}

/// Une promesse de flux : un montant attendu, dans un sens, à une échéance.
///
/// Remplace à lui seul les quatre mécanismes d'avant : la créance, la dette,
/// la facture encaissée et la dépense au comptant. Tout ce qui était `statut`,
/// `acompte` ou `dateReglement` se déduit désormais de [reglements].
class Engagement {
  final int id;
  final String sens;        // 'entrant' | 'sortant'
  int? projetId;            // null = hors projet
  String? documentNumero;   // facture d'origine, ou pièce fournisseur
  int? clientId;            // renseigné si entrant
  String tiers;             // fournisseur si sortant, nom du client si entrant
  String description;
  double montant;           // attendu
  DateTime echeance;
  String categorie;         // analytique, surtout pour les sortants
  final List<Reglement> reglements;
  bool annule;

  Engagement({
    required this.id, required this.sens, required this.tiers,
    required this.montant, required this.echeance,
    this.projetId, this.documentNumero, this.clientId,
    this.description = '', this.categorie = 'Autres',
    List<Reglement>? reglements, this.annule = false,
  }) : reglements = reglements ?? [];

  bool get estEntrant => sens == 'entrant';

  /// Somme réellement mouvementée.
  double get regle => reglements.fold(0.0, (s, r) => s + r.montant);

  /// Solde restant dû. Jamais négatif, même en cas de sur-règlement.
  double get reste {
    final r = montant - regle;
    return r < 0 ? 0 : r;
  }

  bool get solde => reste == 0;

  /// En retard à la date `now`. Le jour de l'échéance n'est pas un retard.
  /// `now` est un paramètre, jamais `DateTime.now()` : c'est ce qui rend la
  /// règle testable, comme `AppState.verifierCloture`.
  bool enRetard(DateTime now) {
    if (solde || annule) return false;
    final jour = DateTime(now.year, now.month, now.day);
    final ech = DateTime(echeance.year, echeance.month, echeance.day);
    return jour.isAfter(ech);
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'sens': sens, 'projetId': projetId,
    'documentNumero': documentNumero, 'clientId': clientId,
    'tiers': tiers, 'description': description, 'montant': montant,
    'echeance': echeance.toIso8601String(), 'categorie': categorie,
    'reglements': reglements.map((r) => r.toJson()).toList(),
    'annule': annule,
  };

  factory Engagement.fromJson(Map<String, dynamic> j) => Engagement(
    id: j['id'], sens: j['sens'], projetId: j['projetId'],
    documentNumero: j['documentNumero'], clientId: j['clientId'],
    tiers: j['tiers'], description: j['description'] ?? '',
    montant: toDouble(j['montant']),
    echeance: DateTime.parse(j['echeance']),
    categorie: j['categorie'] ?? 'Autres',
    reglements: (j['reglements'] as List? ?? [])
        .map((r) => Reglement.fromJson(r)).toList(),
    annule: j['annule'] ?? false,
  );
}
