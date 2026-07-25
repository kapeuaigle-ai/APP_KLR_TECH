import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';

DocumentItem doc(String date) => DocumentItem(
    id: date.hashCode + date.length, numero: 'x', date: date, clientId: 0,
    client: 'C', objet: 'O', montant: 0, statut: 'cours');

void main() {
  // ── Génération : PREFIX-{L}{NN}-JJMMAAAA ─────────────────
  group('DocNumero.next', () {
    test('premier document du jour = 01, lettre selon le type', () {
      final j = DateTime(2026, 4, 25);
      expect(DocNumero.next('KLR', 'proforma', [], j), 'KLR-P01-25042026');
      expect(DocNumero.next('KLR', 'facture', [], j), 'KLR-F01-25042026');
      expect(DocNumero.next('KLR', 'bl', [], j), 'KLR-B01-25042026');
    });

    test('compteur incrémente dans la même journée', () {
      final trois = [doc('24/04/2026'), doc('24/04/2026'), doc('24/04/2026')];
      // 3 documents du type déjà le 24/04 -> le suivant ce jour = 04
      expect(DocNumero.next('KLR', 'proforma', trois, DateTime(2026, 4, 24)), 'KLR-P04-24042026');
    });

    test('changement de jour -> le compteur repart à 01', () {
      final quatre = List.generate(4, (_) => doc('24/04/2026'));
      expect(DocNumero.next('KLR', 'facture', quatre, DateTime(2026, 4, 25)), 'KLR-F01-25042026');
      // seconde du 25/04
      final plus1 = [...quatre, doc('25/04/2026')];
      expect(DocNumero.next('KLR', 'facture', plus1, DateTime(2026, 4, 25)), 'KLR-F02-25042026');
    });

    test('ne compte que la liste fournie (le type est filtré par l\'appelant)', () {
      final deux = [doc('25/04/2026'), doc('25/04/2026')];
      expect(DocNumero.next('KLR', 'bl', deux, DateTime(2026, 4, 25)), 'KLR-B03-25042026');
    });
  });

  // ── Appariement proforma → facture / BL ──────────────────
  group('DocNumero.retype', () {
    test('même compteur et même date, seule la lettre change', () {
      expect(DocNumero.retype('KLR-P02-25072026', 'facture'), 'KLR-F02-25072026');
      expect(DocNumero.retype('KLR-P02-25072026', 'bl'), 'KLR-B02-25072026');
    });

    test('préfixe contenant un tiret', () {
      expect(DocNumero.retype('KLR-TECH-P05-25072026', 'facture'), 'KLR-TECH-F05-25072026');
    });

    test('ancien numéro (sans lettre, année sur 2 chiffres) est normalisé', () {
      expect(DocNumero.retype('KLR-03-160226', 'facture'), 'KLR-F03-16022026');
    });

    test('format inattendu : renvoyé inchangé', () {
      expect(DocNumero.retype('brouillon', 'facture'), 'brouillon');
    });
  });

  // ── Nom du fichier PDF téléchargé = le numéro exact ──────
  group('DocNumero.fileName', () {
    final jour = DateTime(2026, 7, 24);

    test('nom = le numéro exact du document (lettre conservée)', () {
      expect(DocNumero.fileName('proforma', 'KLR-P01-25072026', jour),
          'KLR-P01-25072026.pdf');
      expect(DocNumero.fileName('facture', 'KLR-F02-25072026', jour),
          'KLR-F02-25072026.pdf');
      expect(DocNumero.fileName('bl', 'KLR-B03-25072026', jour),
          'KLR-B03-25072026.pdf');
    });

    test('ancien numéro : repris tel quel', () {
      expect(DocNumero.fileName('facture', 'KLR-03-240726', jour),
          'KLR-03-240726.pdf');
    });

    test('préfixe personnalisé contenant un tiret', () {
      expect(DocNumero.fileName('facture', 'KLR-TECH-F04-24072026', jour),
          'KLR-TECH-F04-24072026.pdf');
    });

    test('numéro absent ou inattendu -> nom daté du jour, avec libellé', () {
      expect(DocNumero.fileName('proforma', '', jour),
          'KLR-Proforma-24072026.pdf');
      expect(DocNumero.fileName('proforma', 'brouillon', jour),
          'KLR-Proforma-24072026.pdf');
    });
  });
}
