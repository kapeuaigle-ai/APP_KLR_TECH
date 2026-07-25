// Génère les icônes d'application (Windows + Web) à partir du logo officiel,
// en remplacement des icônes Flutter par défaut.
//
//   dart run tool/build_app_icons.dart
//
// Produit :
//   windows/runner/resources/app_icon.ico  — multi-résolutions 16 → 256
//   web/favicon.png                        — 32
//   web/icons/Icon-{192,512}.png           — icônes PWA classiques
//   web/icons/Icon-maskable-{192,512}.png  — icônes PWA « maskable »
//
// Les icônes classiques gardent le fond transparent (le losange se pose alors
// correctement sur une barre des tâches claire comme sombre). Les « maskable »
// sont rognées par le système en cercle ou en carré arrondi : elles reçoivent
// donc un fond blanc plein et une marge de sécurité plus large.

import 'dart:io';
import 'package:image/image.dart' as img;

/// Place [logo] au centre d'un carré de [size] px, en occupant [ratio] de la
/// largeur. [background] null = fond transparent.
img.Image _square(img.Image logo, int size, double ratio, {img.Color? background}) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  if (background != null) {
    img.fill(canvas, color: background);
  } else {
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  }

  final target = (size * ratio).round();
  // Le losange est plus large que haut d'un poil : on borne la plus grande
  // dimension pour que rien ne soit rogné.
  final scale = target / (logo.width > logo.height ? logo.width : logo.height);
  final resized = img.copyResize(
    logo,
    width: (logo.width * scale).round(),
    height: (logo.height * scale).round(),
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(canvas, resized,
      dstX: (size - resized.width) ~/ 2, dstY: (size - resized.height) ~/ 2);
  return canvas;
}

void main() {
  final markFile = File('assets/logo/klr_mark.png');
  if (!markFile.existsSync()) {
    stderr.writeln('assets/logo/klr_mark.png introuvable — lance d\'abord '
        'tool/build_logo_assets.dart');
    exit(66);
  }
  final mark = img.decodePng(markFile.readAsBytesSync())!.convert(numChannels: 4);

  // ── Windows : .ico multi-résolutions ────────────────────
  // Windows pioche la taille adaptée au contexte (16 px dans la barre de
  // titre, 256 px dans l'explorateur en grandes icônes).
  const icoSizes = [16, 24, 32, 48, 64, 128, 256];
  final icoImages = [for (final s in icoSizes) _square(mark, s, 0.92)];
  File('windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(img.IcoEncoder().encodeImages(icoImages));
  stdout.writeln('app_icon.ico : ${icoSizes.join(", ")} px');

  // ── Web ─────────────────────────────────────────────────
  Directory('web/icons').createSync(recursive: true);

  File('web/favicon.png').writeAsBytesSync(img.encodePng(_square(mark, 32, 0.92)));
  stdout.writeln('favicon.png : 32 px');

  for (final s in [192, 512]) {
    File('web/icons/Icon-$s.png').writeAsBytesSync(img.encodePng(_square(mark, s, 0.9)));
    stdout.writeln('Icon-$s.png');
  }

  // Zone de sécurité « maskable » : le contenu doit tenir dans le cercle
  // central (≈ 60 % de la largeur) car les bords peuvent être rognés.
  final blanc = img.ColorRgba8(255, 255, 255, 255);
  for (final s in [192, 512]) {
    File('web/icons/Icon-maskable-$s.png')
        .writeAsBytesSync(img.encodePng(_square(mark, s, 0.6, background: blanc)));
    stdout.writeln('Icon-maskable-$s.png');
  }
}
