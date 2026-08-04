import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _p(String typeId) => Projet(
      id: 1, nom: 'P', typeId: typeId, clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30));

void main() {
  test('une sauvegarde sans types reçoit les quatre types par défaut', () {
    final s = AppSettings.fromJson({
      'company': 'KLR', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
      'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
      'tva': 0.0, 'conditions': '',
    });
    expect(s.typesProjet, hasLength(4));
    expect(s.typesProjet.map((t) => t.id), contains('fourniture'));
  });

  test('les types survivent à un aller-retour JSON', () {
    final s = AppSettings.fromJson({
      'company': 'KLR', 'address': '', 'bp': '', 'rccm': '', 'regime': '',
      'tel': '', 'email': '', 'prefix': 'KLR', 'startNum': '01',
      'tva': 0.0, 'conditions': '',
    });
    s.typesProjet.add(TypeProjet(id: 'formation', libelle: 'Formation',
        mode: ModeAvancement.jalons, couleur: const Color(0xFF111111)));

    final c = AppSettings.fromJson(s.toJson());
    expect(c.typesProjet, hasLength(5));
    final f = c.typesProjet.firstWhere((t) => t.id == 'formation');
    expect(f.mode, ModeAvancement.jalons);
  });

  test('modeDuProjet lit le mode de son type', () {
    final s = AppState()..viderDonnees();
    expect(s.modeDuProjet(_p('installation')), ModeAvancement.jalons);
    expect(s.modeDuProjet(_p('maintenance')), ModeAvancement.duree);
    expect(s.modeDuProjet(_p('interne')), ModeAvancement.manuel);
    expect(s.modeDuProjet(_p('fourniture')), ModeAvancement.quantites);
  });

  test('un projet dont le type a été supprimé retombe sur quantites', () {
    final s = AppState()..viderDonnees();
    expect(s.modeDuProjet(_p('type_disparu')), ModeAvancement.quantites);
  });

  test('supprimer un type bascule ses projets sur le premier type restant', () {
    final s = AppState()..viderDonnees();
    s.addProjet(_p('installation'));
    s.supprimerTypeProjet('installation');

    expect(s.settings.typesProjet.map((t) => t.id), isNot(contains('installation')));
    expect(s.projets.first.typeId, s.settings.typesProjet.first.id,
        reason: 'aucun projet ne doit pointer vers un type disparu');
  });

  test('le dernier type ne peut pas être supprimé', () {
    final s = AppState()..viderDonnees();
    for (final t in List.of(s.settings.typesProjet)) {
      s.supprimerTypeProjet(t.id);
    }
    expect(s.settings.typesProjet, hasLength(1));
  });
}
