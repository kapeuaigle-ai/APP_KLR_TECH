import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/migration.dart';

/// Sauvegarde v1 minimale couvrant les quatre mécanismes d'origine.
Map<String, dynamic> _v1() => {
  'clients': [],
  'documents': {
    'proforma': [],
    'facture': [
      {
        'id': 1, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
        'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
        'montant': 800.0, 'statut': 'validee',
        'lines': [
          {'ref': 'PC1', 'designation': 'Ordinateur', 'qte': 2, 'pu': 300.0},
          {'ref': 'SW1', 'designation': 'Switch', 'qte': 1, 'pu': 200.0},
        ],
        'encaissee': true, 'dateEncaissement': '15/02/2026', 'dateAffichee': '',
      },
      {
        'id': 2, 'numero': 'KLR-F02-11012026', 'date': '11/01/2026',
        'clientId': 6, 'client': 'BETA', 'clientAddr': '', 'objet': 'Serveur',
        'montant': 5000.0, 'statut': 'cours',
        'lines': [
          {'ref': 'SRV', 'designation': 'Serveur', 'qte': 1, 'pu': 5000.0},
        ],
        'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
      },
    ],
    'bl': [],
  },
  'engagements': [
    {
      'id': 10, 'sens': 'creance', 'num': 'CTR-2026-01', 'tiers': 'GAMMA',
      'description': 'Maintenance', 'montant': 1200.0, 'statut': 'cours',
      'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
      'acompte': 400.0, 'dateAcompte': '03/03/2026',
    },
    {
      'id': 11, 'sens': 'dette', 'num': 'FRN-77', 'tiers': 'Fournisseur X',
      'description': 'Câbles', 'montant': 900.0, 'statut': 'paye',
      'echeance': '10/04/2026', 'dateReglement': '12/04/2026',
      'categorie': 'Achat matériel', 'acompte': 300.0, 'dateAcompte': '01/04/2026',
    },
  ],
  'expenses': [
    {
      'id': 20, 'date': DateTime(2026, 1, 12).toIso8601String(),
      'label': 'Licences', 'amount': 250.0, 'category': 'Achat matériel',
      'factureNumero': 'KLR-F01-10012026',
    },
  ],
  'activities': [], 'tasks': [], 'notes': [],
  'settings': {}, 'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _engs(Map<String, dynamic> v2) =>
    (v2['engagements'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic>? _parTiers(Map<String, dynamic> v2, String tiers) {
  final m = _engs(v2).where((e) => e['tiers'] == tiers);
  return m.isEmpty ? null : m.first;
}

double _regle(Map<String, dynamic> e) => (e['reglements'] as List)
    .fold(0.0, (s, r) => s + (r['montant'] as num).toDouble());

void main() {
  test('une sauvegarde déjà en v2 traverse la migration inchangée', () {
    final v2 = {'version': 2, 'engagements': [], 'documents': {}};
    expect(migrerV1versV2(v2), same(v2));
  });

  test('la sortie porte version 2 et n\'a plus de clé expenses', () {
    final v2 = migrerV1versV2(_v1());
    expect(v2['version'], 2);
    expect(v2.containsKey('expenses'), isFalse);
  });

  test('creance/dette deviennent entrant/sortant', () {
    final v2 = migrerV1versV2(_v1());
    expect(_parTiers(v2, 'GAMMA')!['sens'], 'entrant');
    expect(_parTiers(v2, 'Fournisseur X')!['sens'], 'sortant');
  });

  test('un acompte v1 devient un règlement à sa date', () {
    final gamma = _parTiers(migrerV1versV2(_v1()), 'GAMMA')!;
    final regs = (gamma['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 1);
    expect(regs.first['montant'], 400.0);
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 3, 3));
    expect(gamma['montant'], 1200.0);
  });

  test('un engagement payé avec acompte donne deux règlements, acompte puis solde', () {
    final frn = _parTiers(migrerV1versV2(_v1()), 'Fournisseur X')!;
    final regs = (frn['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 2);
    expect(regs[0]['montant'], 300.0);
    expect(DateTime.parse(regs[0]['date']), DateTime(2026, 4, 1));
    expect(regs[1]['montant'], 600.0, reason: 'le solde, pas le montant entier');
    expect(DateTime.parse(regs[1]['date']), DateTime(2026, 4, 12));
    expect(_regle(frn), 900.0);
  });

  test('une dépense devient un engagement sortant réglé le jour même', () {
    final v2 = migrerV1versV2(_v1());
    final dep = _engs(v2).firstWhere((e) => e['description'] == 'Licences');
    expect(dep['sens'], 'sortant');
    expect(dep['montant'], 250.0);
    expect(dep['categorie'], 'Achat matériel');
    expect(dep['documentNumero'], 'KLR-F01-10012026');
    final regs = (dep['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs.length, 1);
    expect(regs.first['montant'], 250.0);
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 1, 12));
  });

  test('une facture encaissée devient un engagement entrant soldé, montant = somme des lignes', () {
    final v2 = migrerV1versV2(_v1());
    final f = _engs(v2).firstWhere((e) => e['documentNumero'] == 'KLR-F01-10012026' && e['sens'] == 'entrant');
    expect(f['montant'], 800.0, reason: '2×300 + 1×200');
    expect(f['clientId'], 5);
    expect(_regle(f), 800.0);
    final regs = (f['reglements'] as List).cast<Map<String, dynamic>>();
    expect(DateTime.parse(regs.first['date']), DateTime(2026, 2, 15));
  });

  test('une facture non encaissée devient un engagement entrant sans règlement', () {
    final v2 = migrerV1versV2(_v1());
    final f = _engs(v2).firstWhere((e) => e['documentNumero'] == 'KLR-F02-11012026');
    expect(f['montant'], 5000.0);
    expect((f['reglements'] as List), isEmpty);
  });

  test('les factures ne portent plus encaissee ni dateEncaissement', () {
    final v2 = migrerV1versV2(_v1());
    final factures = ((v2['documents'] as Map)['facture'] as List).cast<Map<String, dynamic>>();
    for (final f in factures) {
      expect(f.containsKey('encaissee'), isFalse);
      expect(f.containsKey('dateEncaissement'), isFalse);
    }
  });

  test('les identifiants produits sont tous distincts', () {
    final v2 = migrerV1versV2(_v1());
    final ids = _engs(v2).map((e) => e['id']).toList();
    expect(ids.toSet().length, ids.length);
    final regIds = _engs(v2)
        .expand((e) => (e['reglements'] as List).map((r) => r['id'])).toList();
    expect(regIds.toSet().length, regIds.length);
  });

  test('les lignes reçoivent qteLivree = 0', () {
    final v2 = migrerV1versV2(_v1());
    final f = ((v2['documents'] as Map)['facture'] as List).first as Map<String, dynamic>;
    for (final l in (f['lines'] as List).cast<Map<String, dynamic>>()) {
      expect(l['qteLivree'], 0);
    }
  });

  test('une date d\'acompte illisible n\'interrompt pas la migration', () {
    final v1 = _v1();
    (v1['engagements'] as List).add({
      'id': 12, 'sens': 'creance', 'num': 'X', 'tiers': 'DELTA',
      'description': '', 'montant': 500.0, 'statut': 'cours',
      'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
      'acompte': 200.0, 'dateAcompte': 'pas une date',
    });

    final v2 = migrerV1versV2(v1);
    final delta = _parTiers(v2, 'DELTA')!;
    expect((delta['reglements'] as List), isEmpty,
        reason: 'l\'acompte sans date exploitable est ignoré, comme en v1');
    expect(delta['montant'], 500.0, reason: 'l\'engagement lui-même est conservé');
  });

  test('une date de règlement illisible n\'interrompt pas la migration', () {
    final v1 = _v1();
    (v1['engagements'] as List).add({
      'id': 13, 'sens': 'dette', 'num': 'Y', 'tiers': 'EPSILON',
      'description': '', 'montant': 700.0, 'statut': 'paye',
      'echeance': '30/06/2026', 'dateReglement': '', 'categorie': 'Autres',
      'acompte': 0.0, 'dateAcompte': null,
    });

    final v2 = migrerV1versV2(v1);
    final eps = _parTiers(v2, 'EPSILON')!;
    expect((eps['reglements'] as List), isEmpty);
    expect(eps['montant'], 700.0);
  });

  test('une dépense à date illisible garde son montant, sans règlement', () {
    final v1 = _v1();
    // Reconstruit la liste en List<Map<String, dynamic>> : la liste à un
    // seul élément de `_v1()` n'a aucune valeur `null`, donc Dart l'infère
    // `List<Map<String, Object>>` (non nullable), ce qui ferait échouer
    // `.add` d'une map contenant `factureNumero: null` avant même d'appeler
    // la migration — même piège d'inférence que pour les documents.
    v1['expenses'] = List<Map<String, dynamic>>.from(v1['expenses'] as List)
      ..add({
        'id': 21, 'date': 'corrompu', 'label': 'Dépense abîmée',
        'amount': 90.0, 'category': 'Transport', 'factureNumero': null,
      });

    final v2 = migrerV1versV2(v1);
    final dep = _engs(v2).firstWhere((e) => e['description'] == 'Dépense abîmée');
    expect(dep['montant'], 90.0, reason: 'le montant ne doit pas disparaître');
    expect((dep['reglements'] as List), isEmpty);
  });

  test('les enregistrements sains d\'une sauvegarde partiellement corrompue sont migrés', () {
    final v1 = _v1();
    (v1['engagements'] as List).add({
      'id': 14, 'sens': 'creance', 'num': 'Z', 'tiers': 'ZETA',
      'description': '', 'montant': 100.0, 'statut': 'paye',
      'echeance': 'illisible', 'dateReglement': 'illisible',
      'categorie': 'Autres', 'acompte': 0.0, 'dateAcompte': null,
    });

    final v2 = migrerV1versV2(v1);
    // Les conversions d'origine sont intactes.
    expect(_parTiers(v2, 'GAMMA')!['reglements'], hasLength(1));
    expect(_parTiers(v2, 'Fournisseur X')!['reglements'], hasLength(2));
  });

  test('un montant corrompu ne fait pas échouer la migration', () {
    final v1 = _v1();
    (v1['engagements'] as List).add(<String, dynamic>{
      'id': 15, 'sens': 'creance', 'num': 'W', 'tiers': 'OMEGA',
      'description': '', 'montant': null, 'statut': 'cours',
      'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
      'acompte': 'illisible', 'dateAcompte': '03/03/2026',
    });
    (v1['documents'] as Map)['facture'] = List<Map<String, dynamic>>.from(
        (v1['documents'] as Map)['facture'] as List)
      ..add(<String, dynamic>{
        'id': 3, 'numero': 'KLR-F03-12012026', 'date': '12/01/2026',
        'clientId': 7, 'client': 'THETA', 'clientAddr': '', 'objet': 'X',
        'montant': 100.0, 'statut': 'cours',
        'lines': [
          <String, dynamic>{'ref': 'A', 'designation': 'A', 'qte': null, 'pu': 50.0},
        ],
        'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
      });

    final v2 = migrerV1versV2(v1);

    final omega = _parTiers(v2, 'OMEGA')!;
    expect(omega['montant'], 0.0, reason: 'un montant illisible vaut 0, sans crash');
    expect((omega['reglements'] as List), isEmpty,
        reason: 'un acompte illisible ne produit pas de règlement');

    final theta = _engs(v2).firstWhere((e) => e['documentNumero'] == 'KLR-F03-12012026');
    expect(theta['montant'], 0.0, reason: 'une quantité illisible vaut 0');

    // Les enregistrements sains restent intacts.
    expect(_parTiers(v2, 'GAMMA')!['reglements'], hasLength(1));
    expect(_parTiers(v2, 'Fournisseur X')!['reglements'], hasLength(2));
  });
}
