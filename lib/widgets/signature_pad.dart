import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import 'common.dart';
import 'responsive.dart';

// ─────────────────────────────────────────────────────────
//  Pavé de signature au doigt
//
//  Complète l'import de fichier, qui reste le geste naturel à la souris.
//  La sortie est identique dans les deux cas : des octets PNG confiés à
//  `encodeSignaturePng`. Stockage (AppSettings.signature en base64), aperçu
//  A4 et générateur PDF sont donc inchangés — c'était le point d'extension
//  prévu de longue date.
// ─────────────────────────────────────────────────────────

/// Identifie la zone de dessin, pour que les tests puissent y tracer un geste.
const signatureCanvasKey = Key('signature-canvas');

/// Ouvre le pavé de signature et retourne les octets PNG tracés, ou `null`
/// si l'utilisateur annule ou n'a rien dessiné.
Future<Uint8List?> showSignaturePad(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    // Un trait commencé ne doit pas se perdre sur un appui à côté.
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: const _SignaturePadDialog(),
      ),
    ),
  );
}

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog();

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  /// Un trait par geste. Les garder séparés évite de relier d'une ligne
  /// droite la fin d'un geste au début du suivant.
  final List<List<Offset>> _strokes = [];

  /// Taille réelle de la zone de dessin, mesurée au premier rendu. Sert à
  /// rendre le PNG aux mêmes proportions que ce qui a été tracé.
  Size? _canvasSize;

  /// Vrai dès qu'un trait réel existe : un simple appui sans mouvement ne
  /// constitue pas une signature.
  bool get _hasDrawing => _strokes.any((s) => s.length > 1);

  void _start(Offset p) => setState(() => _strokes.add([p]));

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(p));
  }

  void _clear() => setState(_strokes.clear);

  Future<Uint8List?> _toPng() {
    final size = _canvasSize;
    if (size == null || !_hasDrawing) return Future.value();
    return renderStrokesToPng(_strokes, size);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dessiner la signature', style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const SizedBox(height: 2),
            Text('Signe avec le doigt ou la souris.', style: GoogleFonts.dmSans(
                fontSize: 12.5, color: AppColors.text3)),
          ])),
          IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close, size: 18, color: AppColors.text2),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ]),
      ),

      // ── Zone de dessin ──────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, 200);
          // Mémorisée pour le rendu PNG, hors phase de build.
          _canvasSize = size;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: GestureDetector(
                // Clé de test : la zone de dessin doit pouvoir être visée sans
                // ambiguïté (la boîte contient plusieurs CustomPaint).
                key: signatureCanvasKey,
                // onPan* couvre le doigt comme la souris.
                onPanStart: (d) => _start(d.localPosition),
                onPanUpdate: (d) => _extend(d.localPosition),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes),
                  child: _hasDrawing
                      ? null
                      : Center(child: Text('Signe ici', style: GoogleFonts.dmSans(
                          fontSize: 13, color: AppColors.text3))),
                ),
              ),
            ),
          );
        }),
      ),

      // ── Actions ─────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: isPhone(context)
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: double.infinity, child: PrimaryBtn(
                  label: 'Valider',
                  icon: Icons.check,
                  onTap: _hasDrawing ? _valider : null,
                )),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: SecondaryBtn(
                  label: 'Effacer', icon: Icons.refresh, onTap: _clear,
                )),
              ])
            : Row(children: [
                SecondaryBtn(label: 'Effacer', icon: Icons.refresh, onTap: _clear),
                const Spacer(),
                PrimaryBtn(
                  label: 'Valider',
                  icon: Icons.check,
                  onTap: _hasDrawing ? _valider : null,
                ),
              ]),
      ),
    ]);
  }

  Future<void> _valider() async {
    final png = await _toPng();
    if (!mounted) return;
    Navigator.of(context).pop(png);
  }
}

/// Rejoue les traits sur un `PictureRecorder` et encode le résultat en PNG.
///
/// Le fond reste transparent : c'est ce qui donne le meilleur rendu dans la
/// case « Signature » du document, exactement comme un PNG importé.
///
/// Séparée du widget pour être testable sans monter d'interface. En test, les
/// opérations `dart:ui` ci-dessous exigent `tester.runAsync` ; les envelopper
/// avec un arbre de widgets réveillerait les futures de google_fonts, qui
/// lèvent alors après la fin du test.
Future<Uint8List?> renderStrokesToPng(
  List<List<Offset>> strokes,
  Size size, {
  /// Rendu à 2x pour que le trait reste net après mise à l'échelle dans le
  /// document. `encodeSignaturePng` ramènera la largeur à 800 px au plus.
  double scale = 2.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);
  _paintStrokes(canvas, strokes);
  final picture = recorder.endRecording();

  final image = await picture.toImage(
    (size.width * scale).round(),
    (size.height * scale).round(),
  );
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

/// Dessine les traits accumulés. Extrait pour être partagé entre l'affichage
/// à l'écran et le rendu PNG — un seul code de tracé, donc aucun écart
/// possible entre ce qu'on voit et ce qu'on enregistre.
void _paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final brush = Paint()
    ..color = const Color(0xFF111827) // encre sombre, lisible sur fond blanc
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.length < 2) {
      // Point isolé : un simple appui doit laisser une marque.
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.3, brush..style = PaintingStyle.fill);
        brush.style = PaintingStyle.stroke;
      }
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, brush);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) => _paintStrokes(canvas, strokes);

  // Les traits sont mutés en place puis `setState` est appelé : on redessine
  // systématiquement plutôt que de comparer les listes.
  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
