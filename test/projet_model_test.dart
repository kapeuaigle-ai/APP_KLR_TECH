import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('un projet neuf n\'a ni jalon ni annulation', () {
    final p = Projet(
      id: 1, nom: 'Fourniture matériel', typeId: 'fourniture',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
    );
    expect(p.jalons, isEmpty);
    expect(p.annule, isFalse);
    expect(p.avancementManuel, 0);
  });

  test('aller-retour JSON complet', () {
    final p = Projet(
      id: 7, nom: 'Câblage siège', typeId: 'installation',
      clientId: 5, client: 'ACME',
      debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      avancementManuel: 0.35, annule: true,
      jalons: [
        Jalon(nom: 'Étude', prevue: DateTime(2026, 3, 10),
              realisee: DateTime(2026, 3, 12), poids: 2),
        Jalon(nom: 'Pose', prevue: DateTime(2026, 5, 20), poids: 3),
      ],
    );
    final c = Projet.fromJson(p.toJson());
    expect(c.id, 7);
    expect(c.nom, 'Câblage siège');
    expect(c.typeId, 'installation');
    expect(c.clientId, 5);
    expect(c.client, 'ACME');
    expect(c.debut, DateTime(2026, 3, 1));
    expect(c.finPrevue, DateTime(2026, 6, 30));
    expect(c.avancementManuel, 0.35);
    expect(c.annule, isTrue);
    expect(c.jalons.length, 2);
    expect(c.jalons[0].nom, 'Étude');
    expect(c.jalons[0].realisee, DateTime(2026, 3, 12));
    expect(c.jalons[0].poids, 2);
    expect(c.jalons[1].realisee, isNull);
  });

  test('un projet interne n\'a pas de client', () {
    final p = Projet(
      id: 2, nom: 'Refonte interne', typeId: 'interne',
      clientId: null, client: '',
      debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 2, 1),
    );
    final c = Projet.fromJson(p.toJson());
    expect(c.clientId, isNull);
    expect(c.client, '');
  });

  test('les quatre modes d\'avancement existent', () {
    expect(ModeAvancement.values, hasLength(4));
    expect(ModeAvancement.values.map((m) => m.name).toSet(),
        {'quantites', 'jalons', 'duree', 'manuel'});
  });
}
