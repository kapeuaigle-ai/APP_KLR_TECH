import 'dart:math';
import 'package:flutter/material.dart';

/// Largeur en dessous de laquelle on bascule en mise en page téléphone.
/// Reprend le seuil déjà utilisé par [ResponsiveSplit] dans l'écran de
/// création : une seule valeur de référence dans tout le projet.
const double kPhoneBreakpoint = 700;

/// Vrai sur un écran étroit : téléphone en portrait, ou fenêtre de bureau
/// réduite.
///
/// Le choix se fait volontairement sur la **largeur** et non sur la
/// plateforme (`Platform.isAndroid`). Trois bénéfices : l'app Windows en
/// fenêtre étroite devient utilisable, une tablette ou un téléphone en
/// paysage garde la mise en page riche, et tout se vérifie dans un
/// navigateur redimensionné sans démarrer d'émulateur.
bool isPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kPhoneBreakpoint;

/// Marge intérieure d'un écran. Le bureau respire, le téléphone récupère
/// les 24 px de large que coûtait le padding de bureau.
EdgeInsets pagePadding(BuildContext context) => isPhone(context)
    ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
    : const EdgeInsets.fromLTRB(28, 28, 28, 40);

/// Largeur utile pour le contenu d'un dialogue : la largeur souhaitée sur
/// grand écran, bornée par l'écran réel moins les marges qu'`AlertDialog`
/// s'octroie (40 px de chaque côté, plus une petite réserve).
///
/// Sans cette borne, un `SizedBox(width: 420)` déborde sur un écran de
/// 360 px et lève une exception de rendu en debug.
double dialogWidth(BuildContext context, double preferred) =>
    min(preferred, MediaQuery.sizeOf(context).width - 96);

/// Grille de cartes statistiques : répartit les cartes sur une ligne
/// quand la largeur le permet, sinon passe sur plusieurs rangées.
class StatGrid extends StatelessWidget {
  final List<Widget> cards;
  final double minCardWidth;
  final double spacing;
  const StatGrid({super.key, required this.cards, this.minCardWidth = 230, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = ((w + spacing) / (minCardWidth + spacing)).floor().clamp(1, cards.length);
      final itemW = (w - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards.map((c) => SizedBox(width: itemW, child: c)).toList(),
      );
    });
  }
}

/// Barre « contenu à gauche, action à droite » qui s'empile sur téléphone.
///
/// Sur grand écran, `left` et `right` partagent une ligne, séparés par un
/// `Spacer`. Sous le seuil, `right` passe en dessous et prend toute la
/// largeur : un bouton d'action pleine largeur se vise mieux au pouce, et
/// surtout les deux réunis dépassent souvent 360 px.
class StackingRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  const StackingRow({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (isPhone(context)) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerLeft, child: left),
        SizedBox(height: spacing),
        SizedBox(width: double.infinity, child: right),
      ]);
    }
    // `left` doit réclamer TOUT l'espace restant (comme `SectionHeader`),
    // pas juste sa part d'un `Spacer` à égalité : sans `Expanded`, `left`
    // reçoit une largeur non bornée et un contenu large (ex. le sous-titre
    // de ParametresScreen) déborde plutôt que de s'enrouler — reproduit à
    // 1000-1440 px (défaut F1, Lot F). `right` garde sa taille naturelle et
    // se retrouve poussé à l'extrémité droite, exactement comme avant.
    return Row(children: [
      Expanded(child: left),
      SizedBox(width: spacing),
      right,
    ]);
  }
}

/// Deux panneaux : contenu principal extensible + panneau latéral de largeur
/// fixe. Passe en colonne quand l'écran est trop étroit.
class ResponsiveSplit extends StatelessWidget {
  final Widget main;
  final Widget side;
  final double sideWidth;
  final double breakpoint;
  final double spacing;
  const ResponsiveSplit({
    super.key, required this.main, required this.side,
    this.sideWidth = 320, this.breakpoint = 760, this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= breakpoint) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: main),
          SizedBox(width: spacing),
          SizedBox(width: sideWidth, child: side),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        main,
        SizedBox(height: spacing),
        side,
      ]);
    });
  }
}

/// Enveloppe un tableau large : ajoute un défilement horizontal quand la
/// largeur disponible est inférieure à [minWidth].
class HScrollTable extends StatelessWidget {
  final double minWidth;
  final Widget child;
  const HScrollTable({super.key, required this.minWidth, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= minWidth) return child;
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: max(minWidth, constraints.maxWidth), child: child),
        ),
      );
    });
  }
}
