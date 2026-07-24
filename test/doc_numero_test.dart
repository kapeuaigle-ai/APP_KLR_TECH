import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';

DocumentItem proforma(String date) => DocumentItem(
    id: date.hashCode + date.length, numero: 'x', date: date, clientId: 0,
    client: 'C', objet: 'O', montant: 0, statut: 'cours');

void main() {
  test('première proforma d\'un jour = 01', () {
    final n = DocNumero.next('KLR', [], DateTime(2026, 4, 25));
    expect(n, 'KLR-01-250426');
  });

  test('compteur incrémente dans la même journée', () {
    final existants = [proforma('24/04/2026'), proforma('24/04/2026'), proforma('24/04/2026')];
    // 3 proformas déjà le 24/04 -> la suivante ce jour = 04
    expect(DocNumero.next('KLR', existants, DateTime(2026, 4, 24)), 'KLR-04-240426');
  });

  test('changement de jour -> le compteur repart à 01', () {
    final existants = [proforma('24/04/2026'), proforma('24/04/2026'), proforma('24/04/2026'), proforma('24/04/2026')];
    // 4 proformas le 24/04 ; le 25/04 la première = 01
    expect(DocNumero.next('KLR', existants, DateTime(2026, 4, 25)), 'KLR-01-250426');
    // seconde du 25/04
    final plus1 = [...existants, proforma('25/04/2026')];
    expect(DocNumero.next('KLR', plus1, DateTime(2026, 4, 25)), 'KLR-02-250426');
  });
}
