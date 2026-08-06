import '../auth.dart';
import 'projet.dart';

/// Clause de garantie par défaut, affichée en bas de la dernière page des
/// documents. Éditable dans les Paramètres (`AppSettings.warranty`) ; sert
/// aussi de valeur de repli pour les anciennes sauvegardes et la pagination.
const kDefaultWarranty =
    'Tout produit, sauf mention contraire, bénéficie d\'une période de garantie '
    'contre tout vice de fabrication (retour atelier sans frais de réparation ou '
    'échange standard dans la limite des stocks disponibles) soumise à '
    'l\'expertise constructeur, à compter de la date de facturation et à '
    'condition qu\'il soit tenu en bon état et que les étiquettes de code '
    'ne soient pas retirées ou déchirées.';

// ── App Settings ─────────────────────────────────────────
class AppSettings {
  String company;
  String address;
  String bp;
  String rccm;
  String regime;
  String tel;
  String email;
  String prefix;
  String startNum;
  String conditions;
  /// Signature électronique du manager, image PNG encodée en base64.
  /// Vide = aucune signature : la case du document reste alors vierge.
  String signature;
  /// Légende libre affichée sous la signature (ex. « La Direction »).
  String signatureLabel;
  /// Clause de garantie affichée en bas de la dernière page. Personnalisable.
  String warranty;

  // ── Accès à l'application ──────────────────────────────
  /// Identifiant de connexion du manager.
  String username;
  /// Sel du mot de passe. Vide tant que le mot de passe par défaut est en place.
  String passwordSalt;
  /// Empreinte SHA-256 salée. Le mot de passe en clair n'est jamais conservé.
  String passwordHash;

  /// Types de projet définis par le manager. Jamais vide : supprimer le
  /// dernier est refusé, faute de quoi aucun projet ne serait créable.
  List<TypeProjet> typesProjet;

  AppSettings({
    required this.company, required this.address, required this.bp,
    required this.rccm, required this.regime, required this.tel,
    required this.email, required this.prefix,
    required this.startNum, required this.conditions,
    this.signature = '', this.signatureLabel = '',
    this.warranty = kDefaultWarranty,
    this.username = kDefaultUsername,
    this.passwordSalt = '', this.passwordHash = '',
    List<TypeProjet>? typesProjet,
  }) : typesProjet = typesProjet ?? TypeProjet.defauts;

  /// Vrai tant que le manager n'a pas défini son propre mot de passe : l'app
  /// accepte alors l'accès d'usine et affiche une alerte dans les Paramètres.
  bool get usesDefaultPassword => passwordHash.isEmpty;

  /// Vérifie un mot de passe saisi. Tant qu'aucun mot de passe n'a été défini,
  /// seul l'accès par défaut est accepté.
  bool checkPassword(String password) => usesDefaultPassword
      ? secureEquals(password, kDefaultPassword)
      : secureEquals(hashPassword(password, passwordSalt), passwordHash);

  /// Définit un nouveau mot de passe : nouveau sel, nouvelle empreinte.
  void setPassword(String password) {
    passwordSalt = newSalt();
    passwordHash = hashPassword(password, passwordSalt);
  }

  /// Ligne légale affichée en pied de page des documents.
  String get footerLine =>
      '$company $address - $bp - RCCM: $rccm '
      'Régime d\'imposition $regime - Tel: $tel - Email: $email';

  Map<String, dynamic> toJson() => {
    'company': company, 'address': address, 'bp': bp, 'rccm': rccm,
    'regime': regime, 'tel': tel, 'email': email, 'prefix': prefix,
    'startNum': startNum, 'conditions': conditions,
    'signature': signature, 'signatureLabel': signatureLabel,
    'warranty': warranty,
    'username': username,
    'passwordSalt': passwordSalt, 'passwordHash': passwordHash,
    'typesProjet': typesProjet.map((t) => t.toJson()).toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    company: j['company'], address: j['address'], bp: j['bp'], rccm: j['rccm'],
    regime: j['regime'], tel: j['tel'], email: j['email'], prefix: j['prefix'],
    startNum: j['startNum'], conditions: j['conditions'],
    // Rétro-compatible : les sauvegardes antérieures n'ont pas ces clés.
    signature: j['signature'] ?? '', signatureLabel: j['signatureLabel'] ?? '',
    warranty: j['warranty'] ?? kDefaultWarranty,
    // Sauvegarde antérieure à la connexion : on repart de l'accès par défaut.
    username: j['username'] ?? kDefaultUsername,
    passwordSalt: j['passwordSalt'] ?? '', passwordHash: j['passwordHash'] ?? '',
    // Sauvegarde antérieure à la phase 3 : passer `null` suffit, le
    // constructeur pose alors les quatre types par défaut.
    typesProjet: (j['typesProjet'] as List?)
        ?.map((t) => TypeProjet.fromJson(t)).toList(),
  );
}
