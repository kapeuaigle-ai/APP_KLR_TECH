import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

AppState _avecProformaValidee() {
  final s = AppState()..viderDonnees();
  s.saveOrUpdateProforma(DocumentItem(
    id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
    clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
    lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
  ));
  s.validateProforma(1);
  return s;
}

void main() {
  test('modifier la proforma ne touche NI la facture NI le BL, en mémoire', () {
    final s = _avecProformaValidee();
    s.documents['proforma']!.first.lines.first.qteLivree = 6;

    expect(s.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s.documents['bl']!.first.lines.first.qteLivree, 0);
  });

  test('le même comportement APRÈS un cycle de persistance', () {
    final s = _avecProformaValidee();
    final json = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

    final s2 = AppState()..loadFromJson(json);
    s2.documents['proforma']!.first.lines.first.qteLivree = 6;

    expect(s2.documents['facture']!.first.lines.first.qteLivree, 0);
    expect(s2.documents['bl']!.first.lines.first.qteLivree, 0);
    expect(s2.documents['proforma']!.first.lines.first.qteLivree, 6);
  });

  test('les trois documents partent bien des mêmes valeurs', () {
    final s = _avecProformaValidee();
    for (final type in ['proforma', 'facture', 'bl']) {
      final l = s.documents[type]!.first.lines.first;
      expect(l.ref, 'PC');
      expect(l.qte, 10);
      expect(l.pu, 300);
    }
  });
}
