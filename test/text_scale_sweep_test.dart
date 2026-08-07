import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/main.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'support/test_fonts.dart';

/// Balayage à l'échelle de texte système — 100 %, 150 %, 200 %.
///
/// `test/mobile_layout_test.dart` balaie déjà chaque écran, aux largeurs
/// téléphone et bureau, à l'échelle par défaut (100 %). Une passe antérieure
/// avait signalé — et délibérément laissé — deux débordements à 200 % (le
/// logo de la sidebar, l'en-tête de la carte des alertes du tableau de bord)
/// sans jamais vérifier si d'autres en-têtes de carte partageaient la même
/// forme (un `Row` sans `Expanded` sur son texte). Ce fichier reprend le même
/// principe que `mobile_layout_test.dart` — `pumpAndSettle` propage toute
/// exception de rendu, `takeException()` la fait échouer ici — mais y ajoute
/// la troisième dimension qui manquait : l'échelle de texte.
///
/// Duplique délibérément son propre `pumpApp` et sa propre liste d'écrans
/// plutôt que d'importer ceux de `mobile_layout_test.dart` : un fichier de
/// test ne doit pas dépendre d'un autre (même principe que les doubles de
/// `Store` dupliqués entre fichiers de test — voir leurs commentaires).
void main() {
  setUpAll(loadTestFonts);

  const phone = Size(360, 800);
  const desktop = Size(1440, 900);
  const echelles = [1.0, 1.5, 2.0];

  // Les huit écrans atteignables des deux côtés du seuil téléphone/bureau —
  // Projets en est exclu ici (comme dans mobile_layout_test.dart) : il est
  // inatteignable sur téléphone, l'état y est rabattu sur le tableau de bord
  // avant même de construire l'écran. Couvert séparément, bureau seulement,
  // plus bas.
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

  Future<AppState> pumpApp(WidgetTester tester, {
    required Size size,
    required double echelle,
    NavScreen screen = NavScreen.dashboard,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = echelle;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

  for (final echelle in echelles) {
    final pct = (echelle * 100).round();

    group('$pct % · téléphone (360×800)', () {
      for (final (screen, label) in screens) {
        testWidgets(label, (tester) async {
          await pumpApp(tester, size: phone, echelle: echelle, screen: screen);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('Connexion', (tester) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: AppState(), // non connecté : montre LoginScreen
            child: const KlrTechApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Création de proforma', (tester) async {
        final state = await pumpApp(tester, size: phone, echelle: echelle);
        state.setCreating(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });

    group('$pct % · bureau (1440×900)', () {
      for (final (screen, label) in screens) {
        testWidgets(label, (tester) async {
          await pumpApp(tester, size: desktop, echelle: echelle, screen: screen);
          expect(tester.takeException(), isNull);
        });
      }

      // Projets : bureau seulement, voir la note sur `screens` plus haut.
      testWidgets('Projets', (tester) async {
        await pumpApp(tester, size: desktop, echelle: echelle, screen: NavScreen.projets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Connexion', (tester) async {
        tester.view.physicalSize = desktop;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: AppState(),
            child: const KlrTechApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Création de proforma', (tester) async {
        final state = await pumpApp(tester, size: desktop, echelle: echelle);
        state.setCreating(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  }
}
