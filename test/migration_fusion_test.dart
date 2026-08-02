import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/migration.dart';

Map<String, dynamic> _facture({
  required int id, required String numero, required int clientId,
  required String client, required double pu,
}) => {
  'id': id, 'numero': numero, 'date': '10/01/2026', 'clientId': clientId,
  'client': client, 'clientAddr': '', 'objet': 'Fourniture',
  'montant': pu, 'statut': 'validee',
  'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': pu}],
  'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
};

Map<String, dynamic> _creance({
  required int id, required String num, required String tiers,
  required double montant,
}) => {
  'id': id, 'sens': 'creance', 'num': num, 'tiers': tiers,
  'description': '', 'montant': montant, 'statut': 'cours',
  'echeance': '30/06/2026', 'dateReglement': null, 'categorie': 'Autres',
  'acompte': 0.0, 'dateAcompte': null,
};

Map<String, dynamic> _save({
  List<Map<String, dynamic>> factures = const [],
  List<Map<String, dynamic>> engagements = const [],
}) => {
  'clients': [],
  'documents': {'proforma': [], 'facture': factures, 'bl': []},
  'engagements': engagements,
  'expenses': [],
  'activities': [], 'tasks': [], 'notes': [], 'settings': {},
  'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _engs(Map<String, dynamic> v2) =>
    (v2['engagements'] as List).cast<Map<String, dynamic>>();

void main() {
  test('branche 1 : le numéro de facture figure dans la référence libre', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1, reason: 'fusion : un seul engagement');
    expect(_engs(v2).first['documentNumero'], 'KLR-F01-10012026');
    expect(_engs(v2).first['clientId'], 5);
  });

  test('branche 1 : la normalisation ignore tirets, espaces et casse', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'klr f01 10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1);
  });

  test('branche 2 : même client et même montant fusionnent, et sont marqués ambigus', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Bon de commande 42', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 1);
    expect(_engs(v2).first['fusionAmbigue'], isTrue);
    expect(_engs(v2).first['documentNumero'], 'KLR-F01-10012026');
  });

  test('même montant mais clients différents : AUCUNE fusion', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 500000)],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'BETA', montant: 500000)],
    ));
    expect(_engs(v2).length, 2, reason: 'deux tiers distincts, deux engagements');
  });

  test('même client mais montants différents : AUCUNE fusion', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'ACME', montant: 900)],
    ));
    expect(_engs(v2).length, 2);
  });

  test('une créance n\'est appariée qu\'une fois, même si deux factures correspondent', () {
    final v2 = migrerV1versV2(_save(
      factures: [
        _facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800),
        _facture(id: 2, numero: 'KLR-F02-11012026', clientId: 5, client: 'ACME', pu: 800),
      ],
      engagements: [_creance(id: 10, num: 'Contrat', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).length, 2, reason: '1 créance fusionnée + 1 facture restante');
    final numeros = _engs(v2).map((e) => e['documentNumero']).toSet();
    expect(numeros, {'KLR-F01-10012026', 'KLR-F02-11012026'});
  });

  test('une dette n\'est jamais appariée à une facture', () {
    final dette = _creance(id: 10, num: 'KLR-F01-10012026', tiers: 'ACME', montant: 800);
    dette['sens'] = 'dette';
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [dette],
    ));
    expect(_engs(v2).length, 2);
  });
}
