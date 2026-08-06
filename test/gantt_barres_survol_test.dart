import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/utils.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'support/test_fonts.dart';

/// Les dates exactes d'un projet ne se lisent pas sur un axe gradué au mois.
/// Chaque barre les porte donc en survol, et dit au passage ce qu'elle mesure —
/// sans quoi il faudrait retenir que le rouge est le réalisé et le bleu
/// l'encaissé.
Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: const MaterialApp(home: Scaffold(body: GanttScreen())),
  ));
  await tester.pumpAndSettle();
}

String _message(WidgetTester tester, String cle) =>
    tester.widget<Tooltip>(find.byKey(ValueKey(cle))).message!;

void main() {
  setUpAll(loadTestFonts);

  testWidgets('la barre réalisé annonce son pourcentage, son mode et ses dates',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Câblage',
      type: 'Installation / déploiement', mode: ModeAvancement.jalons, clientId: null, client: '',
      debut: DateTime(2026, 3, 12), finPrevue: DateTime(2026, 6, 28),
      jalons: [
        Jalon(nom: 'Étude', prevue: DateTime(2026, 4, 1),
            realisee: DateTime(2026, 4, 2), poids: 1),
        Jalon(nom: 'Pose', prevue: DateTime(2026, 6, 1), poids: 3),
      ]));

    await _pump(tester, s);

    final m = _message(tester, 'barre-physique-1');
    expect(m, contains('Réalisé — 25 %'), reason: '1 poids sur 4');
    expect(m, contains('Jalons'), reason: 'le mode de mesure du type installation');
    expect(m, contains('12/03/2026'), reason: 'la date de début exacte');
    expect(m, contains('28/06/2026'), reason: 'la date de fin exacte');
  });

  testWidgets('la barre encaissé annonce le montant reçu sur le montant attendu',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Prestation',
      type: 'Projet interne', mode: ModeAvancement.manuel, clientId: null, client: '',
      debut: DateTime(2026, 3, 12), finPrevue: DateTime(2026, 6, 28)));
    s.addEngagement(Engagement(
      id: 9, sens: 'entrant', tiers: 'ACME', montant: 1000,
      echeance: DateTime(2026, 6, 28), projetId: 1));
    s.ajouterReglement(9, 250, DateTime(2026, 4, 5));

    await _pump(tester, s);

    final m = _message(tester, 'barre-financiere-1');
    expect(m, contains('Encaissé — 25 %'));
    // Comparer via `Fmt.money` et non une chaîne écrite à la main : en locale
    // française le séparateur de milliers est une espace INSÉCABLE, et un
    // `contains('1 000')` tapé au clavier échoue pour une raison qui n'a rien
    // à voir avec ce que le test vérifie.
    expect(m, contains(Fmt.money(250)), reason: 'le montant déjà reçu');
    expect(m, contains(Fmt.money(1000)), reason: 'le montant attendu');
    expect(m, contains('12/03/2026'));
    expect(m, contains('28/06/2026'));
  });

  testWidgets('les deux barres portent les mêmes dates, pas le même libellé',
      (tester) async {
    final s = AppState()..viderDonnees();
    s.addProjet(Projet(
      id: 1, nom: 'Fourniture',
      type: 'Fourniture de matériel', mode: ModeAvancement.quantites, clientId: null, client: '',
      debut: DateTime(2026, 1, 5), finPrevue: DateTime(2026, 2, 20)));

    await _pump(tester, s);

    final phys = _message(tester, 'barre-physique-1');
    final fin = _message(tester, 'barre-financiere-1');

    expect(phys, startsWith('Réalisé'));
    expect(fin, startsWith('Encaissé'));
    for (final m in [phys, fin]) {
      expect(m, contains('05/01/2026'));
      expect(m, contains('20/02/2026'));
    }
  });
}
