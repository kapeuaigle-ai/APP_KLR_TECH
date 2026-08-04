import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/screens/parametres_screen.dart';
import 'support/test_fonts.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('les quatre types par défaut sont listés', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TYPES DE PROJET'), findsOneWidget);
    expect(find.text('Fourniture de matériel'), findsOneWidget);
    expect(find.text('Installation / déploiement'), findsOneWidget);
    expect(find.text('Maintenance / contrat'), findsOneWidget);
    expect(find.text('Projet interne'), findsOneWidget);
  });

  testWidgets('chaque type annonce son mode d\'avancement', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppState()..viderDonnees(),
      child: const MaterialApp(home: Scaffold(body: ParametresScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Quantités livrées'), findsWidgets);
    expect(find.textContaining('Jalons'), findsWidgets);
  });
}
