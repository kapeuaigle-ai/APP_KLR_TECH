import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  AppState avecProjet() {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Fourniture ACME',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: 5,
      client: 'ACME', debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30)));
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10032026', date: '10/03/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours', projetId: 1,
      lines: [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)]));
    return s;
  }

  test('setQuantiteLivree met à jour la ligne de la proforma', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 6);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 6);
  });

  test('la quantité livrée est bornée à la quantité commandée', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 25);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 10);
  });

  test('une quantité négative est ramenée à zéro', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, -3);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 0);
  });

  test('un index de ligne hors bornes ne provoque pas d\'erreur', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 9, 5);
    expect(s.documents['proforma']!.first.lines.first.qteLivree, 0);
  });

  test('la saisie modifie l\'avancement physique du projet', () {
    final s = avecProjet();
    s.setQuantiteLivree(1, 0, 4);
    expect(s.avancementProjet(1, now: DateTime(2026, 4, 1)).physique,
        closeTo(0.4, 0.0001));
  });

  test('la facture et le BL ne bougent pas', () {
    final s = avecProjet();
    s.validateProforma(1);
    s.setQuantiteLivree(1, 0, 6);
    expect(s.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s.documents['bl']!.first.lines.first.qteLivree, 0);
  });
}
