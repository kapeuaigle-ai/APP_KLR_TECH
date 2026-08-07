import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';
import 'package:klr_tech_app/widgets/write_failure_banner.dart';
import 'support/test_fonts.dart';

/// Store en mémoire dont les prochaines écritures peuvent être forcées à
/// échouer — même idée que `MemoryStore` de `persistence_test.dart`, dupliqué
/// ici pour ne pas faire dépendre un fichier de test d'un autre.
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

Client _client(int id) => Client(id: id, initials: 'ZZ',
    color: const Color(0xFF123456), name: 'Client $id', contact: '',
    email: '', phone: '');

Future<void> _pump(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: WriteFailureBanner())),
  ));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('rien ne s\'affiche tant qu\'aucune écriture n\'a échoué', (tester) async {
    final state = AppState(store: _FlakyStore());
    await _pump(tester, state);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('la bannière apparaît après un échec, avec un bouton Réessayer', (tester) async {
    final store = _FlakyStore()..failNextWrites = 1;
    final state = AppState(store: store);
    state.addClient(_client(900));
    await state.flush();

    await _pump(tester, state);
    expect(find.text('Réessayer'), findsOneWidget);
    // Le message dit au manager quoi faire, pas seulement qu'un problème est
    // survenu — voir la consigne « dit ce qu'il faut faire ».
    expect(find.textContaining('enregistrée'), findsOneWidget);
  });

  testWidgets('Réessayer relance l\'écriture et la bannière disparaît au succès', (tester) async {
    final store = _FlakyStore()..failNextWrites = 1;
    final state = AppState(store: store);
    state.addClient(_client(900));
    await state.flush();

    await _pump(tester, state);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await state.flush();
    await tester.pump();

    expect(find.text('Réessayer'), findsNothing);
  });
}
