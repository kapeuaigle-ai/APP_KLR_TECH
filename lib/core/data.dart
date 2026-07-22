import 'models.dart';
import 'theme.dart';

class SampleData {
  static final List<Client> clients = [
    const Client(id: 1, initials: 'AC', color: AppColors.purple, name: 'Acme Corp', contact: 'Jean Dupont', email: 'jean@acmecorp.com', phone: '01 23 45 67 88', totalFacture: 12450000, status: 'actif', address: '14 Rue de la Paix, 75001 Paris, France'),
    const Client(id: 2, initials: 'GT', color: AppColors.blue, name: 'Global Tech', contact: 'Sarah Smith', email: 's.smith@globaltech.fr', phone: '06 12 34 56 78', totalFacture: 8900000, status: 'actif', address: '45 Avenue des Champs, Lyon, France'),
    const Client(id: 3, initials: 'DS', color: AppColors.emerald, name: 'Design Studio', contact: 'Marc Lévy', email: 'contact@designstudio.io', phone: '07 88 99 80 91', totalFacture: 3200000, status: 'attente', address: '8 Rue Créative, Plateau, Abidjan, CI'),
    const Client(id: 4, initials: 'IN', color: AppColors.orange, name: 'Innovate SAS', contact: 'Julie Martin', email: 'j.martin@innovate.fr', phone: '01 99 88 77 66', totalFacture: 15780000, status: 'actif', address: '22 Boulevard de l\'Innovation, Bordeaux, France'),
    const Client(id: 5, initials: 'UJ', color: AppColors.red, name: 'Université Jean Lorougon Guédé', contact: 'Prof. Koné', email: 'kone@ujlg.ci', phone: '07 00 11 22 33', totalFacture: 0, status: 'cours', address: 'BP 150, Daloa, Côte d\'Ivoire'),
    const Client(id: 6, initials: 'SA', color: AppColors.purple, name: 'Société Anonyme X', contact: 'Dir. Général', email: 'dg@sax.ci', phone: '07 44 55 66 77', totalFacture: 450000, status: 'actif', address: 'Zone Industrielle, Yopougon, Abidjan, CI'),
    const Client(id: 7, initials: 'AD', color: AppColors.teal, name: "Advans Côte d'Ivoire", contact: 'M. Diallo', email: 'm.diallo@advans.ci', phone: '07 22 33 44 55', totalFacture: 3517500, status: 'actif', address: 'Cocody Les Deux Plateaux, Abidjan, CI'),
  ];

