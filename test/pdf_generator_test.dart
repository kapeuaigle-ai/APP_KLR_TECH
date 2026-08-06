import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/document_pagination.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/pdf_generator.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'support/test_fonts.dart';

/// Le PDF doit contenir exactement les pages calculées par DocumentPagination :
/// c'est ce qui garantit que le fichier produit correspond à l'aperçu affiché,
/// et qu'aucune ligne n'est silencieusement tronquée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  AppSettings settings() => AppSettings(
        company: 'KLR TECH SARL',
        address: 'Abidjan Riviera 2 Lot 128 ilot 307',
        bp: '28 BP 994 Abidjan 28',
        rccm: 'CI-ABJ-03-2021-B1308160',
        regime: 'TEE',
        tel: '0708714557',
        email: 'klr.tech8@gmail.com',
        prefix: 'KLR',
        startNum: '01',
        conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
      );

  List<LineItem> lines(int n, String kind) => List.generate(n, (i) {
        final d = kind == 'courte'
            ? 'Article ${i + 1}'
            : 'Désignation particulièrement détaillée du produit ou service fourni n°${i + 1}';
        return LineItem(ref: (i + 1).toString().padLeft(2, '0'), designation: d, qte: 3, pu: 35000);
      });

  Future<List<int>> build(int n, String type, String kind) {
    final l = lines(n, kind);
    final montant = l.fold<double>(0, (s, x) => s + x.total);
    return PdfGenerator.generate(
      settings: settings(),
      type: type,
      numero: 'KLR-04-200726',
      date: '20/07/2026',
      client: 'Global Tech',
      clientAddr: '45 Avenue des Champs, Lyon, France',
      objet: 'Matériels informatiques',
      lines: l,
      montant: montant,
      conditions: settings().conditions,
    );
  }

  // Contexte identique à celui que construit PdfGenerator.generate, pour
  // recalculer la pagination attendue.
  DocumentContext ctx(int n, String type, String kind) {
    final l = lines(n, kind);
    final montant = l.fold<double>(0, (s, x) => s + x.total);
    return DocumentContext(
      typeLabel: type == 'facture' ? 'FACTURE' : type == 'bl' ? 'BON DE LIVRAISON' : 'FACTURE PROFORMA',
      numero: 'KLR-04-200726',
      date: '20/07/2026',
      deLines: [settings().company, settings().address, settings().bp],
      attentionLines: ['Global Tech', '45 Avenue des Champs, Lyon, France'],
      objet: 'Matériels informatiques',
      montantWords: 'Arrêté la présente facture à la somme de : ${NumberToWords.convert(montant)} FRANCS CFA.',
      conditions: settings().conditions,
      warranty: DocumentPagination.warrantyClause,
      footerLine: settings().footerLine,
      showMontant: montant > 0 && type != 'bl',
    );
  }

  // Un objet page par feuille dans le fichier PDF.
  int pageCount(List<int> bytes) =>
      RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

  for (final type in ['facture', 'bl']) {
    for (final kind in ['courte', 'longue']) {
      for (final n in [1, 8, 9, 19, 20, 35, 60]) {
        testWidgets('$type · $kind · $n lignes : pagination conforme à l\'aperçu', (tester) async {
          final bytes = await build(n, type, kind);
          expect(bytes, isNotEmpty);
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

          final attendu = DocumentPagination
              .paginate(lines(n, kind), isBl: type == 'bl', context: ctx(n, type, kind))
              .length;
          expect(pageCount(bytes), attendu,
              reason: 'le PDF doit avoir le même nombre de pages que l\'aperçu');
        });
      }
    }
  }

  testWidgets('un document sans ligne produit tout de même une page', (tester) async {
    final bytes = await build(0, 'facture', 'courte');
    expect(pageCount(bytes), 1);
  });

  // Garde-fou : si le comptage de pages renvoyait toujours la même valeur, les
  // tests de conformité ci-dessus passeraient sans rien vérifier. Le nombre de
  // pages doit croître avec le nombre de lignes.
  testWidgets('le comptage de pages croît avec le nombre de lignes', (tester) async {
    final p1 = pageCount(await build(1, 'facture', 'courte'));
    final p20 = pageCount(await build(20, 'facture', 'courte'));
    final p60 = pageCount(await build(60, 'facture', 'courte'));
    expect(p1, 1);
    expect(p20, greaterThan(p1));
    expect(p60, greaterThan(p20));
  });
}
