import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/pdf_generator.dart';
import 'support/test_fonts.dart';

/// Date imprimée sur le document (saisie libre, masquée si vide) et
/// modification d'une proforma existante.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  AppSettings settings() => AppSettings(
        company: 'KLR TECH SARL', address: 'Abidjan', bp: 'BP 1', rccm: 'R',
        regime: 'TEE', tel: '07', email: 'a@b.ci', prefix: 'KLR',
        startNum: '01', conditions: 'x',
      );

  DocumentItem proforma({String dateAffichee = ''}) => DocumentItem(
      id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026',
      dateAffichee: dateAffichee, clientId: 0, client: 'C', objet: 'O',
      montant: 1000, statut: 'cours',
      lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 1000)]);

  group('dateAffichee', () {
    test('vide par défaut, distincte de la date de création', () {
      final d = proforma();
      expect(d.dateAffichee, '');
      expect(d.date, '25/07/2026'); // date interne, sert au compteur du jour
    });

    test('round-trip JSON, et rétro-compatibilité', () {
      final d = proforma(dateAffichee: '25 Juillet 2026');
      expect(DocumentItem.fromJson(d.toJson()).dateAffichee, '25 Juillet 2026');

      final vieux = d.toJson()..remove('dateAffichee');
      expect(DocumentItem.fromJson(vieux).dateAffichee, '');
    });

    test('la facture et le BL héritent de la date saisie', () {
      final s = AppState();
      s.addDocument('proforma', proforma(dateAffichee: '25 Juillet 2026'));
      s.validateProforma(900);

      expect(s.documents['facture']!.last.dateAffichee, '25 Juillet 2026');
      expect(s.documents['bl']!.last.dateAffichee, '25 Juillet 2026');
    });
  });

  group('PDF', () {
    Future<String> pdfText({String? date}) async {
      final bytes = await PdfGenerator.generate(
        settings: settings(), type: 'facture', numero: 'KLR-F01-25072026',
        date: date, client: 'C', clientAddr: '', objet: 'O',
        lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 1000)],
        montant: 1000, conditions: 'x',
      );
      return String.fromCharCodes(bytes);
    }

    testWidgets('date saisie : le PDF reste valide', (tester) async {
      final pdf = await pdfText(date: '25 Juillet 2026');
      expect(pdf.startsWith('%PDF-'), isTrue);
    });

    testWidgets('date absente ou vide : PDF valide, plus court', (tester) async {
      final avec = await pdfText(date: '25 Juillet 2026');
      final sans = await pdfText(date: '');
      final nulle = await pdfText();

      expect(sans.startsWith('%PDF-'), isTrue);
      expect(nulle.startsWith('%PDF-'), isTrue);
      // La ligne de date n'étant plus dessinée, le flux de contenu est plus léger.
      expect(sans.length, lessThan(avec.length));
    });
  });

  group('modification', () {
    test('réenregistrer la proforma modifiée ne crée pas de doublon', () {
      final s = AppState();
      s.addDocument('proforma', proforma());
      final avant = s.documents['proforma']!.length;

      // L'écran d'édition renvoie le même id, avec un contenu à jour.
      s.saveOrUpdateProforma(DocumentItem(
        id: 900, numero: 'KLR-P01-25072026', date: '25/07/2026',
        dateAffichee: '26 Juillet 2026', clientId: 0, client: 'Client corrigé',
        objet: 'Objet corrigé', montant: 2000, statut: 'cours',
        lines: [LineItem(ref: '01', designation: 'Article', qte: 2, pu: 1000)]));

      expect(s.documents['proforma']!.length, avant); // pas de second document
      final d = s.documents['proforma']!.firstWhere((x) => x.id == 900);
      expect(d.client, 'Client corrigé');
      expect(d.objet, 'Objet corrigé');
      expect(d.dateAffichee, '26 Juillet 2026');
      expect(d.numero, 'KLR-P01-25072026'); // numéro conservé
    });

    test('startEditProforma ouvre l\'écran sur le document visé', () {
      final s = AppState();
      final d = proforma();
      s.addDocument('proforma', d);

      s.startEditProforma(d);
      expect(s.creating, isTrue);
      expect(s.editingProforma?.id, 900);

      s.setCreating(false); // sortie de l'écran
      expect(s.editingProforma, isNull);
    });
  });
}
