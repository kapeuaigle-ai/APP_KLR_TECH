import 'models.dart';
import 'theme.dart';

class SampleData {
  static final List<Client> clients = [
    const Client(id: 1, initials: 'AC', color: AppColors.purple, name: 'Acme Corp', contact: 'Jean Dupont', email: 'jean@acmecorp.com', phone: '01 23 45 67 88', totalFacture: 12450000, address: '14 Rue de la Paix, 75001 Paris, France'),
    const Client(id: 2, initials: 'GT', color: AppColors.blue, name: 'Global Tech', contact: 'Sarah Smith', email: 's.smith@globaltech.fr', phone: '06 12 34 56 78', totalFacture: 8900000, address: '45 Avenue des Champs, Lyon, France'),
    const Client(id: 3, initials: 'DS', color: AppColors.emerald, name: 'Design Studio', contact: 'Marc Lévy', email: 'contact@designstudio.io', phone: '07 88 99 80 91', totalFacture: 3200000, address: '8 Rue Créative, Plateau, Abidjan, CI'),
    const Client(id: 4, initials: 'IN', color: AppColors.orange, name: 'Innovate SAS', contact: 'Julie Martin', email: 'j.martin@innovate.fr', phone: '01 99 88 77 66', totalFacture: 15780000, address: '22 Boulevard de l\'Innovation, Bordeaux, France'),
    const Client(id: 5, initials: 'UJ', color: AppColors.red, name: 'Université Jean Lorougon Guédé', contact: 'Prof. Koné', email: 'kone@ujlg.ci', phone: '07 00 11 22 33', totalFacture: 0, address: 'BP 150, Daloa, Côte d\'Ivoire'),
    const Client(id: 6, initials: 'SA', color: AppColors.purple, name: 'Société Anonyme X', contact: 'Dir. Général', email: 'dg@sax.ci', phone: '07 44 55 66 77', totalFacture: 450000, address: 'Zone Industrielle, Yopougon, Abidjan, CI'),
    const Client(id: 7, initials: 'AD', color: AppColors.teal, name: "Advans Côte d'Ivoire", contact: 'M. Diallo', email: 'm.diallo@advans.ci', phone: '07 22 33 44 55', totalFacture: 3517500, address: 'Cocody Les Deux Plateaux, Abidjan, CI'),
  ];

  // Lignes des documents d'exemple. Les montants ci-dessous sont la somme de
  // ces lignes, pour que la liste et l'aperçu concordent.
  static List<LineItem> _linesMaintenance() => [
    LineItem(ref: '01', designation: 'Maintenance préventive parc informatique (40 postes)', qte: 40, pu: 25000),
    LineItem(ref: '02', designation: 'Remplacement disques SSD 512 Go', qte: 12, pu: 45000),
    LineItem(ref: '03', designation: 'Intervention technicien sur site (forfait journée)', qte: 5, pu: 75000),
  ];

  static List<LineItem> _linesDeveloppement() => [
    LineItem(ref: '01', designation: 'Développement application de gestion — module métier', qte: 1, pu: 950000),
    LineItem(ref: '02', designation: 'Intégration et reprise des données existantes', qte: 1, pu: 350000),
    LineItem(ref: '03', designation: 'Formation des utilisateurs (2 sessions)', qte: 2, pu: 100000),
  ];

  static List<LineItem> _linesAudit() => [
    LineItem(ref: '01', designation: 'Audit de sécurité du réseau — phase d\'analyse', qte: 1, pu: 300000),
    LineItem(ref: '02', designation: 'Rapport de recommandations et plan d\'action', qte: 1, pu: 150000),
  ];

  static List<LineItem> _linesEquipements() => [
    LineItem(ref: '01', designation: 'Switch administrable 48 ports Gigabit', qte: 4, pu: 385000),
    LineItem(ref: '02', designation: 'Borne Wi-Fi 6 professionnelle', qte: 10, pu: 145000),
    LineItem(ref: '03', designation: 'Onduleur rack 3000 VA', qte: 2, pu: 275000),
    LineItem(ref: '04', designation: 'Câblage et mise en service', qte: 1, pu: 200000),
  ];

