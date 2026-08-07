import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/document_create_screen.dart';
import 'package:klr_tech_app/screens/parametres_screen.dart';
import 'support/test_fonts.dart';

/// F5 (Lot F) : `AppSettings.startNum` n'avait aucun effet — `DocNumero.next`
/// ne le lisait jamais, la numérotation repartait toujours de 01 quel que
/// soit le champ « NUMÉRO DE DÉPART ». Il devient ici le plancher du premier
/// document du jour (seule lecture cohérente avec un compteur remis à zéro
/// chaque jour — voir le commentaire de `DocNumero.next`).
///
/// F6 (Lot F) : l'exemple de numérotation ne se mettait pas à jour pendant
/// la frappe, faute de rien qui déclenche une reconstruction.
void main() {
  setUpAll(loadTestFonts);

  group('F5 — DocNumero.next lit désormais startNum', () {
    test('sans startNum, comportement inchangé : premier document = 01', () {
      final j = DateTime(2026, 4, 25);
      expect(DocNumero.next('KLR', 'proforma', [], j), 'KLR-P01-25042026');
    });

    test('startNum = 50 : le premier document du jour porte le numéro 50', () {
      final j = DateTime(2026, 4, 25);
      expect(DocNumero.next('KLR', 'proforma', [], j, startNum: '50'),
          'KLR-P50-25042026');
    });

    test('startNum décale aussi les documents suivants du même jour', () {
      final j = DateTime(2026, 4, 25);
      final deux = [
        DocumentItem(id: 1, numero: 'x', date: '25/04/2026', clientId: 0,
            client: 'C', objet: 'O', montant: 0, statut: 'cours'),
        DocumentItem(id: 2, numero: 'x', date: '25/04/2026', clientId: 0,
            client: 'C', objet: 'O', montant: 0, statut: 'cours'),
      ];
      expect(DocNumero.next('KLR', 'proforma', deux, j, startNum: '50'),
          'KLR-P52-25042026');
    });

    test('une valeur invalide ou nulle retombe sur 1, jamais sur 0', () {
      final j = DateTime(2026, 4, 25);
      expect(DocNumero.next('KLR', 'proforma', [], j, startNum: ''), 'KLR-P01-25042026');
      expect(DocNumero.next('KLR', 'proforma', [], j, startNum: 'abc'), 'KLR-P01-25042026');
      expect(DocNumero.next('KLR', 'proforma', [], j, startNum: '0'), 'KLR-P01-25042026');
      expect(DocNumero.next('KLR', 'proforma', [], j, startNum: '-5'), 'KLR-P01-25042026');
    });
  });

  group('F5 — l\'écran de création lit vraiment le réglage', () {
    testWidgets('une nouvelle proforma porte le numéro de départ configuré',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState()..viderDonnees();
      state.settings.startNum = '50';

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: DocumentCreateScreen())),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('P50-'), findsWidgets);
      expect(find.textContaining('P01-'), findsNothing);
    });
  });

  group('F6 — l\'exemple de numérotation se met à jour en direct', () {
    testWidgets('taper un nouveau préfixe met à jour l\'exemple sans enregistrer',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState();

      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
      ));
      await tester.tap(find.text('Facturation'));
      await tester.pumpAndSettle();

      // Valeur d'ouverture, dérivée des réglages par défaut (préfixe KLR).
      expect(find.textContaining('KLR-P01-010126'), findsOneWidget);

      // Le champ PRÉFIXE est le premier de l'onglet Facturation.
      await tester.enterText(find.byType(TextField).first, 'ACME');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('ACME-P01-010126'), findsOneWidget);
      expect(find.textContaining('KLR-P01-010126'), findsNothing);
    });
  });
}
