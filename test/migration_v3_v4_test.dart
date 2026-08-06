import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/migration.dart';

/// v3 → v4 : le registre `settings.typesProjet` disparaît — voir le
/// commentaire de `migrerV3versV4`. Chaque projet portait un `typeId`
/// pointant dedans, pour un libellé et un mode que le registre confondait
/// dans une seule entité. Après migration, chaque projet porte directement
/// `type` (le libellé du type retrouvé) et `mode` (son mode), et
/// `settings.typesProjet` n'existe plus.
List<Map<String, dynamic>> _typesProjet() => [
  {'id': 'fourniture', 'libelle': 'Fourniture de matériel', 'mode': 'quantites', 'couleur': 0xFF2563EB},
  {'id': 'installation', 'libelle': 'Installation / déploiement', 'mode': 'jalons', 'couleur': 0xFFF59E0B},
  {'id': 'maintenance', 'libelle': 'Maintenance / contrat', 'mode': 'duree', 'couleur': 0xFF10B981},
  {'id': 'interne', 'libelle': 'Projet interne', 'mode': 'manuel', 'couleur': 0xFF8B5CF6},
];

Map<String, dynamic> _projet(int id, String typeId) => {
  'id': id, 'nom': 'Projet $id', 'typeId': typeId,
  'clientId': null, 'client': '',
  'debut': DateTime(2026, 1, 1).toIso8601String(),
  'finPrevue': DateTime(2026, 6, 30).toIso8601String(),
  'jalons': [], 'avancementManuel': 0, 'annule': false,
};

Map<String, dynamic> _v3({List<Map<String, dynamic>>? projets}) => {
  'version': 3,
  'clients': [],
  'documents': {'proforma': [], 'facture': [], 'bl': []},
  'engagements': [],
  'activities': [], 'tasks': [], 'notes': [],
  'projets': projets ?? [],
  'settings': {
    'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
    'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01', 'conditions': '',
    'typesProjet': _typesProjet(),
  },
  'dimePaidMonths': [], 'dimePaidDates': {},
  'moisCourant': '2026-07', 'nextActivityId': 1000,
};

List<Map<String, dynamic>> _projetsDe(Map<String, dynamic> v4) =>
    (v4['projets'] as List).cast<Map<String, dynamic>>();

void main() {
  test('une sauvegarde déjà en v4 traverse la migration inchangée', () {
    final v4 = {'version': 4, 'engagements': [], 'documents': {}, 'projets': []};
    expect(migrerV3versV4(v4), same(v4));
  });

  test('la sortie porte version 4', () {
    final v4 = migrerV3versV4(_v3());
    expect(v4['version'], 4);
  });

  test('settings.typesProjet disparaît', () {
    final v4 = migrerV3versV4(_v3());
    final settings = v4['settings'] as Map;
    expect(settings.containsKey('typesProjet'), isFalse);
    // Le reste des réglages survit intact.
    expect(settings['company'], 'KLR TECH');
    expect(settings['prefix'], 'KLR');
  });

  // Un projet par mode : les quatre types par défaut couvrent les quatre
  // modes, chacun doit migrer vers son libellé et son mode corrects.
  test('un projet en mode quantites migre vers son libellé et son mode', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(1, 'fourniture')]));
    final p = _projetsDe(v4).first;
    expect(p['type'], 'Fourniture de matériel');
    expect(p['mode'], 'quantites');
    expect(p.containsKey('typeId'), isFalse);
  });

  test('un projet en mode jalons migre vers son libellé et son mode', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(2, 'installation')]));
    final p = _projetsDe(v4).first;
    expect(p['type'], 'Installation / déploiement');
    expect(p['mode'], 'jalons');
  });

  test('un projet en mode duree migre vers son libellé et son mode', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(3, 'maintenance')]));
    final p = _projetsDe(v4).first;
    expect(p['type'], 'Maintenance / contrat');
    expect(p['mode'], 'duree');
  });

  test('un projet en mode manuel migre vers son libellé et son mode', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(4, 'interne')]));
    final p = _projetsDe(v4).first;
    expect(p['type'], 'Projet interne');
    expect(p['mode'], 'manuel');
  });

  // Un `typeId` qui ne correspond à aucun type du registre — déjà toléré
  // avant cette version (AppState.modeDuProjet retombait sur `quantites`) —
  // ne doit jamais faire planter la migration.
  test('un typeId qui ne correspond à aucun type devient type vide, mode quantites', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(5, 'type_disparu')]));
    final p = _projetsDe(v4).first;
    expect(p['type'], '');
    expect(p['mode'], 'quantites');
  });

  test('plusieurs projets migrent chacun indépendamment', () {
    final v4 = migrerV3versV4(_v3(projets: [
      _projet(1, 'fourniture'),
      _projet(2, 'installation'),
      _projet(3, 'type_disparu'),
    ]));
    final projets = _projetsDe(v4);
    expect(projets, hasLength(3));
    expect(projets[0]['type'], 'Fourniture de matériel');
    expect(projets[1]['type'], 'Installation / déploiement');
    expect(projets[2]['type'], '');
  });

  test('une seconde migration est un no-op (idempotence)', () {
    final v4 = migrerV3versV4(_v3(projets: [_projet(1, 'fourniture')]));
    final v4bis = migrerV3versV4(v4);
    expect(v4bis, same(v4));
  });

  test('tolère une sauvegarde sans projets ni settings', () {
    final j = {'version': 3, 'engagements': []};
    expect(() => migrerV3versV4(j), returnsNormally);
    expect(migrerV3versV4(j)['version'], 4);
  });

  test('tolère des settings sans typesProjet du tout', () {
    final j = _v3(projets: [_projet(1, 'fourniture')]);
    (j['settings'] as Map).remove('typesProjet');
    final v4 = migrerV3versV4(j);
    // Aucun registre à consulter : comme un typeId disparu.
    expect(_projetsDe(v4).first['type'], '');
    expect(_projetsDe(v4).first['mode'], 'quantites');
  });
}
