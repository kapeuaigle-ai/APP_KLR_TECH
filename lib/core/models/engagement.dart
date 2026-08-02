import 'commun.dart';

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
    description: j['description'] ?? '', montant: toDouble(j['montant']),
    statut: j['statut'], echeance: j['echeance'], dateReglement: j['dateReglement'],
    categorie: j['categorie'] ?? 'Autres',
    // Rétro-compatible : engagements enregistrés avant les acomptes.
    acompte: j['acompte'] == null ? 0 : toDouble(j['acompte']),
    dateAcompte: j['dateAcompte'],
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
