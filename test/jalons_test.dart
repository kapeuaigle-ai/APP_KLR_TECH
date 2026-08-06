import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _avecProjetJalons() {
  final s = AppState()..viderDonnees();
  s.addProjet(Projet(
    id: 1, nom: 'Câblage siège',
    type: 'Installation / déploiement', mode: ModeAvancement.jalons, clientId: 5,
    client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
  return s;
}

void main() {
  test('ajouterJalon puis marquerJalon font monter l\'avancement', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.ajouterJalon(1, Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3));

    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique, 0);

    s.marquerJalon(1, 0, DateTime(2026, 3, 16));
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique,
        closeTo(0.25, 0.0001));
  });

  test('démarquer un jalon fait redescendre l\'avancement', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.marquerJalon(1, 0, DateTime(2026, 3, 16));
    s.marquerJalon(1, 0, null);
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique, 0);
  });

  test('supprimerJalon retire l\'étape visée', () {
    final s = _avecProjetJalons();
    s.ajouterJalon(1, Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 15), poids: 1));
    s.ajouterJalon(1, Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 15), poids: 3));
    s.supprimerJalon(1, 0);
    expect(s.projets.first.jalons, hasLength(1));
    expect(s.projets.first.jalons.first.nom, 'Pose');
  });

  test('un index hors bornes ne provoque pas d\'erreur', () {
    final s = _avecProjetJalons();
    s.marquerJalon(1, 9, DateTime(2026, 3, 16));
    s.supprimerJalon(1, 9);
    expect(s.projets.first.jalons, isEmpty);
  });

  test('setAvancementManuel borne la valeur dans [0, 1]', () {
    final s = _avecProjetJalons();
    s.setAvancementManuel(1, 1.5);
    expect(s.projets.first.avancementManuel, 1);
    s.setAvancementManuel(1, -0.2);
    expect(s.projets.first.avancementManuel, 0);
    s.setAvancementManuel(1, 0.4);
    expect(s.projets.first.avancementManuel, closeTo(0.4, 0.0001));
  });
}
