import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/projets_screen.dart';
import 'support/test_fonts.dart';

/// Neuf projets « En cours » : au-delà de ce qu'une colonne de 800 px de
/// haut peut montrer sans défiler. Le mode manuel + une date de fin très
/// lointaine garantit `En cours` (physique entre 0 et 1, échéance jamais
/// dépassée) indépendamment de la date système réelle.
AppState _avecNeufProjetsEnCours() {
  final s = AppState()..viderDonnees();
  for (var i = 1; i <= 9; i++) {
    s.addProjet(Projet(
      id: i, nom: 'Projet en cours $i', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
      client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2035, 1, 1)));
    s.setAvancementManuel(i, 0.5);
  }
  return s;
}

// Soixante, pas neuf : la liste des annulés est un `Wrap` sur toute la
// largeur de l'écran (1600 px), donc cinq à six cartes tiennent par rangée —
// neuf cartes n'auraient occupé que deux rangées, largement dans les 800 px
// de haut. Il en faut assez pour que la dernière rangée soit garantie hors
// champ, quel que soit le nombre de colonnes que le Wrap choisit. Porté de
// 30 à 60 quand la carte d'un projet sans argent a perdu ses lignes
// Encaissé/Attendu/Reste dû (défaut 2, revue finitions) : plus basse, elle
// ne poussait plus la dernière rangée sous les 800 px avec seulement 30
// cartes — la marge est volontairement large pour ne pas redépendre d'un
// calcul de pixels précis.
AppState _avecSoixanteProjetsAnnules() {
  final s = AppState()..viderDonnees();
  for (var i = 1; i <= 60; i++) {
    s.addProjet(Projet(
      id: i, nom: 'Projet annulé $i', type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null,
      client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2035, 1, 1)));
    s.annulerProjet(i);
  }
  return s;
}

Future<void> _pumpEcranEtroit(WidgetTester tester, AppState state) async {
  // Volontairement bas (800 px) pour garantir que neuf cartes ne tiennent
  // pas toutes à l'écran, sans dépendre d'un compte de cartes précis.
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: ProjetsScreen())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('neuf projets « En cours » : aucune exception de rendu', (tester) async {
    await _pumpEcranEtroit(tester, _avecNeufProjetsEnCours());
    expect(tester.takeException(), isNull);
  });

  testWidgets('une carte hors écran de la colonne « En cours » devient atteignable en défilant',
      (tester) async {
    final state = _avecNeufProjetsEnCours();
    await _pumpEcranEtroit(tester, state);

    // `AppState.addProjet` insère en tête de liste (LIFO) : le tout premier
    // projet créé — « Projet en cours 1 » — est donc celui qui termine en
    // bas de la colonne, le plus hors champ des neuf. `SingleChildScrollView`
    // construit toutes ses cartes d'un coup : cette carte existe déjà dans
    // l'arbre de widgets même hors champ, donc `findsNothing` ne prouverait
    // rien ici. Ce qui compte, c'est sa position : elle doit démarrer sous
    // le bas de la fenêtre (800 px), donc hors de portée tant qu'on n'a pas
    // défilé.
    final derniereCarte = find.text('Projet en cours 1');
    expect(derniereCarte, findsOneWidget);
    expect(tester.getTopLeft(derniereCarte).dy, greaterThanOrEqualTo(800),
        reason: 'avant défilement, la carte la plus ancienne doit être sous le bas visible de l\'écran');

    final colonne = find.byKey(const ValueKey('colonne-enCours'));
    expect(colonne, findsOneWidget);
    final scrollable = find.descendant(of: colonne, matching: find.byType(Scrollable));
    expect(scrollable, findsOneWidget,
        reason: 'la colonne doit porter son propre Scrollable vertical');

    await tester.scrollUntilVisible(
      derniereCarte,
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    // Après défilement, la carte est passée dans la zone visible (entre 0
    // et la hauteur de la fenêtre) : elle est désormais atteignable, pas
    // seulement présente dans l'arbre.
    final y = tester.getTopLeft(derniereCarte).dy;
    expect(y, inInclusiveRange(0, 800),
        reason: 'après défilement, la carte doit être dans la zone visible');
  });

  testWidgets('l\'en-tête de la colonne reste visible pendant le défilement', (tester) async {
    final state = _avecNeufProjetsEnCours();
    await _pumpEcranEtroit(tester, state);

    final colonne = find.byKey(const ValueKey('colonne-enCours'));
    final scrollable = find.descendant(of: colonne, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(
      find.text('Projet en cours 1'),
      200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    // L'en-tête (titre + compteur) n'a pas été emporté par le défilement.
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });

  testWidgets(
      'soixante projets annulés : aucune exception, et le dernier devient atteignable en défilant',
      (tester) async {
    final state = _avecSoixanteProjetsAnnules();
    await _pumpEcranEtroit(tester, state);
    expect(tester.takeException(), isNull);

    // Le filtre « Annulés » n'apparaît pas encore : bascule d'abord dessus.
    await tester.tap(find.textContaining('Annulés'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Même LIFO qu'ailleurs (`addProjet` insère en tête) : « Projet annulé 1 »
    // est le premier créé, donc le dernier de la liste affichée — le plus
    // sûr d'être hors champ.
    final derniereCarte = find.text('Projet annulé 1');
    expect(derniereCarte, findsOneWidget);
    expect(tester.getTopLeft(derniereCarte).dy, greaterThanOrEqualTo(800),
        reason: 'avant défilement, la carte la plus ancienne doit être sous le bas visible de l\'écran');

    await tester.scrollUntilVisible(
      derniereCarte,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final y = tester.getTopLeft(derniereCarte).dy;
    expect(y, inInclusiveRange(0, 800),
        reason: 'après défilement, la carte doit être dans la zone visible');
  });
}
