import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/screens/clients_screen.dart';
import 'package:klr_tech_app/screens/gantt_screen.dart';
import 'package:klr_tech_app/screens/rapports_screen.dart';
import 'support/test_fonts.dart';

/// Trois retours de lecture sur les écrans, corrigés ensemble :
///
///  * Rapports / « Mouvements de la période » annonçait les créances en cours
///    — une situation à date, donc de l'argent PAS reçu — sous un titre qui
///    promet des mouvements, et tronquait la liste à 20 lignes en renvoyant au
///    PDF. Cette page sert à présenter l'activité à un investisseur : elle doit
///    montrer les mouvements, tous, et rien d'autre.
///  * Clients était trié par ordre d'insertion, pas par chiffre d'affaires.
///  * Gantt coupe les noms longs dans sa colonne de 220 px sans jamais les
///    redonner en entier.
void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, AppState state, Widget ecran) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(home: Scaffold(body: ecran)),
    ));
    await tester.pumpAndSettle();
  }

  Client client(int id, String nom) => Client(
        id: id, initials: nom.substring(0, 2).toUpperCase(), color: Colors.blue,
        name: nom, contact: '', email: '', phone: '',
      );

  group('Rapports — mouvements de la période', () {
    /// L'onglet Financier s'ouvre sur « Ce mois » : les règlements doivent
    /// tomber dans le mois courant pour être visibles.
    AppState avecMouvements(int combien) {
      final now = DateTime.now();
      final s = AppState()..viderDonnees();
      for (var i = 0; i < combien; i++) {
        s.addEngagement(Engagement(
          id: i + 1, sens: 'entrant', tiers: 'Client $i',
          description: 'Vente numéro $i',
          montant: 100000, echeance: DateTime(now.year, now.month, 1),
        ));
        s.ajouterReglement(i + 1, 100000, DateTime(now.year, now.month, 1));
      }
      return s;
    }

    testWidgets('la ligne « Créances en cours » a disparu', (tester) async {
      final s = avecMouvements(1);
      // Une créance non soldée : c'est elle qui alimentait la ligne retirée.
      s.addEngagement(Engagement(
        id: 900, sens: 'entrant', tiers: 'Débiteur', description: 'Reste dû',
        montant: 750000, echeance: DateTime.now(),
      ));

      await pump(tester, s, const RapportsScreen());

      expect(find.text('Mouvements de la période'), findsOneWidget);
      expect(find.textContaining('Créances en cours'), findsNothing);
    });

    testWidgets('tous les mouvements sont listés, sans plafond à 20',
        (tester) async {
      await pump(tester, avecMouvements(23), const RapportsScreen());

      expect(find.text('Vente numéro 22'), findsOneWidget,
          reason: 'la 23e ligne était coupée par le plafond');
      expect(find.textContaining('autres — tous figurent dans le PDF'),
          findsNothing);
    });
  });

  group('Clients', () {
    testWidgets('la liste est triée par CA total décroissant', (tester) async {
      final s = AppState()..viderDonnees();
      for (final (id, nom, encaisse) in [
        (1, 'Petit client', 200000.0),
        (2, 'Gros client', 9000000.0),
        (3, 'Client moyen', 1500000.0),
      ]) {
        s.addClient(client(id, nom));
        s.addEngagement(Engagement(
          id: 100 + id, sens: 'entrant', clientId: id, tiers: nom,
          montant: encaisse, echeance: DateTime(2026, 6, 1),
        ));
        s.ajouterReglement(100 + id, encaisse, DateTime(2026, 6, 1));
      }

      await pump(tester, s, const ClientsScreen());

      double y(String nom) => tester.getTopLeft(find.text(nom)).dy;
      expect(y('Gros client'), lessThan(y('Client moyen')));
      expect(y('Client moyen'), lessThan(y('Petit client')));
    });

    testWidgets('à CA égal (notamment à 0), le nom départage', (tester) async {
      final s = AppState()..viderDonnees();
      s.addClient(client(1, 'Zeta'));
      s.addClient(client(2, 'Alpha'));

      await pump(tester, s, const ClientsScreen());

      expect(tester.getTopLeft(find.text('Alpha')).dy,
          lessThan(tester.getTopLeft(find.text('Zeta')).dy));
    });
  });

  group('Gantt', () {
    testWidgets('le nom tronqué est redonné en entier au survol', (tester) async {
      const nomLong = 'Déploiement du réseau structuré, site principal et annexe';
      final s = AppState()..viderDonnees();
      s.addProjet(Projet(
        id: 1, nom: nomLong, type: 'Installation / déploiement',
        mode: ModeAvancement.manuel, clientId: 7, client: 'Advans Côte d\'Ivoire',
        debut: DateTime(2026, 3, 1), finPrevue: DateTime(2026, 6, 30),
      ));

      await pump(tester, s, const GanttScreen());

      final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: find.text(nomLong), matching: find.byType(Tooltip)));
      expect(tooltip.message, contains(nomLong));
      expect(tooltip.message, contains('Advans Côte d\'Ivoire'),
          reason: 'deux projets d\'un même client doivent rester distinguables');
    });
  });
}