  // Lignes des documents d'exemple. Les montants ci-dessous sont les totaux
  // TTC correspondants (HT × 1,05), pour que la liste et l'aperçu concordent.
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
      DocumentItem(id: 1, numero: 'KLR-03-160226', date: '16/02/2026', clientId: 5, client: 'Université Jean Lorougon Guédé', clientAddr: 'Daloa, Côte d\'Ivoire', objet: 'Maintenance parc informatique', montant: 2010750, statut: 'cours', lines: _linesMaintenance()),
      DocumentItem(id: 2, numero: 'KLR-02-100126', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 1575000, statut: 'validee', lines: _linesDeveloppement()),
      DocumentItem(id: 3, numero: 'KLR-01-050126', date: '05/01/2026', clientId: 6, client: 'Société Anonyme X', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Audit Sécurité Réseau', montant: 472500, statut: 'annulee', lines: _linesAudit()),
    ],
    // Générées à la validation de leur proforma : même numéro, mêmes lignes.
    'facture': [
      DocumentItem(id: 1, numero: 'KLR-04-240426', date: '24/04/2026', clientId: 7, client: "Advans Côte d'Ivoire", clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Équipements Réseau', montant: 3927000, statut: 'cours', lines: _linesEquipements()),
      DocumentItem(id: 2, numero: 'KLR-02-100126', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 1575000, statut: 'validee', lines: _linesDeveloppement()),
    ],
    'bl': [
      DocumentItem(id: 1, numero: 'KLR-04-240426', date: '24/04/2026', clientId: 7, client: "Advans Côte d'Ivoire", clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Équipements Réseau', montant: 0, statut: 'cours', lines: _linesEquipements()),
      DocumentItem(id: 2, numero: 'KLR-02-100126', date: '10/01/2026', clientId: 2, client: 'Client B', clientAddr: 'Abidjan, Côte d\'Ivoire', objet: 'Développement Application', montant: 0, statut: 'validee', lines: _linesDeveloppement()),
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

  static final List<DimeEntry> dimeHistory = [
    const DimeEntry(mois: 'Janvier 2026', revenu: 12450000, dime: 1245000, statut: 'paye', date: '03/02/2026'),
    const DimeEntry(mois: 'Février 2026', revenu: 9800000, dime: 980000, statut: 'paye', date: '05/03/2026'),
    const DimeEntry(mois: 'Mars 2026', revenu: 15600000, dime: 1560000, statut: 'paye', date: '02/04/2026'),
    const DimeEntry(mois: 'Avril 2026', revenu: 11200000, dime: 1120000, statut: 'paye', date: '04/05/2026'),
    const DimeEntry(mois: 'Mai 2026', revenu: 13950000, dime: 1395000, statut: 'paye', date: '06/06/2026'),
    const DimeEntry(mois: 'Juin 2026', revenu: 18000000, dime: 1800000, statut: 'attente'),
  ];

  static final List<FactureEntry> factureHistory = [
    FactureEntry(num: 'KLR-F001-240426', client: "Advans Côte d'Ivoire", montant: 3517500, statut: 'cours', echeance: '24/05/2026'),
    FactureEntry(num: 'KLR-F003-180326', client: 'Acme Corp', montant: 5200000, statut: 'paye', echeance: '18/04/2026'),
    FactureEntry(num: 'KLR-F002-050326', client: 'Global Tech', montant: 1800000, statut: 'paye', echeance: '05/04/2026'),
    FactureEntry(num: 'KLR-F004-010426', client: 'Design Studio', montant: 750000, statut: 'retard', echeance: '01/05/2026'),
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
    Note(id: 3, titre: 'Conditions TVA', contenu: "Rappel : TVA à 5% sur tous les documents. Vérifier avec comptable pour les cas d'exonération.", color: AppColors.emerald, date: '28 Avr'),
  ];

  static final List<ActivityItem> activities = [
    const ActivityItem(id: 1, type: 'facture', titre: 'Facture #KLR-F001-240426 générée', desc: "Client : Advans Côte d'Ivoire — 3 517 500 FCFA", auteur: 'Koffi Lambert', initiales: 'KL', time: "Aujourd'hui, 09:14", color: AppColors.primary),
    const ActivityItem(id: 2, type: 'paiement', titre: 'Paiement reçu — 5 200 000 FCFA', desc: 'Via virement bancaire · Acme Corp', auteur: 'Sara El Mansouri', initiales: 'SM', time: "Aujourd'hui, 08:40", color: AppColors.purple),
    const ActivityItem(id: 3, type: 'projet', titre: 'Tâche "API OAuth2" marquée terminée', desc: 'Projet Alpha · Développement API Connecteurs', auteur: 'Amine Benjelloun', initiales: 'AB', time: 'Hier, 17:22', color: AppColors.blue),
    const ActivityItem(id: 4, type: 'client', titre: 'Nouveau client ajouté — Société Sahel Innov', desc: 'Secteur : Technologie · Statut : Actif', auteur: 'Fatou Sy', initiales: 'FS', time: 'Hier, 15:05', color: AppColors.red),
    const ActivityItem(id: 5, type: 'document', titre: 'Proforma #KLR-P008-160226 envoyée par email', desc: "Destinataire : Université Jean Lorougon Guédé", auteur: 'Koffi Lambert', initiales: 'KL', time: 'Hier, 11:30', color: AppColors.primary),
    const ActivityItem(id: 6, type: 'projet', titre: 'Nouveau projet créé — Module CRM', desc: 'Chef de projet : Moussa Diallo · Priorité haute', auteur: 'Moussa Diallo', initiales: 'MD', time: '28 Avr, 16:00', color: AppColors.emerald),
    const ActivityItem(id: 7, type: 'paiement', titre: 'Rappel de paiement envoyé', desc: 'Facture #4402 · Tech Corp — J+15', auteur: 'Sara El Mansouri', initiales: 'SM', time: '28 Avr, 10:15', color: AppColors.purple),
    const ActivityItem(id: 8, type: 'equipe', titre: 'Jean-Luc Traoré assigné au Projet Alpha', desc: 'Rôle : Développeur Backend', auteur: 'Koffi Lambert', initiales: 'KL', time: '27 Avr, 14:20', color: AppColors.primary),
    const ActivityItem(id: 9, type: 'document', titre: 'BL #KLR-B001-240426 validé', desc: "Client : Advans Côte d'Ivoire", auteur: 'Koffi Lambert', initiales: 'KL', time: '27 Avr, 09:00', color: AppColors.primary),
    const ActivityItem(id: 10, type: 'facture', titre: 'Facture #KLR-F003-180326 marquée payée', desc: 'Acme Corp — 5 200 000 FCFA', auteur: 'Sara El Mansouri', initiales: 'SM', time: '25 Avr, 11:00', color: AppColors.purple),
  ];
}
