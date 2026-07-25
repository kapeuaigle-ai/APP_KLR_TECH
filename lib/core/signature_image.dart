import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Traitement de l'image de signature — source unique partagée par les
/// paramètres (import), l'aperçu A4 et le générateur PDF.
///
/// Le stockage est volontairement neutre : une simple image PNG en base64.
/// Peu importe qu'elle vienne d'un fichier importé (version PC) ou, demain,
/// d'un pavé de dessin (version mobile) — le rendu ne change pas.

/// Optimise une image importée pour le stockage : réduit sa largeur à
/// [maxWidth] pixels au plus, ré-encode en PNG compact, et renvoie le base64.
///
/// Redimensionner borne le poids de la sauvegarde (le JSON contient la
/// signature en clair) tout en gardant un rendu net à la taille d'une case
/// de signature. Le décodage natif `dart:ui` accepte PNG, JPG, etc.
Future<String> encodeSignaturePng(Uint8List raw, {int maxWidth = 800}) async {
  var codec = await ui.instantiateImageCodec(raw);
  var frame = await codec.getNextFrame();
  var image = frame.image;

  // Ne redimensionne que vers le bas : jamais d'agrandissement (qui flouterait).
  if (image.width > maxWidth) {
    image.dispose();
    codec = await ui.instantiateImageCodec(raw, targetWidth: maxWidth);
    frame = await codec.getNextFrame();
    image = frame.image;
  }

  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Encodage PNG de la signature impossible');
  return base64Encode(data.buffer.asUint8List());
}

/// Décode une signature base64 en octets prêts à afficher, ou `null` si elle
/// est absente ou illisible. Ne lève jamais : une sauvegarde corrompue laisse
/// simplement la case de signature vide plutôt que de casser le rendu.
Uint8List? decodeSignature(String base64Png) {
  if (base64Png.isEmpty) return null;
  try {
    return base64Decode(base64Png);
  } catch (_) {
    return null;
  }
}
