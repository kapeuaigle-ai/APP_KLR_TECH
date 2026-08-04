import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('aller-retour JSON, mode et couleur compris', () {
    final t = TypeProjet(
        id: 'installation', libelle: 'Installation réseau',
        mode: ModeAvancement.jalons, couleur: const Color(0xFF2563EB));
    final c = TypeProjet.fromJson(t.toJson());
    expect(c.id, 'installation');
    expect(c.libelle, 'Installation réseau');
    expect(c.mode, ModeAvancement.jalons);
    expect(c.couleur, const Color(0xFF2563EB));
  });

  test('un mode inconnu retombe sur quantites plutôt que de planter', () {
    final c = TypeProjet.fromJson({
      'id': 'x', 'libelle': 'X', 'mode': 'mode_qui_nexiste_pas',
      'couleur': 0xFF000000,
    });
    expect(c.mode, ModeAvancement.quantites);
  });

  test('les quatre types par défaut couvrent les quatre modes', () {
    final defauts = TypeProjet.defauts;
    expect(defauts, hasLength(4));
    expect(defauts.map((t) => t.mode).toSet(), ModeAvancement.values.toSet());
    expect(defauts.map((t) => t.id).toSet(), hasLength(4),
        reason: 'les identifiants doivent être distincts');
  });

  test('le type par défaut « fourniture » est en mode quantites', () {
    final f = TypeProjet.defauts.firstWhere((t) => t.id == 'fourniture');
    expect(f.mode, ModeAvancement.quantites);
  });
}
