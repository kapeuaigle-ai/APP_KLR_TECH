import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/pdf_generator.dart';
import 'package:klr_tech_app/core/signature_image.dart';
import 'support/test_fonts.dart';

/// Vérifie le chemin « avec signature » de bout en bout : une image passe par
/// l'optimisation `encodeSignaturePng`, puis se retrouve rendue dans la case
/// Signature d'un vrai PDF. C'est l'intégration qui compte : le PNG produit par
/// `dart:ui` doit être décodable par `pw.MemoryImage` du paquet pdf.
///
/// Les opérations d'image `dart:ui` n'aboutissent en test que dans la zone
/// asynchrone réelle : tout ce qui touche au moteur est donc dans `runAsync`.
/// Le chemin « sans signature » reste couvert par pdf_generator_test.

/// Fabrique un PNG opaque de w×h px, comme le ferait un fichier importé.
Future<Uint8List> _makePng(int w, int h) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = const Color(0xFF1A1D2E),
  );
  final img = await recorder.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<int> _pngWidth(Uint8List bytes) async {
  final frame = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
  final w = frame.image.width;
  frame.image.dispose();
  return w;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  AppSettings settings({String signature = '', String signatureLabel = ''}) =>
      AppSettings(
        company: 'KLR TECH SARL', address: 'Abidjan Riviera 2 Lot 128 ilot 307',
        bp: '28 BP 994 Abidjan 28', rccm: 'CI-ABJ-03-2021-B1308160', regime: 'TEE',
        tel: '0708714557', email: 'klr.tech8@gmail.com', prefix: 'KLR',
        startNum: '01', tva: 5,
        conditions: '100% à la livraison\nDisponibilité immédiate\nGarantie 1 an',
        signature: signature, signatureLabel: signatureLabel,
      );

  List<LineItem> lines(int n) => List.generate(n, (i) => LineItem(
      ref: (i + 1).toString().padLeft(2, '0'),
      designation: 'Article ${i + 1}', qte: 3, pu: 35000));

  Future<List<int>> buildPdf(AppSettings s, int n) {
    final l = lines(n);
    final ht = l.fold<double>(0, (a, x) => a + x.total);
    return PdfGenerator.generate(
      settings: s, type: 'facture', numero: 'KLR-04-200726', date: '20/07/2026',
      client: 'Global Tech', clientAddr: 'Lyon', objet: 'Matériels',
      lines: l, tva: true, ht: ht, tvaAmt: ht * 0.05, ttc: ht * 1.05,
      conditions: s.conditions,
    );
  }

  int pageCount(List<int> bytes) =>
      RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

  test('decodeSignature : vide ou corrompue → null, jamais d\'exception', () {
    expect(decodeSignature(''), isNull);
    expect(decodeSignature('ceci n\'est pas du base64 !!!'), isNull);
  });

  testWidgets('encodeSignaturePng : réduit à 800px max et n\'agrandit jamais', (tester) async {
    await tester.runAsync(() async {
      final large = await encodeSignaturePng(await _makePng(1600, 400));
      expect(await _pngWidth(decodeSignature(large)!), 800); // ramenée à 800 px

      final small = await encodeSignaturePng(await _makePng(300, 120));
      expect(await _pngWidth(decodeSignature(small)!), 300); // largeur inchangée
    });
  });

  testWidgets('le PNG optimisé se rend dans un PDF valide, sans page en plus', (tester) async {
    // L'encodage image passe par le moteur → zone asynchrone réelle. La
    // génération PDF, elle, reste hors runAsync (comme pdf_generator_test) pour
    // ne pas réveiller les futures de polices qui lèveraient après le test.
    final png = await tester.runAsync(() => _makePng(600, 200));
    final signature = await tester.runAsync(() => encodeSignaturePng(png!));

    final signe = await buildPdf(settings(signature: signature!, signatureLabel: 'La Direction'), 6);
    final nu = await buildPdf(settings(), 6);

    expect(String.fromCharCodes(signe.take(5)), '%PDF-');
    expect(signe.length, greaterThan(nu.length)); // l'image pèse des octets…
    expect(pageCount(signe), pageCount(nu));       // …mais la pagination ne bouge pas
  });
}
