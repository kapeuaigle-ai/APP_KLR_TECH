// Génère les assets du logo à partir du PDF fourni par le graphiste, rasterisé
// au préalable (voir README ci-dessous).
//
//   dart run tool/build_logo_assets.dart <logo_rasterise.png>
//
// Produit deux fichiers dans assets/logo/ :
//   • klr_logo.png — verrouillage complet (losanges + « KLR TECH »)
//   • klr_mark.png — losanges seuls, pour les petites tailles (sidebar, PDF)
//
// Le fond EXTÉRIEUR est rendu transparent par remplissage depuis les bords :
// les blancs ENFERMÉS (l'anneau blanc du losange, les contre-formes des lettres)
// sont conservés. C'est ce qui permet d'afficher le logo aussi bien sur le fond
// clair de la page de connexion que sur la sidebar sombre.
//
// Rasterisation du PDF sous Windows (API PDF intégrée, aucune installation) :
// voir tool/render_pdf.ps1.

import 'dart:io';
import 'package:image/image.dart' as img;

/// Un pixel est considéré comme fond s'il est quasi blanc et opaque.
bool _isBackground(img.Image im, int x, int y) {
  final p = im.getPixel(x, y);
  return p.r > 244 && p.g > 244 && p.b > 244;
}

/// Rend transparent tout le fond connecté aux bords (remplissage par diffusion).
/// Itératif (pile explicite) : une récursion déborderait sur une grande image.
void _clearOuterBackground(img.Image im) {
  final w = im.width, h = im.height;
  final seen = List<bool>.filled(w * h, false);
  final stack = <int>[];

  void push(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (seen[i]) return;
    seen[i] = true;
    if (_isBackground(im, x, y)) stack.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }

  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w, y = i ~/ w;
    im.setPixelRgba(x, y, 0, 0, 0, 0); // transparent
    push(x - 1, y);
    push(x + 1, y);
    push(x, y - 1);
    push(x, y + 1);
  }
}

/// Rectangle englobant des pixels non transparents, dans la bande [top, bottom[.
img.Image _cropToContent(img.Image im, {int? top, int? bottom}) {
  final y0 = top ?? 0, y1 = bottom ?? im.height;
  int minX = im.width, minY = im.height, maxX = -1, maxY = -1;
  for (var y = y0; y < y1; y++) {
    for (var x = 0; x < im.width; x++) {
      if (im.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  if (maxX < 0) throw StateError('Aucun contenu trouvé dans la bande $y0..$y1');
  return img.copyCrop(im, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

/// Lignes entièrement transparentes, pour repérer la coupure losange / texte.
List<bool> _blankRows(img.Image im) => List.generate(im.height, (y) {
      for (var x = 0; x < im.width; x++) {
        if (im.getPixel(x, y).a > 8) return false;
      }
      return true;
    });

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage : dart run tool/build_logo_assets.dart <logo.png>');
    exit(64);
  }
  final src = img.decodePng(File(args.first).readAsBytesSync());
  if (src == null) {
    stderr.writeln('PNG illisible : ${args.first}');
    exit(65);
  }
  final im = src.convert(numChannels: 4);
  _clearOuterBackground(im);

  // Le logo est composé de deux blocs séparés par une bande vide : les losanges
  // en haut, le mot « KLR TECH » en bas. On coupe au milieu de cette bande.
  final blank = _blankRows(im);
  final first = blank.indexOf(false);
  var gapStart = -1, gapEnd = -1;
  for (var y = first; y < im.height; y++) {
    if (blank[y] && gapStart < 0) gapStart = y;
    if (!blank[y] && gapStart >= 0) {
      // Bande vide significative (> 1 % de la hauteur) = séparation cherchée.
      if (y - gapStart > im.height * 0.01) { gapEnd = y; break; }
      gapStart = -1;
    }
  }

  final dir = Directory('assets/logo')..createSync(recursive: true);
  final full = _cropToContent(im);
  File('${dir.path}/klr_logo.png').writeAsBytesSync(img.encodePng(full));
  stdout.writeln('klr_logo.png : ${full.width}x${full.height}');

  if (gapEnd > 0) {
    final mark = _cropToContent(im, top: 0, bottom: gapStart);
    File('${dir.path}/klr_mark.png').writeAsBytesSync(img.encodePng(mark));
    stdout.writeln('klr_mark.png : ${mark.width}x${mark.height}');
  } else {
    stderr.writeln('Séparation losange/texte introuvable : klr_mark.png non généré');
  }
}
