import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/document_pagination.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/widgets/document_preview.dart';
import 'support/test_fonts.dart';

/// L'aperçu A4 est composé à taille fixe puis mis à l'échelle : il ne doit
/// jamais déborder, quels que soient la largeur du volet, le nombre de lignes
/// et la longueur des désignations.
void main() {
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

  DocumentContext ctx() => DocumentContext(
        typeLabel: 'FACTURE PROFORMA',
        numero: 'KLR-04-220726',
        date: '22 Juillet 2026',
        deLines: [settings().company, settings().address, settings().bp],
        attentionLines: ['Global Tech', '45 Avenue des Champs, Lyon, France'],
        objet: 'Matériels informatiques',
        montantWords: 'Arrêté la présente facture à la somme de : DEUX MILLIONS FRANCS CFA.',
        conditions: settings().conditions,
        warranty: 'Tout produit, sauf mention contraire, bénéficie d\'une période de garantie contre tout '
            'vice de fabrication soumise à l\'expertise constructeur, à compter de la date de facturation.',
        footerLine: settings().footerLine,
        showMontant: true,
      );

  // 'courte'  : tient sur une rangée
  // 'longue'  : renvoyée à la ligne, occupe deux rangées
  List<LineItem> lines(int n, String kind) => List.generate(n, (i) {
        final d = switch (kind) {
          'courte' => 'Article ${i + 1}',
          'longue' => 'Désignation particulièrement détaillée du produit ou service fourni n°${i + 1}',
          _ => 'Désignation du produit ou service n°${i + 1}',
        };
        return LineItem(ref: (i + 1).toString().padLeft(2, '0'), designation: d, qte: 3, pu: 35000);
      });

  Widget host({required double width, required String type, required int n, required String kind}) {
    final l = lines(n, kind);
    final montant = l.fold<double>(0, (s, x) => s + x.total);
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: DocumentPreview(
              type: type,
              numero: 'KLR-04-200726',
              settings: settings(),
              client: 'Global Tech',
              clientAddr: '45 Avenue des Champs, Lyon, France',
              objet: 'Matériels informatiques',
              lines: l,
              montant: montant,
              conditions: settings().conditions,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> expectNoOverflow(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1600, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    expect(tester.takeException(), isNull);
  }

  // Le bug d'origine : le volet étroit réduisait la hauteur alors que les
  // polices restaient en pixels fixes.
  group('largeur du volet', () {
    for (final width in [280.0, 340.0, 420.0, 530.0, 680.0]) {
      testWidgets('${width.toInt()}px', (tester) async {
        await expectNoOverflow(tester, host(width: width, type: 'facture', n: 6, kind: 'courte'));
      });
    }
  });

  // Balayage exhaustif : couvre page unique, bascule multi-pages, pages
  // intermédiaires et dernière page — c'est aux frontières que la pagination
  // se trompait (une page intermédiaire devenant la dernière).
  group('nombre de lignes', () {
    for (final kind in ['courte', 'moyenne', 'longue']) {
      for (var n = 1; n <= 70; n++) {
        testWidgets('facture · $kind · $n lignes', (tester) async {
          await expectNoOverflow(tester, host(width: 340, type: 'facture', n: n, kind: kind));
        });
      }
    }
  });

  group('bon de livraison', () {
    for (final n in [1, 8, 13, 24, 40]) {
      testWidgets('$n lignes', (tester) async {
        await expectNoOverflow(tester, host(width: 340, type: 'bl', n: n, kind: 'longue'));
      });
    }
  });

  // Défaut F4 (Lot F) : `DocumentPagination.rowsFor` budgète au plus 6 lignes
  // par rangée (clamp), mais le `Text` rendu n'avait pas de `maxLines` — une
  // désignation démesurément longue déborde alors le cadre mesuré sur ce
  // même budget. Le texte rendu doit désormais respecter le même plafond.
  group('désignation démesurée', () {
    testWidgets('une désignation de 2900 caractères ne fait pas déborder la page', (tester) async {
      final ligne = LineItem(
        ref: '01',
        designation: List.generate(2900, (i) => 'x').join(),
        qte: 1, pu: 35000,
      );
      await expectNoOverflow(tester, MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 530,
              child: DocumentPreview(
                type: 'facture',
                numero: 'KLR-04-200726',
                settings: settings(),
                client: 'Global Tech',
                clientAddr: '45 Avenue des Champs, Lyon, France',
                objet: 'Matériels informatiques',
                lines: [ligne],
                montant: ligne.total,
                conditions: settings().conditions,
              ),
            ),
          ),
        ),
      ));
    });
  });

  // Une rangée laissée vide dans le formulaire ne fait pas partie du document :
  // elle ne doit ni s'afficher ni compter dans la pagination, sinon « Ajouter
  // une ligne » provoquerait un saut de page prématuré.
  group('lignes vides ignorées', () {
    LineItem filled(int i) => LineItem(
        ref: i.toString().padLeft(2, '0'), designation: 'Article $i', qte: 3, pu: 35000);
    LineItem empty(int i) => LineItem(
        ref: i.toString().padLeft(2, '0'), designation: '   ', qte: 1, pu: 0);

    test('visible() retire les rangées sans désignation', () {
      final lines = [filled(1), filled(2), empty(3), empty(4)];
      expect(DocumentPagination.visible(lines).length, 2);
    });

    testWidgets('les rangées vides ne sont pas dessinées', (tester) async {
      tester.view.physicalSize = const Size(1100, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lines = [for (var i = 1; i <= 6; i++) filled(i), empty(7), empty(8)];
      final montant = lines.fold<double>(0, (s, x) => s + x.total);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: SizedBox(width: 530, child: DocumentPreview(
          type: 'facture', numero: 'KLR-04-220726', settings: settings(),
          client: 'Global Tech', clientAddr: 'Lyon', objet: 'Objet',
          lines: lines, montant: montant,
          conditions: settings().conditions, showToolbar: false,
        )),
      ))));

      expect(tester.takeException(), isNull);
      expect(find.text('06'), findsOneWidget); // dernière ligne remplie
      expect(find.text('07'), findsNothing);   // rangée vide non dessinée
      expect(find.text('08'), findsNothing);
    });

    testWidgets('ajouter une ligne vide ne crée pas de page', (tester) async {
      tester.view.physicalSize = const Size(1100, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Ajouter une rangée VIDE à un lot de lignes remplies ne doit jamais
      // changer le nombre de pages (elle est filtrée avant pagination).
      final huit = [for (var i = 1; i <= 8; i++) filled(i)];
      final neuf = [...huit, empty(9)];
      expect(
        DocumentPagination.paginate(DocumentPagination.visible(huit), isBl: false, context: ctx()).length,
        DocumentPagination.paginate(DocumentPagination.visible(neuf), isBl: false, context: ctx()).length,
      );
    });
  });
}
