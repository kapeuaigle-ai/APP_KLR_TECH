import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/documents_list_screen.dart';
import 'support/test_fonts.dart';

/// F8 (Lot F) : la rangée d'actions (Modifier / Imprimer / Télécharger PDF)
/// de `showFullDocument` n'était pas protégée contre le débordement et
/// dépassait d'environ 71 px à 360 px de large.
///
/// En creusant ce défaut, un second débordement — non signalé, hors du
/// périmètre décrit — est apparu dans la boîte `showDetails` qui précède
/// `showFullDocument` dans le parcours : la rangée « CHANGER LE STATUT »
/// (En cours / Validée / Annulée) n'était pas non plus bornée. Même cause,
/// même correctif (`Wrap`), donc traité ici plutôt que ré-ouvert ailleurs.
void main() {
  setUpAll(loadTestFonts);

  DocumentItem doc({required String statut}) => DocumentItem(
        id: 1, numero: 'KLR-P01-25072026', date: '25/07/2026', clientId: 0,
        client: 'Client Test', objet: 'Matériel', montant: 100000, statut: statut,
        lines: [LineItem(ref: '01', designation: 'Article', qte: 1, pu: 100000)],
      );

  Future<void> pumpAndOpenCard(WidgetTester tester, DocumentItem d) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState()..viderDonnees();
    state.documents['proforma'] = [d];

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: Scaffold(body: DocumentsListScreen())),
    ));
    await tester.pumpAndSettle();

    // Carte téléphone : tout son corps ouvre le détail.
    await tester.tap(find.text('KLR-P01-25072026'));
    await tester.pumpAndSettle();
  }

  testWidgets('la boîte de détail (proforma en cours) ne déborde pas à 360 px',
      (tester) async {
    await pumpAndOpenCard(tester, doc(statut: 'cours'));

    // C'est ici que la rangée « CHANGER LE STATUT » débordait. Les libellés
    // apparaissent aussi ailleurs (badge de statut, carte en arrière-plan) :
    // `findsWidgets` suffit, seule l'absence d'exception importe ici.
    expect(tester.takeException(), isNull);
    expect(find.text('En cours'), findsWidgets);
    expect(find.text('Validée'), findsWidgets);
    expect(find.text('Annulée'), findsWidgets);
  });

  testWidgets('la rangée Modifier / Imprimer / Télécharger PDF ne déborde pas à 360 px',
      (tester) async {
    await pumpAndOpenCard(tester, doc(statut: 'validee'));

    expect(find.text('Voir le document'), findsOneWidget);
    await tester.tap(find.text('Voir le document'));
    await tester.pumpAndSettle();

    // C'est ici que la rangée d'actions débordait avant le correctif.
    expect(tester.takeException(), isNull);
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Imprimer'), findsOneWidget);
    expect(find.text('Télécharger PDF'), findsOneWidget);
  });
}
