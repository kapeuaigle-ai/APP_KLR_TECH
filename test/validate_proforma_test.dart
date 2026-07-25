import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

/// Validation d'une proforma : la facture et le BL générés sont appariés
/// (même compteur/date, lettre P→F/B), et re-valider ne duplique jamais —
/// y compris pour les proformas validées avant la refonte de la numérotation,
/// dont la facture porte un numéro identique à l'ancien format.
///
/// Ids en 900+ et numéros hors des données d'exemple : AppState sème toujours
/// le seed de démo, il ne faut collisionner ni ses ids ni ses numéros.
void main() {
  DocumentItem proforma(int id, String numero, {String statut = 'cours'}) =>
      DocumentItem(id: id, numero: numero, date: '25/07/2026', clientId: 0,
          client: 'C', objet: 'O', montant: 1000, statut: statut);

  test('validation : facture et BL créés avec le numéro décliné P→F/B', () {
    final s = AppState();
    s.addDocument('proforma', proforma(900, 'KLR-P07-25072026'));
    final created = s.validateProforma(900);

    expect(created, isTrue);
    expect(s.documents['facture']!.any((d) => d.numero == 'KLR-F07-25072026'), isTrue);
    expect(s.documents['bl']!.any((d) => d.numero == 'KLR-B07-25072026'), isTrue);
  });

  test('re-valider la même proforma ne duplique ni facture ni BL', () {
    final s = AppState();
    s.addDocument('proforma', proforma(900, 'KLR-P07-25072026'));
    expect(s.validateProforma(900), isTrue);
    final nbFactures = s.documents['facture']!.length;
    final nbBl = s.documents['bl']!.length;

    expect(s.validateProforma(900), isFalse); // déjà générés
    expect(s.documents['facture']!.length, nbFactures);
    expect(s.documents['bl']!.length, nbBl);
  });

  test('héritage : proforma validée avant la refonte (facture au même numéro) '
      'ne génère pas de doublon', () {
    final s = AppState();
    // État d'une sauvegarde antérieure : ancien format, facture au numéro
    // IDENTIQUE à la proforma (l'appariement d'alors). Numéro choisi pour ne
    // correspondre à aucun numéro décliné présent dans le seed.
    s.addDocument('proforma', proforma(900, 'KLR-05-180326', statut: 'validee'));
    s.addDocument('facture', DocumentItem(id: 901, numero: 'KLR-05-180326',
        date: '18/03/2026', clientId: 0, client: 'C', objet: 'O',
        montant: 1000, statut: 'validee'));
    final nbFactures = s.documents['facture']!.length;
    final nbBl = s.documents['bl']!.length;

    // L'utilisateur re-sélectionne « validee » dans la liste.
    expect(s.validateProforma(900), isFalse);
    expect(s.documents['facture']!.length, nbFactures); // pas de doublon
    expect(s.documents['bl']!.length, nbBl);
  });
}
