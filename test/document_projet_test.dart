import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

void main() {
  test('une ligne neuve n\'a rien de livré', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300);
    expect(l.qteLivree, 0);
    expect(l.total, 3000);
    expect(l.totalLivre, 0);
  });

  test('totalLivre pondère par le prix unitaire', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6);
    expect(l.totalLivre, 1800);
  });

  test('aller-retour JSON d\'une ligne, qteLivree comprise', () {
    final l = LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6);
    final c = LineItem.fromJson(l.toJson());
    expect(c.qteLivree, 6);
    expect(c.qte, 10);
  });

  test('une ligne d\'une sauvegarde antérieure vaut 0 livré', () {
    final c = LineItem.fromJson({'ref': 'PC', 'designation': 'Ordinateur', 'qte': 10, 'pu': 300.0});
    expect(c.qteLivree, 0);
  });

  test('un document neuf est hors projet', () {
    final d = DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
    );
    expect(d.projetId, isNull);
  });

  test('aller-retour JSON d\'un document, projetId compris', () {
    final d = DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      projetId: 42,
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300, qteLivree: 6)],
    );
    final c = DocumentItem.fromJson(d.toJson());
    expect(c.projetId, 42);
    expect(c.lines.first.qteLivree, 6);
  });
}
