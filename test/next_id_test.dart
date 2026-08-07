import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/comptabilite.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Défaut 2 (revue Lot A) : les ids étaient mintés depuis l'horloge
/// (`DateTime.now().millisecondsSinceEpoch`), qui renvoie la MÊME
/// milliseconde pour des milliers d'appels consécutifs sur certaines
/// machines — validé 500 proformas d'affilée, 498 ids distincts seulement.
/// Deux engagements partageant un id, `deleteEngagement(id)` (un
/// `removeWhere`) supprimait les DEUX à la fois.
///
/// `AppState.nextId()` remplace toute source horloge par un compteur unique,
/// monotone, jamais réutilisé — voir `AppState._seedNextId`.
class MemoryStore implements Store {
  String? data;
  int writes = 0;
  @override
  Future<String?> read() async => data;
  @override
  void write(String d) { data = d; writes++; }
  @override
  Future<void> writeBackup(String d) async {}
  @override
  Future<void> clear() async { data = null; }
}

void main() {
  test('1000 ids consécutifs sont tous distincts', () {
    final s = AppState(store: const NoopStore());
    final ids = List.generate(1000, (_) => s.nextId());
    expect(ids.toSet().length, 1000);
  });

  test('les ids survivent à une sauvegarde puis un rechargement, et '
      'continuent au-dessus du maximum précédent', () async {
    final store = MemoryStore();
    final a = AppState(store: store)..viderDonnees();
    final id1 = a.nextId();
    a.addClient(Client(id: id1, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'Client', contact: '', email: '', phone: ''));
    await a.flush();

    final b = AppState(store: store);
    await b.init();
    final id2 = b.nextId();
    expect(id2, greaterThan(id1));
  });

  test('un fichier restauré dont les ids dépassent le compteur stocké '
      'donne quand même un id neuf, non collisionnant', () async {
    // Simule un fichier corrigé à la main ou fusionné : le compteur
    // persisté (5) est très en dessous d'un id réellement présent (99999).
    // Un rechargement naïf du seul compteur redistribuerait 6, 7, 8... et
    // collisionnerait avec des ids déjà pris ailleurs dans le fichier.
    final j = <String, dynamic>{
      'clients': [
        {
          'id': 99999, 'initials': 'HM', 'color': 0xFF123456,
          'name': 'Client fusionné', 'contact': '', 'email': '', 'phone': '',
          'totalFacture': 0.0, 'address': '',
        },
      ],
      'documents': {'proforma': [], 'facture': [], 'bl': []},
      'engagements': [],
      'activities': [], 'tasks': [], 'notes': [],
      'projets': [],
      'settings': {
        'company': 'KLR TECH', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
        'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
        'conditions': '',
      },
      'dimePaidMonths': [], 'dimePaidDates': {},
      'moisCourant': Comptabilite.monthKeyFromDate(DateTime.now()),
      'nextActivityId': 1000,
      'nextId': 5,
      'version': 4,
    };
    final store = MemoryStore()..data = jsonEncode(j);
    final a = AppState(store: store);
    await a.init();

    final nouveau = a.nextId();
    expect(nouveau, greaterThan(99999));
  });

  test('valider de nombreuses proformas en boucle serrée produit des ids '
      'facture, BL et engagement tous distincts (reproduction du défaut 2)',
      () {
    final s = AppState()..viderDonnees();
    const n = 500;
    for (var i = 0; i < n; i++) {
      final id = s.nextId();
      s.saveOrUpdateProforma(DocumentItem(
        id: id, numero: 'KLR-P01-${i.toString().padLeft(6, '0')}',
        date: '01/01/2026', clientId: 0, client: 'C', objet: 'O',
        montant: 1000, statut: 'cours',
      ));
      s.validateProforma(id);
    }

    final factureIds = s.documents['facture']!.map((d) => d.id).toSet();
    final blIds = s.documents['bl']!.map((d) => d.id).toSet();
    final engagementIds = s.engagements.map((e) => e.id).toSet();

    expect(factureIds.length, n, reason: 'ids de facture tous distincts');
    expect(blIds.length, n, reason: 'ids de BL tous distincts');
    expect(engagementIds.length, n, reason: 'ids d\'engagement tous distincts');

    // Aucun chevauchement entre les trois espaces : tous partagent
    // désormais le même compteur.
    final tous = {...factureIds, ...blIds, ...engagementIds};
    expect(tous.length, 3 * n);
  });

  test('deleteEngagement ne supprime que l\'engagement visé, jamais un '
      'autre', () {
    final s = AppState()..viderDonnees();
    final id1 = s.nextId();
    final id2 = s.nextId();
    s.addEngagement(Engagement(id: id1, sens: 'entrant', tiers: 'A',
        montant: 1000, echeance: DateTime(2026, 12, 31)));
    s.addEngagement(Engagement(id: id2, sens: 'sortant', tiers: 'B',
        montant: 2000, echeance: DateTime(2026, 12, 31)));

    s.deleteEngagement(id1);

    expect(s.engagements.length, 1);
    expect(s.engagements.single.id, id2);
    expect(s.engagements.any((e) => e.id == id1), isFalse);
  });
}
