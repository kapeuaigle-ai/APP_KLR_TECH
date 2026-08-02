import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';

void main() {
  test('une fusion ambiguë laisse une trace dans Activités', () {
    final v1 = {
      'clients': [],
      'documents': {
        'proforma': [], 'bl': [],
        'facture': [
          {
            'id': 1, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
            'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
            'montant': 800.0, 'statut': 'validee',
            'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': 800.0}],
            'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
          },
        ],
      },
      'engagements': [
        {
          'id': 10, 'sens': 'creance', 'num': 'Bon de commande 42',
          'tiers': 'ACME', 'description': '', 'montant': 800.0,
          'statut': 'cours', 'echeance': '30/06/2026', 'dateReglement': null,
          'categorie': 'Autres', 'acompte': 0.0, 'dateAcompte': null,
        },
      ],
      'expenses': [],
      'activities': [], 'tasks': [], 'notes': [],
      'settings': _settings(), 'dimePaidMonths': [], 'dimePaidDates': {},
      'moisCourant': '2026-07', 'nextActivityId': 1000,
    };

    final s = AppState()..loadFromJson(v1);

    expect(s.engagements.length, 1, reason: 'les deux ont fusionné');
    expect(
      s.activities.any((a) => a.titre.contains('Rapprochement')),
      isTrue,
      reason: 'la fusion ambiguë doit être signalée au manager',
    );
    expect(s.engagements.first.toJson().containsKey('fusionAmbigue'), isFalse,
        reason: 'le marqueur de migration ne doit pas être persisté');
  });

  test('une migration sans fusion ambiguë ne journalise rien', () {
    final v1 = {
      'clients': [],
      'documents': {
        'proforma': [], 'bl': [],
        'facture': [
          {
            'id': 1, 'numero': 'KLR-F01-10012026', 'date': '10/01/2026',
            'clientId': 5, 'client': 'ACME', 'clientAddr': '', 'objet': 'PC',
            'montant': 800.0, 'statut': 'validee',
            'lines': [{'ref': 'A', 'designation': 'Article', 'qte': 1, 'pu': 800.0}],
            'encaissee': false, 'dateEncaissement': null, 'dateAffichee': '',
          },
        ],
      },
      // Aucun engagement v1 : la facture ne peut être fusionnée avec rien.
      'engagements': [],
      'expenses': [],
      'activities': [], 'tasks': [], 'notes': [],
      'settings': _settings(), 'dimePaidMonths': [], 'dimePaidDates': {},
      'moisCourant': '2026-07', 'nextActivityId': 1000,
    };

    final s = AppState()..loadFromJson(v1);

    expect(s.engagements.length, 1, reason: 'la facture, non fusionnée');
    expect(
      s.activities.any((a) => a.titre.contains('Rapprochement')),
      isFalse,
      reason: 'sans fusion ambiguë, aucune alerte ne doit apparaître',
    );
  });
}

Map<String, dynamic> _settings() => {
  'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
  'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01', 'tva': 0.0,
  'conditions': '',
};
