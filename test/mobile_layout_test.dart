import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/main.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/widgets/sidebar.dart';
import 'package:klr_tech_app/widgets/app_header.dart';
import 'package:klr_tech_app/widgets/responsive.dart';
import 'support/test_fonts.dart';

/// Mise en page téléphone.
///
/// Le vrai enjeu de ces tests n'est pas d'affirmer que tel widget existe :
/// c'est de faire **échouer** le test sur une exception de rendu. Les
/// assertions Flutter (« RenderFlex overflowed », « borderRadius can only be
/// given on borders with uniform colors ») ne se déclenchent qu'en debug, donc
/// jamais dans l'APK release. Ce fichier est le seul filet qui les attrape.
void main() {
  setUpAll(loadTestFonts);

  /// Taille d'un téléphone d'entrée de gamme en portrait — le cas le plus
  /// serré qu'on veuille supporter. Un Pixel fait 412 px, un iPhone SE 375.
  const phone = Size(360, 800);

  /// Taille de bureau, pour vérifier qu'on n'a rien cassé au-dessus du seuil.
  const desktop = Size(1440, 900);

  Future<AppState> pumpApp(WidgetTester tester, {
    required Size size,
    NavScreen screen = NavScreen.dashboard,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..login('admin', 'admin');
    if (screen != NavScreen.dashboard) state.navigate(screen);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const KlrTechApp(),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  // ── Le prédicat lui-même ────────────────────────────────
  group('seuil de bascule', () {
    testWidgets('360 px est un téléphone, 1440 px ne l\'est pas', (tester) async {
      late bool phoneVerdict;
      Widget probe() => MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: Builder(builder: (c) {
          phoneVerdict = isPhone(c);
          return const SizedBox();
        }),
      );
      await tester.pumpWidget(probe());
      expect(phoneVerdict, isTrue);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: Builder(builder: (c) {
          phoneVerdict = isPhone(c);
          return const SizedBox();
        }),
      ));
      expect(phoneVerdict, isFalse);
    });

    testWidgets('le padding de page se resserre sur téléphone', (tester) async {
      late EdgeInsets small, large;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(360, 800)),
        child: Builder(builder: (c) { small = pagePadding(c); return const SizedBox(); }),
      ));
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: Builder(builder: (c) { large = pagePadding(c); return const SizedBox(); }),
      ));
      expect(small.left, lessThan(large.left));
      expect(small.bottom, lessThan(large.bottom));
    });
  });

  // ── Coquille ────────────────────────────────────────────
  group('coquille', () {
    testWidgets('téléphone : barre du bas, pas de sidebar ni d\'en-tête bureau',
        (tester) async {
      await pumpApp(tester, size: phone);

      expect(find.byType(Sidebar), findsNothing);
      expect(find.byType(AppHeader), findsNothing);
      // Les cinq entrées de la barre du bas.
      for (final label in ['Bord', 'Docs', 'Clients', 'Suivi', 'Plus']) {
        expect(find.text(label), findsWidgets, reason: 'entrée « $label » absente');
      }
    });

    testWidgets('bureau : sidebar et en-tête conservés, pas de barre du bas',
        (tester) async {
      await pumpApp(tester, size: desktop);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.text('Plus'), findsNothing);
    });

    testWidgets('la barre du bas navigue réellement', (tester) async {
      final state = await pumpApp(tester, size: phone);
      expect(state.screen, NavScreen.dashboard);

      await tester.tap(find.text('Clients'));
      await tester.pumpAndSettle();
      expect(state.screen, NavScreen.clients);

      await tester.tap(find.text('Suivi').first);
      await tester.pumpAndSettle();
      expect(state.screen, NavScreen.suivi);
    });

    testWidgets('la feuille « Plus » donne accès aux écrans restants',
        (tester) async {
      final state = await pumpApp(tester, size: phone);

      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();

      // Gantt doit y figurer : c'était le seul point d'entrée de Projets,
      // écran retiré du mobile.
      for (final label in ['Gantt', 'Activités', 'Rapports', 'Paramètres']) {
        expect(find.text(label), findsWidgets, reason: '« $label » absent de Plus');
      }

      await tester.tap(find.text('Rapports'));
      await tester.pumpAndSettle();
      expect(state.screen, NavScreen.rapports);
    });
  });

  // ── Projets retiré ──────────────────────────────────────
  group('écran Projets retiré du téléphone', () {
    testWidgets('aucune entrée de navigation ne mène à Projets', (tester) async {
      await pumpApp(tester, size: phone);

      expect(find.text('Projets'), findsNothing);
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      expect(find.text('Projets'), findsNothing);
    });

    testWidgets('un état pointant sur Projets est rabattu sur le tableau de bord',
        (tester) async {
      final state = await pumpApp(tester, size: phone, screen: NavScreen.projets);
      await tester.pumpAndSettle();

      expect(state.screen, NavScreen.dashboard,
          reason: 'Projets est inatteignable sur téléphone : il faut en sortir');
    });

    testWidgets('sur bureau Projets reste accessible', (tester) async {
      final state = await pumpApp(tester, size: desktop, screen: NavScreen.projets);
      expect(state.screen, NavScreen.projets);
      expect(find.text('Projets'), findsWidgets);
    });
  });

  // ── Aucun débordement, écran par écran ──────────────────
  //
  // C'est le cœur du fichier. `pumpAndSettle` propage toute exception de
  // rendu levée pendant le build : si un Row déborde ou si un dialogue est
  // plus large que l'écran, le test échoue ici.
  group('aucun débordement sur 360 x 800', () {
    const screens = <(NavScreen, String)>[
      (NavScreen.dashboard,  'Tableau de bord'),
      (NavScreen.documents,  'Documents'),
      (NavScreen.clients,    'Clients'),
      (NavScreen.gantt,      'Gantt'),
      (NavScreen.suivi,      'Suivi'),
      (NavScreen.activites,  'Activités'),
      (NavScreen.rapports,   'Rapports'),
      (NavScreen.parametres, 'Paramètres'),
    ];

    for (final (screen, label) in screens) {
      testWidgets(label, (tester) async {
        await pumpApp(tester, size: phone, screen: screen);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Création de proforma', (tester) async {
      final state = await pumpApp(tester, size: phone);
      state.setCreating(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Connexion', (tester) async {
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: AppState(), // non connecté : montre LoginScreen
          child: const KlrTechApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── Onglets ─────────────────────────────────────────────
  group('barres d\'onglets défilantes', () {
    testWidgets('les cinq onglets du Suivi tiennent sans déborder',
        (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.suivi);

      // Le premier onglet est visible ; les suivants sont accessibles par
      // défilement horizontal, sans exception de rendu.
      expect(find.text('Engagements'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les onglets de Paramètres ne débordent pas', (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.parametres);
      expect(find.text('Entreprise'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
