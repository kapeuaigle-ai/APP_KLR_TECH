import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Familles réclamées par `GoogleFonts.dmSans` selon le poids/style. Les enregistrer
/// avec une vraie police évite l'écart mesure/rendu en test (voir plus bas).
const _regularFamilies = ['DMSans_regular'];
const _boldFamilies = ['DMSans_500', 'DMSans_600', 'DMSans_700', 'DMSans_800', 'DMSans_900'];

/// Charge une vraie police (Roboto, fournie par le SDK Flutter) sous les noms de
/// famille que réclame `GoogleFonts.dmSans`.
///
/// En test, DM Sans n'est pas téléchargeable : sans ceci, `TextPainter` (la mesure
/// du paginateur) ne résout aucune police et renvoie une hauteur dégénérée, alors
/// que le widget `Text` se rabat sur une police réelle — les deux divergent et la
/// pagination mesurée ne correspond pas au rendu. En enregistrant une police
/// réelle sous la famille demandée, mesure et rendu utilisent la MÊME police,
/// exactement comme en production (où DM Sans est chargée pour les deux). Roboto a
/// des métriques représentatives : si le modèle ne déborde pas avec Roboto, sa
/// logique est validée.
Future<void> loadTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final root = _flutterRoot();
  final regular = _read('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
  final bold = _read('$root/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf');

  Future<void> register(String family, ByteData bytes) async {
    final loader = FontLoader(family)..addFont(Future.value(bytes));
    await loader.load();
  }

  for (final f in _regularFamilies) {
    await register(f, regular);
  }
  for (final f in _boldFamilies) {
    await register(f, bold);
  }
}

String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && Directory(fromEnv).existsSync()) return fromEnv;
  // .../flutter/bin/cache/dart-sdk/bin/dart(.exe) → remonter jusqu'à flutter/.
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('Racine Flutter introuvable depuis ${Platform.resolvedExecutable}');
}

ByteData _read(String path) {
  final bytes = File(path).readAsBytesSync();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}
