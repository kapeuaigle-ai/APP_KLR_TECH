import 'dart:math';
import 'package:flutter/material.dart';

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
