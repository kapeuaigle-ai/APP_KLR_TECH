import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';
import 'package:klr_tech_app/main.dart';
import 'support/test_fonts.dart';

/// `WriteFailureBanner` est monté une seule fois, au-dessus d'`AppShell`
/// dans `KlrTechApp` (§ commentaire de `main.dart`) — précisément pour
/// couvrir la coquille de bureau ET la coquille téléphone (`_PhoneShell`)
/// sans dupliquer le branchement dans les deux. `write_failure_banner_test`
/// vérifie déjà le widget seul ; celui-ci vérifie qu'assemblé dans la vraie
/// racine de composition (`KlrTechApp`), avec un manager connecté, la
/// bannière apparaît réellement au-dessus de l'écran — sur les deux largeurs
/// — sans provoquer d'erreur de rendu (défaut 1, revue finitions).
class _FlakyStore implements Store {
  String? data;
  int failNextWrites = 0;
  @override
  Future<String?> read() async => data;
  @override
  void write(String d) {
    if (failNextWrites > 0) {
      failNextWrites--;
      throw Exception('échec d\'écriture simulé');
    }
    data = d;
  }
  @override
  Future<void> writeBackup(String d) async {}
}

AppState _etatConnecte(Store store) {
  final s = AppState(store: store);
  expect(s.login('admin', 'admin'), isTrue);
  return s;
}

Future<void> _pump(WidgetTester tester, AppState state, Size taille) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const KlrTechApp(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets(
      'coquille de bureau : une écriture ratée fait apparaître la bannière au-dessus d\'AppShell',
      (tester) async {
    final store = _FlakyStore()..failNextWrites = 1;
    final state = _etatConnecte(store);
    await _pump(tester, state, const Size(1400, 900));
    expect(find.text('Réessayer'), findsNothing,
        reason: 'aucune écriture n\'a encore été tentée à ce stade');

    // Une vraie mutation de données, pas une simple navigation (qui ne
    // persiste pas) : c'est elle qui déclenche l'écriture ratée.
    state.addClient(Client(id: 900, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'Client test', contact: '', email: '', phone: ''));
    await state.flush();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Réessayer'), findsOneWidget,
        reason: 'la bannière doit apparaître au-dessus de la coquille de bureau');
  });

  testWidgets(
      'coquille téléphone : une écriture ratée fait apparaître la bannière au-dessus de la barre du bas',
      (tester) async {
    final store = _FlakyStore()..failNextWrites = 1;
    final state = _etatConnecte(store);
    await _pump(tester, state, const Size(390, 844));

    state.addClient(Client(id: 900, initials: 'ZZ', color: const Color(0xFF123456),
        name: 'Client test', contact: '', email: '', phone: ''));
    await state.flush();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Réessayer'), findsOneWidget,
        reason: 'la bannière doit apparaître aussi au-dessus de la coquille téléphone');
  });
}
