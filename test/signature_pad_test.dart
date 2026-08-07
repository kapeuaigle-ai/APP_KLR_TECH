import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/widgets/signature_pad.dart';
import 'package:klr_tech_app/core/signature_image.dart';
import 'support/test_fonts.dart';

/// Pavé de signature au doigt.
///
/// Le fichier est scindé en deux volets délibérément :
///
/// - le **rendu PNG** se teste sans monter d'interface. Les opérations
///   `dart:ui` (`Picture.toImage`, `toByteData`) exigent `tester.runAsync`,
///   et envelopper un arbre de widgets dans `runAsync` réveille les futures
///   de google_fonts, qui lèvent après la fin du test (piège déjà rencontré
///   sur le rendu de signature dans le PDF) ;
/// - le **comportement de l'interface** se teste normalement, sans
///   `runAsync`, donc sans toucher aux images.
void main() {
  setUpAll(loadTestFonts);

  // ── Rendu PNG, sans interface ───────────────────────────
  group('rendu des traits en PNG', () {
    /// Un trait en zigzag, comme un vrai geste de signature.
    List<List<Offset>> zigzag() => [
      [
        for (var i = 0; i < 10; i++) Offset(20 + i * 12, 100 + (i.isEven ? -20 : 20)),
      ],
    ];

    testWidgets('produit un PNG non vide', (tester) async {
      final png = await tester.runAsync(
          () => renderStrokesToPng(zigzag(), const Size(400, 200)));

      expect(png, isNotNull);
      expect(png!.length, greaterThan(0));
      // Signature de fichier PNG.
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('traverse encodeSignaturePng puis decodeSignature',
        (tester) async {
      // La chaîne complète : pavé → base64 stocké dans AppSettings → octets
      // réaffichables. C'est ce qui garantit que le pavé se substitue à
      // l'import sans rien changer en aval (aperçu A4, PDF).
      final base64 = await tester.runAsync(() async {
        final png = await renderStrokesToPng(zigzag(), const Size(400, 200));
        return encodeSignaturePng(png!);
      });

      expect(base64, isNotNull);
      expect(base64!.isNotEmpty, isTrue);

      final decoded = decodeSignature(base64);
      expect(decoded, isNotNull);
      expect(decoded!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('un tracé large reste sous la limite de redimensionnement',
        (tester) async {
      // encodeSignaturePng borne la largeur à 800 px : un rendu 2x d'une zone
      // de 560 px fait 1120 px et doit donc être réduit.
      final base64 = await tester.runAsync(() async {
        final png = await renderStrokesToPng(zigzag(), const Size(560, 200));
        return encodeSignaturePng(png!);
      });

      expect(base64, isNotNull);
      expect(decodeSignature(base64!), isNotNull);
    });
  });

  // ── Comportement de l'interface ─────────────────────────
  group('interface du pavé', () {
    Future<Uint8List?> openPad(WidgetTester tester) async {
      Uint8List? result;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => ElevatedButton(
            onPressed: () async => result = await showSignaturePad(context),
            child: const Text('ouvrir'),
          )),
        ),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return result;
    }

    /// Trace un geste continu au centre de la zone de dessin.
    Future<void> drawStroke(WidgetTester tester) async {
      final zone = tester.getCenter(find.byKey(signatureCanvasKey));
      final gesture = await tester.startGesture(zone);
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(Offset(9, i.isEven ? -7 : 7));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('la zone vide affiche son repère', (tester) async {
      await openPad(tester);
      expect(find.text('Signe ici'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Effacer'), findsOneWidget);
    });

    testWidgets('dessiner fait disparaître le repère', (tester) async {
      await openPad(tester);
      await drawStroke(tester);
      expect(find.text('Signe ici'), findsNothing);
    });

    testWidgets('« Effacer » remet la zone à vide', (tester) async {
      await openPad(tester);
      await drawStroke(tester);
      expect(find.text('Signe ici'), findsNothing);

      await tester.tap(find.text('Effacer'));
      await tester.pumpAndSettle();
      expect(find.text('Signe ici'), findsOneWidget);
    });

    testWidgets('sans trait, « Valider » est inactif', (tester) async {
      await openPad(tester);

      // Le bouton existe mais n'a pas de rappel : appuyer ne ferme rien.
      final bouton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Valider'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(bouton.onPressed, isNull,
          reason: 'valider une zone vide enregistrerait une signature blanche');

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.text('Signe ici'), findsOneWidget, reason: 'la boîte reste ouverte');
    });

    // ── Défaut G3 (Lot G) ─────────────────────────────────
    // « Effacer » n'a rien à effacer tant qu'aucun trait n'existe : le
    // bouton doit être aussi inerte que « Valider » l'est déjà dans le même
    // état, pas seulement visuellement plus discret.
    testWidgets('sans trait, « Effacer » est inactif', (tester) async {
      await openPad(tester);

      final bouton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Effacer'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(bouton.onPressed, isNull,
          reason: 'rien à effacer sur une zone vide');

      await tester.tap(find.text('Effacer'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Signe ici'), findsOneWidget, reason: 'toujours vide, sans exception');
    });

    testWidgets('après un trait, « Effacer » est actif', (tester) async {
      await openPad(tester);
      await drawStroke(tester);

      final bouton = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Effacer'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(bouton.onPressed, isNotNull);
    });

    testWidgets('après un trait, « Valider » est actif', (tester) async {
      await openPad(tester);
      await drawStroke(tester);

      final bouton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Valider'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(bouton.onPressed, isNotNull);
    });

    testWidgets('la boîte ne se ferme pas sur un appui à côté', (tester) async {
      await openPad(tester);
      // barrierDismissible: false — un trait en cours ne doit pas se perdre.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Dessiner la signature'), findsOneWidget);
    });
  });
}
