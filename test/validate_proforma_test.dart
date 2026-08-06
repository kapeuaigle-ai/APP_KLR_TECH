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

  test('valider une proforma crée l\'engagement entrant de sa facture', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      projetId: 42,
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);

    expect(s.engagements.length, 1);
    final e = s.engagements.first;
    expect(e.sens, 'entrant');
    expect(e.documentNumero, 'KLR-F01-10012026');
    expect(e.clientId, 5);
    expect(e.tiers, 'ACME');
    expect(e.montant, 3000, reason: 'la somme des lignes, comme montantFacture');
    expect(e.projetId, 42);
    expect(e.reglements, isEmpty, reason: 'rien n\'est encore encaissé');
  });

  test('valider deux fois ne crée pas deux engagements', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);
    s.validateProforma(1);
    expect(s.engagements.length, 1);
  });

  test('l\'échéance de l\'engagement est la date de la proforma', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC', montant: 3000, statut: 'cours',
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);
    expect(s.engagements.first.echeance, DateTime(2026, 1, 10));
  });

  // Le bug d'origine (audit § « money bug ») : la facture et l'engagement de
  // créance étaient calculés avec deux expressions différentes — la facture
  // recopiait `p.montant` (potentiellement TTC ou périmé), l'engagement
  // resommait les lignes (HT). L'écart entre les deux disparaissait sans
  // trace au premier règlement complet, `ajouterReglement` écrêtant le
  // paiement au `reste` de l'engagement. Les deux DOIVENT désormais provenir
  // de la même expression, même quand `p.montant` ment.
  test('facture et engagement portent le même montant, la somme des lignes, '
      'même si le montant stocké de la proforma est faux', () {
    final s = AppState()..viderDonnees();
    s.saveOrUpdateProforma(DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026',
      clientId: 5, client: 'ACME', objet: 'PC',
      montant: 999999, // délibérément faux : ne doit influencer ni l'un ni l'autre
      statut: 'cours',
      lines: [LineItem(ref: 'PC', designation: 'Ordinateur', qte: 10, pu: 300)],
    ));
    s.validateProforma(1);

    final facture = s.documents['facture']!.first;
    final engagement = s.engagements.first;
    expect(facture.montant, 3000, reason: 'la somme des lignes, pas p.montant');
    expect(engagement.montant, 3000);
    expect(facture.montant, engagement.montant,
        reason: 'les deux doivent toujours coïncider — c\'est l\'écart entre '
            'eux qui a fait disparaître de l\'argent réellement encaissé');
  });
}