  static final Map<String, List<DocumentItem>> documents = {
    'proforma': [
      DocumentItem(id: 1, numero: 'KLR-P03-16022026', date: '16/02/2026', clientId: 5, client: 'Université Jean Lorougon Guédé', clientAddr: 'Daloa, Côte d\'Ivoire', objet: 'Maintenance parc informatique', montant: 1915000, statut: 'cours', lines: _linesMaintenance()),
      DocumentItem(id: 2, numero: 'KLR-P02-10012026', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 1500000, statut: 'validee', lines: _linesDeveloppement()),
      DocumentItem(id: 3, numero: 'KLR-P01-05012026', date: '05/01/2026', clientId: 6, client: 'Société Anonyme X', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Audit Sécurité Réseau', montant: 450000, statut: 'annulee', lines: _linesAudit()),
    ],
    // Générées à la validation de leur proforma : numéro apparié (lettre F/B pour
    // le même compteur et la même date), mêmes lignes.
    'facture': [
      DocumentItem(id: 1, numero: 'KLR-F04-24042026', date: '24/04/2026', clientId: 7, client: "Advans Côte d'Ivoire", clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Équipements Réseau', montant: 3740000, statut: 'cours', lines: _linesEquipements()),
      DocumentItem(id: 2, numero: 'KLR-F02-10012026', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 1500000, statut: 'validee', lines: _linesDeveloppement()),
    ],
    'bl': [
      DocumentItem(id: 1, numero: 'KLR-B04-24042026', date: '24/04/2026', clientId: 7, client: "Advans Côte d'Ivoire", clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Équipements Réseau', montant: 0, statut: 'cours', lines: _linesEquipements()),
      DocumentItem(id: 2, numero: 'KLR-B02-10012026', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 0, statut: 'validee', lines: _linesDeveloppement()),
    ],
  };

  static final List<Employee> employees = [
    const Employee(id: 1, nom: 'Koffi Lambert', initiales: 'KL', role: 'Directeur Tech', dept: 'Direction', statut: 'actif', projets: 4, taches: 12, perf: 96, phone: '+225 07 09 71 45 57', email: 'kl@klrtech.ci', color: AppColors.primary),
    const Employee(id: 2, nom: 'Amine Benjelloun', initiales: 'AB', role: 'Développeur Senior', dept: 'Développement', statut: 'actif', projets: 3, taches: 18, perf: 88, phone: '+225 07 11 22 33 44', email: 'ab@klrtech.ci', color: AppColors.blue),
    const Employee(id: 3, nom: 'Sara El Mansouri', initiales: 'SM', role: 'Comptable', dept: 'Finance', statut: 'actif', projets: 2, taches: 9, perf: 91, phone: '+225 07 55 66 77 88', email: 'sm@klrtech.ci', color: AppColors.purple),
    const Employee(id: 4, nom: 'Moussa Diallo', initiales: 'MD', role: 'Chef de Projet', dept: 'Gestion', statut: 'actif', projets: 5, taches: 21, perf: 84, phone: '+225 05 01 02 03 04', email: 'md@klrtech.ci', color: AppColors.emerald),
    const Employee(id: 5, nom: 'Aïcha Koné', initiales: 'AK', role: 'Designer UI/UX', dept: 'Design', statut: 'conge', projets: 1, taches: 4, perf: 79, phone: '+225 07 99 88 77 66', email: 'ak@klrtech.ci', color: AppColors.orange),
    const Employee(id: 6, nom: 'Jean-Luc Traoré', initiales: 'JT', role: 'Développeur Backend', dept: 'Développement', statut: 'actif', projets: 3, taches: 15, perf: 85, phone: '+225 07 22 33 44 55', email: 'jt@klrtech.ci', color: AppColors.teal),
    const Employee(id: 7, nom: 'Fatou Sy', initiales: 'FS', role: 'Commerciale', dept: 'Commercial', statut: 'mission', projets: 2, taches: 7, perf: 77, phone: '+225 07 66 77 88 99', email: 'fs@klrtech.ci', color: AppColors.red),
  ];

  static final List<Department> departments = [
    const Department(nom: 'Développement', membres: 2, color: AppColors.blue, bg: AppColors.blueBg, projets: 3, chef: 'Amine Benjelloun'),
    const Department(nom: 'Design', membres: 1, color: AppColors.orange, bg: AppColors.orangeBg, projets: 1, chef: 'Aïcha Koné'),
    const Department(nom: 'Finance', membres: 1, color: AppColors.purple, bg: AppColors.purpleBg, projets: 2, chef: 'Sara El Mansouri'),
    const Department(nom: 'Gestion', membres: 1, color: AppColors.emerald, bg: AppColors.greenBg, projets: 5, chef: 'Moussa Diallo'),
    const Department(nom: 'Commercial', membres: 1, color: AppColors.red, bg: AppColors.redBg, projets: 2, chef: 'Fatou Sy'),
    const Department(nom: 'Direction', membres: 1, color: AppColors.primary, bg: AppColors.redBg, projets: 4, chef: 'Koffi Lambert'),
  ];

  static List<Engagement> get initialEngagementsSortants => [
    Engagement(id: 201, sens: 'sortant', tiers: 'Fournisseur logiciels',
        description: 'Licences de développement', montant: 250000,
        echeance: DateTime(2026, 1, 12), categorie: 'Achat matériel',
        documentNumero: 'KLR-F02-10012026',
        reglements: [Reglement(id: 2011, date: DateTime(2026, 1, 12), montant: 250000)]),
    Engagement(id: 202, sens: 'sortant', tiers: 'Intégrateur',
        description: 'Sous-traitance intégration', montant: 180000,
        echeance: DateTime(2026, 1, 20), categorie: 'Sous-traitance',
        documentNumero: 'KLR-F02-10012026',
        reglements: [Reglement(id: 2021, date: DateTime(2026, 1, 20), montant: 180000)]),
    Engagement(id: 203, sens: 'sortant', tiers: 'Grossiste réseau',
        description: 'Achat switches et bornes Wi-Fi', montant: 1650000,
        echeance: DateTime(2026, 4, 26), categorie: 'Achat matériel',
        documentNumero: 'KLR-F04-24042026',
        reglements: [Reglement(id: 2031, date: DateTime(2026, 4, 26), montant: 1650000)]),
    Engagement(id: 204, sens: 'sortant', tiers: 'Bailleur',
        description: 'Loyer atelier — avril', montant: 150000,
        echeance: DateTime(2026, 4, 10), categorie: 'Loyer & charges',
        reglements: [Reglement(id: 2041, date: DateTime(2026, 4, 10), montant: 150000)]),
    Engagement(id: 205, sens: 'sortant', tiers: 'Transporteur',
        description: 'Transport livraisons', montant: 60000,
        echeance: DateTime(2026, 1, 5), categorie: 'Transport',
        reglements: [Reglement(id: 2051, date: DateTime(2026, 1, 5), montant: 60000)]),
  ];

  static final List<DimeEntry> dimeHistory = [
    const DimeEntry(mois: 'Janvier 2026', revenu: 12450000, dime: 1245000, statut: 'paye', date: '03/02/2026'),
    const DimeEntry(mois: 'Février 2026', revenu: 9800000, dime: 980000, statut: 'paye', date: '05/03/2026'),
    const DimeEntry(mois: 'Mars 2026', revenu: 15600000, dime: 1560000, statut: 'paye', date: '02/04/2026'),
    const DimeEntry(mois: 'Avril 2026', revenu: 11200000, dime: 1120000, statut: 'paye', date: '04/05/2026'),
    const DimeEntry(mois: 'Mai 2026', revenu: 13950000, dime: 1395000, statut: 'paye', date: '06/06/2026'),
    const DimeEntry(mois: 'Juin 2026', revenu: 18000000, dime: 1800000, statut: 'attente'),
  ];

  // Engagements : ce qu'on nous doit (créances, sens 'entrant') et ce que l'on
  // doit (dettes, sens 'sortant'). Getter et non champ : chaque AppState part
  // d'objets neufs, les règlements d'un test ou d'une session ne fuient pas
  // dans la suivante. L'ancienne référence libre ('num') rejoint la
  // description entre parenthèses, comme le fait `migrerV1versV2`.
  static List<Engagement> get initialEngagements => [
    Engagement(id: 1, sens: 'entrant', tiers: "Advans Côte d'Ivoire",
        description: 'Équipements réseau (KLR-F001-240426)', montant: 3517500,
        echeance: DateTime(2026, 5, 24)),
    Engagement(id: 2, sens: 'entrant', tiers: 'Acme Corp',
        description: 'Développement application (KLR-F003-180326)', montant: 5200000,
        echeance: DateTime(2026, 4, 18),
        reglements: [Reglement(id: 1002, date: DateTime(2026, 4, 18), montant: 5200000)]),
    Engagement(id: 3, sens: 'entrant', tiers: 'Global Tech',
        description: 'Audit sécurité réseau (KLR-F002-050326)', montant: 1800000,
        echeance: DateTime(2026, 4, 5),
        reglements: [Reglement(id: 1003, date: DateTime(2026, 4, 5), montant: 1800000)]),
    Engagement(id: 4, sens: 'entrant', tiers: 'Design Studio',
        description: 'Maintenance parc informatique (KLR-F004-010426)', montant: 750000,
        echeance: DateTime(2026, 5, 1)),
    Engagement(id: 5, sens: 'sortant', tiers: 'Orange CI',
        description: 'Abonnement fibre trimestriel (FRN-2026-018)', montant: 240000,
        echeance: DateTime(2026, 7, 31), categorie: 'Loyer & charges'),
    Engagement(id: 6, sens: 'sortant', tiers: 'Sotra Logistique',
        description: 'Livraison matériel Daloa (FRN-2026-012)', montant: 480000,
        echeance: DateTime(2026, 6, 30), categorie: 'Sous-traitance',
        reglements: [Reglement(id: 1006, date: DateTime(2026, 6, 28), montant: 480000)]),
  ];

  static List<Task> get initialTasks => [
    Task(id: 1, texte: 'Générer la facture Advans', titre: 'Facturation', priorite: 'haute', done: false),
    Task(id: 2, texte: 'Relancer Tech Corp (J+15)', titre: 'Relance client', priorite: 'haute', done: false),
    Task(id: 3, texte: 'Valider le BL #KLR-B001', titre: 'Livraison', priorite: 'normale', done: true),
    Task(id: 4, texte: 'Préparer rapport mensuel', titre: 'Rapport', priorite: 'basse', done: false),
  ];

  static List<Note> get initialNotes => [
    Note(id: 1, titre: 'Réunion client Advans', contenu: "Points abordés :\n• Budget validé\n• Livraison prévue fin mai\n• Contacter M. Diallo pour suivi", color: AppColors.blue, date: "Aujourd'hui"),
    Note(id: 2, titre: 'Idées refonte dashboard', contenu: "- Ajouter graphe donut CA\n- Bouton export en haut\n- Notifications en temps réel", color: AppColors.orange, date: 'Hier'),
    Note(id: 3, titre: 'Relances clients', contenu: "Rappel : relancer les clients dont l'échéance est dépassée de plus de 15 jours. Vérifier le tableau des créances chaque lundi.", color: AppColors.emerald, date: '28 Avr'),
  ];

  // Le fil d'activité démarre vide : il se remplit des vraies actions du
  // manager (documents, encaissements, dépenses, clôtures). Voir AppState.
}
