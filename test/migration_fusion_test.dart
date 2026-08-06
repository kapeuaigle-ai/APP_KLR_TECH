import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/migration.dart';
import 'package:klr_tech_app/core/models.dart';

Map<String, dynamic> _facture({
  required int id, required String numero, required int clientId,
  required String client, required double pu,
  bool encaissee = false, String? dateEncaissement,
}) => {
  'id': id, 'numero': numero, 'date': '10/01/2026', 'clientId': clientId,
  'client': client, 'clientAddr': '', 'objet': 'Fourniture',
  'montant': pu, 'statut': 'validee',
  'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': pu}],
  'encaissee': encaissee, 'dateEncaissement': dateEncaissement, 'dateAffichee': '',
};

Map<String, dynamic> _creance({
  required int id, required String num, required String tiers,
  required double montant,
  String statut = 'cours', double acompte = 0.0, String? dateAcompte,
  String? dateReglement,
}) => {
  'id': id, 'sens': 'creance', 'num': num, 'tiers': tiers,
  'description': '', 'montant': montant, 'statut': statut,
  'echeance': '30/06/2026', 'dateReglement': dateReglement, 'categorie': 'Autres',
  'acompte': acompte, 'dateAcompte': dateAcompte,
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

  // ── Défaut 1 : un encaissement réel ne doit jamais disparaître dans une
  //    fusion (§ 8.1). ──────────────────────────────────────────────────

  test('un encaissement réel de la facture est reporté sur l\'engagement fusionné (branche 1)', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800,
          encaissee: true, dateEncaissement: '15/02/2026')],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    final e = _engs(v2).single;
    final regs = (e['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs, hasLength(1));
    expect(regs.single['montant'], 800.0);
    expect(DateTime.parse(regs.single['date']), DateTime(2026, 2, 15));
    expect(e['fusionAmbigue'], isTrue);
  });

  test('même chose via la branche 2 (même client, même montant)', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800,
          encaissee: true, dateEncaissement: '15/02/2026')],
      engagements: [_creance(id: 10, num: 'Bon de commande 42', tiers: 'ACME', montant: 800)],
    ));
    final e = _engs(v2).single;
    final regs = (e['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs, hasLength(1));
    expect(regs.single['montant'], 800.0);
    expect(DateTime.parse(regs.single['date']), DateTime(2026, 2, 15));
    expect(e['fusionAmbigue'], isTrue);
  });

  test('une créance déjà soldée absorbe l\'encaissement facture sans le doubler', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800,
          encaissee: true, dateEncaissement: '15/02/2026')],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800,
          statut: 'paye', dateReglement: '01/02/2026')],
    ));
    final e = _engs(v2).single;
    final regs = (e['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs, hasLength(1), reason: 'le règlement de la créance seul, pas les deux');
    expect(regs.single['montant'], 800.0);
    expect(DateTime.parse(regs.single['date']), DateTime(2026, 2, 1),
        reason: 'la date du règlement de la créance, pas celle de la facture');
    expect(e['fusionAmbigue'], isTrue);
  });

  test('un acompte déjà présent sur la créance n\'est pas complété par la facture', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800,
          encaissee: true, dateEncaissement: '15/02/2026')],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800,
          acompte: 300, dateAcompte: '05/01/2026')],
    ));
    final e = _engs(v2).single;
    final regs = (e['reglements'] as List).cast<Map<String, dynamic>>();
    expect(regs, hasLength(1));
    expect(regs.single['montant'], 300.0);
    expect(e['fusionAmbigue'], isTrue);
  });

  test('une facture non encaissée ne fait apparaître aucun règlement', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 800)],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    final e = _engs(v2).single;
    expect((e['reglements'] as List), isEmpty);
    expect(e['fusionAmbigue'], isNot(true), reason: 'rien à vérifier : aucun paiement en jeu');
  });

  test('le montant fusionné retient le plus grand des deux (facture > créance)', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 900)],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).single['montant'], 900.0);
  });

  test('le montant fusionné retient le plus grand des deux (créance > facture)', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F01-10012026', clientId: 5, client: 'ACME', pu: 700)],
      engagements: [_creance(id: 10, num: 'Facture KLR-F01-10012026', tiers: 'ACME', montant: 800)],
    ));
    expect(_engs(v2).single['montant'], 800.0);
  });

  test('§ 8.2 appliqué au cas corrigé : le revenu du mois d\'encaissement '
      'égale la somme des lignes de la facture', () {
    final v2 = migrerV1versV2(_save(
      factures: [_facture(id: 1, numero: 'KLR-F09-20012026', clientId: 5, client: 'ACME', pu: 1234.5,
          encaissee: true, dateEncaissement: '15/02/2026')],
      engagements: [_creance(id: 10, num: 'Facture KLR-F09-20012026', tiers: 'ACME', montant: 1234.5)],
    ));
    final engagements = _engs(v2).map((e) => Engagement.fromJson(e)).toList();
    final bilan = Comptabilite.bilanMensuel(engagements, const {}, const {});
    final fevrier = bilan.firstWhere((r) => r.monthKey == '2026-02');
    expect(fevrier.revenu, 1234.5);
  });
}
