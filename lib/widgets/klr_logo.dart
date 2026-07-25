import 'package:flutter/material.dart';

/// Logo officiel KLR TECH, généré depuis le fichier du graphiste
/// (voir tool/build_logo_assets.dart).
///
/// Les deux fichiers ont un fond transparent mais conservent l'anneau blanc
/// interne du losange : ils s'affichent donc correctement aussi bien sur les
/// surfaces claires que sur la sidebar sombre.
class KlrLogo extends StatelessWidget {
  /// Hauteur souhaitée. La largeur suit le rapport d'origine.
  final double height;

  /// `true` : losange seul (petites tailles, sidebar).
  /// `false` : verrouillage complet, losange + « KLR TECH ».
  final bool markOnly;

  const KlrLogo({super.key, required this.height, this.markOnly = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        markOnly ? 'assets/logo/klr_mark.png' : 'assets/logo/klr_logo.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium, // net à petite taille
        semanticLabel: 'KLR TECH',
      );
}
