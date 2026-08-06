import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/migration.dart';
import 'package:klr_tech_app/core/models.dart';

/// v2 → v3 : suppression de `settings.tva` et correction du montant des
/// documents — voir le commentaire de `migrerV2versV3`. Un document devait
/// valoir la somme de ses lignes ; il pouvait auparavant valoir un TTC
/// (proforma/facture créées depuis l'écran) sans que rien ne le corrige.
Map<String, dynamic> _v2({double tva = 5.0}) => {
  'version': 2,
  'clients': [],
  'documents': {
    'proforma': [
      {
        'id': 1, 'numero': 'KLR-P01-10012026', 'date': '10/01/2026',
        'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
        // Bug d'origine : le TTC (HT × 1,05) était stocké ici.
        'montant': 1575000.0, 'statut': 'validee', 'dateAffichee': '',
        'projetId': null,
        'lines': [
          {'ref': '01', 'designation': 'Développement', 'qte': 1, 'pu': 950000.0, 'qteLivree': 0},
          {'ref': '02', 'designation': 'Intégration', 'qte': 1, 'pu': 350000.0, 'qteLivree': 0},
          {'ref': '03', 'designation': 'Formation', 'qte': 2, 'pu': 100000.0, 'qteLivree': 0},
        ],
      },
    ],
    'facture': [
      {
        'id': 2, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
        'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
        'montant': 1575000.0, 'statut': 'cours', 'dateAffichee': '',
        'projetId': null,
        'lines': [
          {'ref': '01', 'designation': 'Développement', 'qte': 1, 'pu': 950000.0, 'qteLivree': 0},
          {'ref': '02', 'designation': 'Intégration', 'qte': 1, 'pu': 350000.0, 'qteLivree': 0},
          {'ref': '03', 'designation': 'Formation', 'qte': 2, 'pu': 100000.0, 'qteLivree': 0},
        ],
      },
    ],
    'bl': [
      {
        'id': 3, 'numero': 'KLR-B01-10012026', 'date': '10/01/2026',
        'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
        // Le BL ne porte aucun montant, par convention (validateProforma).
        'montant': 0.0, 'statut': 'cours', 'dateAffichee': '', 'projetId': null,
        'lines': [
          {'ref': '01', 'designation': 'Développement', 'qte': 1, 'pu': 950000.0, 'qteLivree': 0},
        ],
      },
    ],
  },
  // L'engagement, lui, était déjà correct (HT, comme `factureHt` l'a toujours
  // calculé) : c'est le règlement en entier qui a fait disparaître les 75 000
  // F d'écart avec la facture (le manager avait paramétré la TVA à 5 % —
  // AppState.ajouterReglement écrête au reste dû de l'engagement).
  'engagements': [
    {
      'id': 10, 'sens': 'entrant', 'projetId': null,
      'documentNumero': 'KLR-F01-10012026', 'clientId': 5, 'tiers': 'ACME',
      'description': 'PC', 'montant': 1500000.0,
      'echeance': DateTime(2026, 1, 10).toIso8601String(),
      'categorie': 'Autres', 'annule': false,
      'reglements': [
        {'id': 100, 'date': DateTime(2026, 1, 15).toIso8601String(),
          'montant': 1500000.0, 'moyen': 'especes'},
      ],
    },
  ],
  'activities': [], 'tasks': [], 'notes': [], 'projets': [],
  'settings': {
    'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
    'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
    'tva': tva, 'conditions': '',
  },
  'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _docs(Map<String, dynamic> v3, String type) =>
    ((v3['documents'] as Map)[type] as List).cast<Map<String, dynamic>>();

void main() {
  test('une sauvegarde déjà en v3 traverse la migration inchangée', () {
    final v3 = {'version': 3, 'engagements': [], 'documents': {}};
    expect(migrerV2versV3(v3), same(v3));
  });

  test('la sortie porte version 3', () {
    final v3 = migrerV2versV3(_v2());
    expect(v3['version'], 3);
  });

  test('settings.tva disparaît', () {
    final v3 = migrerV2versV3(_v2());
    final settings = v3['settings'] as Map;
    expect(settings.containsKey('tva'), isFalse);
    // Le reste des réglages survit intact.
    expect(settings['company'], 'KLR TECH');
    expect(settings['prefix'], 'KLR');
  });

  test('le montant de la proforma devient la somme de ses lignes (HT, pas TTC)', () {
    final v3 = migrerV2versV3(_v2());
    final p = _docs(v3, 'proforma').first;
    expect(p['montant'], 1500000.0, reason: '950000 + 350000 + 2×100000, pas ×1,05');
  });

  test('le montant de la facture devient la somme de ses lignes', () {
    final v3 = migrerV2versV3(_v2());
    final f = _docs(v3, 'facture').first;
    expect(f['montant'], 1500000.0);
  });

  test('le bon de livraison garde son montant à 0, jamais recalculé', () {
    final v3 = migrerV2versV3(_v2());
    final bl = _docs(v3, 'bl').first;
    // La ligne du BL vaut 950000 : si elle était sommée comme pour une
    // facture, le BL se retrouverait avec un prix qu'il ne doit jamais avoir.
    expect(bl['montant'], 0.0);
  });

  test('les engagements ne bougent pas : ils étaient déjà en HT', () {
    final j = _v2();
    final v3 = migrerV2versV3(j);
    // Même liste, pas une copie : la clé n'est jamais réécrite.
    expect(v3['engagements'], same(j['engagements']));
  });

  test('une seconde migration est un no-op (idempotence)', () {
    final v3 = migrerV2versV3(_v2());
    final v3bis = migrerV2versV3(v3);
    expect(v3bis, same(v3));
  });

  test('tolère une sauvegarde sans documents ni settings', () {
    final j = {'version': 2, 'engagements': []};
    expect(() => migrerV2versV3(j), returnsNormally);
    expect(migrerV2versV3(j)['version'], 3);
  });

  test('tolère des lignes avec qte/pu manquants ou corrompus', () {
    final j = _v2();
    (((j['documents'] as Map)['proforma'] as List).first
        as Map<String, dynamic>)['lines'] = [
      <String, dynamic>{'ref': 'A', 'designation': 'A', 'qte': null, 'pu': 'abc', 'qteLivree': 0},
    ];
    final v3 = migrerV2versV3(j);
    expect(_docs(v3, 'proforma').first['montant'], 0.0);
  });

  // La preuve que le manager attend : la migration corrige l'AFFICHAGE des
  // documents, jamais la COMPTABILITÉ — celle-ci a toujours sommé les lignes
  // (le HT), jamais `DocumentItem.montant`. Le bilan mensuel, qui ne dépend
  // que des règlements des engagements (inchangés par cette migration), doit
  // donc être rigoureusement identique avant et après.
  test('le bilan mensuel est identique au centime avant et après la migration', () {
    final v2 = _v2(); // écart TTC/HT delibéré sur la facture (§ ci-dessus)
    final v3 = migrerV2versV3(v2);

    Engagement engagementDe(Map<String, dynamic> j) =>
        Engagement.fromJson((j['engagements'] as List).first as Map<String, dynamic>);

    final avant = Comptabilite.bilanMensuel([engagementDe(v2)], const {}, const {});
    final apres = Comptabilite.bilanMensuel([engagementDe(v3)], const {}, const {});

    expect(avant.length, 1, reason: 'un mois avec mouvement : janvier 2026');
    expect(avant.length, apres.length);
    for (var i = 0; i < avant.length; i++) {
      expect(apres[i].monthKey, avant[i].monthKey);
      expect(apres[i].revenuHt, avant[i].revenuHt);
      expect(apres[i].depenses, avant[i].depenses);
      expect(apres[i].benefice, avant[i].benefice);
      expect(apres[i].dime, avant[i].dime);
    }
    // Chiffre concret, pour que le rapprochement soit lisible et pas
    // seulement une égalité entre deux copies du même nombre : c'est le HT
    // réellement encaissé (1 500 000), jamais le TTC affiché sur la facture
    // avant migration (1 575 000).
    expect(avant.first.revenuHt, 1500000.0);
    expect(apres.first.revenuHt, 1500000.0);
  });
}
