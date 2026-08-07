import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/main.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/theme.dart';
import 'package:klr_tech_app/widgets/sidebar.dart';
import 'package:klr_tech_app/widgets/app_header.dart';
import 'package:klr_tech_app/widgets/responsive.dart';
import 'package:klr_tech_app/widgets/common.dart';
import 'package:klr_tech_app/widgets/document_preview.dart';
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

  /// Les écrans balayés par les deux groupes « aucun débordement »
  /// (téléphone § ci-dessous, bureau § F2 plus bas) : une seule liste, pour
  /// que les deux balayages portent exactement sur les mêmes écrans.
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

  // ── Balayage bureau (défaut F2, Lot F) ──────────────────
  //
  // Les tests « bureau » d'origine se contentaient de vérifier que la
  // sidebar et l'en-tête existent, sans jamais appeler `takeException()` :
  // c'est pour ça que F1 (StackingRow) et F3 (sidebar) sont passés inaperçus
  // à des largeurs de bureau tout à fait courantes. Ce groupe rejoue le même
  // balayage écran par écran que le groupe téléphone, mais à 1000, 1152,
  // 1280, 1366 et 1440 px — le minimum demandé plus les deux largeurs déjà
  // citées dans le défaut F1 lui-même.
  group('aucun débordement à des largeurs de bureau courantes', () {
    const largeursBureau = [1000.0, 1152.0, 1280.0, 1366.0, 1440.0];

    for (final largeur in largeursBureau) {
      final taille = Size(largeur, 900);
      for (final (screen, label) in screens) {
        testWidgets('${largeur.toInt()}px · $label', (tester) async {
          await pumpApp(tester, size: taille, screen: screen);
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('${largeur.toInt()}px · Création de proforma', (tester) async {
        final state = await pumpApp(tester, size: taille);
        state.setCreating(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ── Régressions F1 et F3 : débordements structurels ─────
  //
  // Avec la police de substitution des tests (Roboto — § `test_fonts.dart`),
  // le balayage ci-dessus ne reproduit pas les débordements F1/F3 tels que
  // décrits (403 px à 1000 px de large pour F1, 1,5 px pour F3) : les
  // libellés réels sont trop courts pour déborder avec CES métriques-là. Les
  // deux défauts sont pourtant réels — `StackingRow` ne bornait pas `left`,
  // `_NavItem` ne bornait pas son libellé — et se reproduisent dès qu'on
  // pousse le contenu ou l'échelle de texte au-delà de ce que les libellés
  // actuels couvrent. Ces deux tests le prouvent directement, sans dépendre
  // de la police exacte.
  group('régressions F1 et F3', () {
    testWidgets('StackingRow (bureau) : un « left » plus long que l\'espace ne déborde pas',
        (tester) async {
      // MediaQuery en largeur « bureau » (> kPhoneBreakpoint) pour prendre la
      // branche desktop de StackingRow, mais l'espace réellement disponible
      // (SizedBox 340 px) est bien plus étroit qu'un texte de démonstration
      // volontairement long — exactement la situation de ParametresScreen
      // une fois la sidebar et le padding déduits d'une fenêtre resserrée.
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: MaterialApp(home: Scaffold(body: Center(child: SizedBox(
          width: 340,
          child: StackingRow(
            left: Text(
              'Un intitulé de démonstration bien trop long pour tenir à côté '
              'du bouton sans qu\'il ne soit borné par un Expanded.',
              style: GoogleFonts.dmSans(fontSize: 13.5),
            ),
            right: Container(width: 120, height: 32, color: AppColors.primary),
          ),
        )))),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sidebar : un texte agrandi (accessibilité, 180%) ne déborde pas',
        (tester) async {
      // Un utilisateur Windows qui grossit le texte système reste un usage
      // légitime — c'est un moyen déterministe de reproduire, indépendamment
      // de la police, l'écart de 1,5 px signalé sur `_NavItem` (sidebar.dart:130)
      // à 210 px. `Sidebar` est pompée seule plutôt que via l'app entière :
      // au-delà de 180 %, d'autres écrans développent leurs propres
      // débordements sous un texte deux fois plus grand que prévu — hors
      // périmètre de ce défaut précis, à traiter séparément.
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: Scaffold(body: Sidebar())),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Tableaux remplacés par des cartes ───────────────────
  //
  // Sans ces assertions, les tests de débordement ci-dessus passeraient même
  // si rien n'avait été converti : HScrollTable ne déborde pas, il défile.
  // Ce qu'on veut vérifier, c'est que le tableau a bien cédé la place.
  group('tableaux convertis en cartes', () {
    testWidgets('Clients : cartes sur téléphone, tableau sur bureau',
        (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.clients);
      expect(find.byType(HScrollTable), findsNothing,
          reason: 'le tableau de 1020 px ne doit pas subsister sur téléphone');
      expect(find.byType(ListCard), findsWidgets);

      await pumpApp(tester, size: desktop, screen: NavScreen.clients);
      expect(find.byType(HScrollTable), findsOneWidget);
      expect(find.byType(ListCard), findsNothing);
    });

    testWidgets('Documents : cartes sur téléphone, tableau sur bureau',
        (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.documents);
      expect(find.byType(HScrollTable), findsNothing);
      expect(find.byType(ListCard), findsWidgets);

      await pumpApp(tester, size: desktop, screen: NavScreen.documents);
      expect(find.byType(HScrollTable), findsOneWidget);
      expect(find.byType(ListCard), findsNothing);
    });

    testWidgets('Suivi / Engagements : cartes sur téléphone', (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.suivi);
      expect(find.byType(HScrollTable), findsNothing);
      expect(find.byType(ListCard), findsWidgets);
    });

    testWidgets('Suivi / Comptabilité : les trois sections en cartes',
        (tester) async {
      await pumpApp(tester, size: phone, screen: NavScreen.suivi);
      await tester.tap(find.text('Comptabilité'));
      await tester.pumpAndSettle();

      expect(find.byType(HScrollTable), findsNothing,
          reason: 'les trois tableaux (820/720/720) doivent céder la place');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gantt garde son défilement horizontal', (tester) async {
      // Décision produit : une frise chronologique se lit en défilant, elle
      // ne se découpe pas en cartes. Le Gantt est désormais alimenté par les
      // vrais projets (Phase 2, tâche 8) : sans aucun projet enregistré, il
      // affiche un état vide sans HScrollTable — il faut donc en poser un
      // pour vérifier que le tableau défile plutôt que de se transformer en
      // cartes.
      tester.view.physicalSize = phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..login('admin', 'admin');
      state.addProjet(Projet(
        id: 1, nom: 'Projet de test',
        type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: null,
        client: '', debut: DateTime(2026, 1, 1), finPrevue: DateTime(2026, 3, 1)));
      state.navigate(NavScreen.gantt);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(value: state, child: const KlrTechApp()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HScrollTable), findsOneWidget);
    });
  });

  // ── Création de proforma ────────────────────────────────
  group('création de proforma sur téléphone', () {
    testWidgets('formulaire seul, aperçu A4 derrière un bouton', (tester) async {
      final state = await pumpApp(tester, size: phone);
      state.setCreating(true);
      await tester.pumpAndSettle();

      // L'aperçu ne doit pas cohabiter avec le formulaire : il ferait 330 px
      // de large pour un texte composé en 8,5 pt.
      expect(find.byType(DocumentPreview), findsNothing);
      expect(find.text('Aperçu'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('le bouton Aperçu ouvre l\'A4 zoomable en plein écran',
        (tester) async {
      final state = await pumpApp(tester, size: phone);
      state.setCreating(true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aperçu'));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentPreview), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les lignes d\'article ne défilent plus latéralement',
        (tester) async {
      final state = await pumpApp(tester, size: phone);
      state.setCreating(true);
      await tester.pumpAndSettle();

      // La grille de saisie à cinq colonnes obligeait à défiler pendant la
      // frappe : elle est empilée sur téléphone.
      expect(find.byType(HScrollTable), findsNothing);
      expect(find.text('QTÉ'), findsWidgets);
    });

    testWidgets('bureau : aperçu et formulaire côte à côte', (tester) async {
      final state = await pumpApp(tester, size: desktop);
      state.setCreating(true);
      await tester.pumpAndSettle();

      expect(find.byType(DocumentPreview), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
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
