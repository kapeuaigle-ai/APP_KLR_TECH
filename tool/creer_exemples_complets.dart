// Complète le jeu d'exemples : les neuf cas restants dont nous avons parlé,
// en plus des huit déjà injectés par `creer_exemples_projets.dart`.
//
// Couvre les cinq statuts, les quatre modes d'avancement, les deux sortes de
// retard, la marge dans les deux sens, et les trois cas limites qui ont donné
// lieu à un correctif.
//
// Tout passe par les vraies API métier. Les dates sont RELATIVES au jour
// d'exécution. Les projets sont préfixés « EXEMPLE — » pour être repérables et
// supprimables.
//
// L'application doit être FERMÉE.
//
// Lancement : flutter test tool/creer_exemples_complets.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';
import 'package:klr_tech_app/core/utils.dart';

class _StoreDirect implements Store {
  final File _f;
  _StoreDirect(String chemin) : _f = File(chemin);
  @override
  Future<String?> read() async => await _f.exists() ? _f.readAsString() : null;
  @override
  Future<void> write(String data) => _f.writeAsString(data, flush: true);
  @override
  Future<void> writeBackup(String data) async {}
  @override
  Future<void> clear() async {}
}

const _chemin =
    r'C:\Users\HP\AppData\Roaming\ci.klrtech\KLR TECH - Gestion\klr_data.json';

void main() {
  test('injecte les exemples restants', () async {
    final state = AppState(store: _StoreDirect(_chemin));
    await state.init();

    final now = DateTime.now();
    DateTime jour(int d) => DateTime(now.year, now.month, now.day + d);

    final client = state.clients.firstWhere((c) => c.id == 7,
        orElse: () => state.clients.first);

    var id = now.microsecondsSinceEpoch;
    int nid() => id++;

    // ── 9. Annulé ───────────────────────────────────────────
    // Sort du tableau. Atteignable par le filtre « Annulés » de l'en-tête,
    // où son menu ne propose plus que Réactiver et Modifier.
    final pAnnule = nid();
    state.addProjet(Projet(
      id: pAnnule, nom: 'EXEMPLE — Abandonné après négociation',
      typeId: 'installation', clientId: client.id, client: client.name,
      debut: jour(-70), finPrevue: jour(-10)));
    state.annulerProjet(pAnnule);

    // ── 10. Terminé sans aucun argent attendu ───────────────
    // Aucun engagement rattaché : `attendu` vaut 0, donc `financier` reste
    // nul à jamais. Avant correctif, ce projet restait bloqué en révision
    // en annonçant un encaissement qui n'avait jamais été attendu.
    state.addProjet(Projet(
      id: nid(), nom: 'EXEMPLE — Refonte interne achevée (aucun argent)',
      typeId: 'interne', clientId: null, client: '',
      debut: jour(-60), finPrevue: jour(-20), avancementManuel: 1));

    // ── 11. Livré mais impayé, AVANT échéance → En cours ────
    // Le signal que vous avez accepté de perdre du bandeau : le travail est
    // fini, l'argent n'est pas là, mais la date laisse encore du temps.
    final pAvant = nid();
    state.addProjet(Projet(
      id: pAvant, nom: 'EXEMPLE — Livré, impayé, mais échéance devant',
      typeId: 'interne', clientId: client.id, client: client.name,
      debut: jour(-40), finPrevue: jour(25), avancementManuel: 1));
    state.addEngagement(Engagement(
      id: nid(), sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Facture émise, non encore réglée', montant: 1500000,
      echeance: jour(25), projetId: pAvant));

    // ── 12. Le jour même de l'échéance ──────────────────────
    // Pas encore en révision : le jour de l'échéance n'est pas un retard,
    // même convention que `Engagement.enRetard`. Il bascule demain.
    final pJourJ = nid();
    state.addProjet(Projet(
      id: pJourJ, nom: 'EXEMPLE — Échéance AUJOURD\'HUI (bascule demain)',
      typeId: 'installation', clientId: client.id, client: client.name,
      debut: jour(-45), finPrevue: jour(0)));
    state.ajouterJalon(pJourJ, Jalon(nom: 'Préparation', prevue: jour(-30), poids: 1));
    state.ajouterJalon(pJourJ, Jalon(nom: 'Exécution', prevue: jour(-5), poids: 1));
    state.marquerJalon(pJourJ, 0, jour(-28));

    // ── 13. Mode manuel, avancement partiel ─────────────────
    // Ni quantités ni jalons : un curseur, pour ce qui ne se mesure pas.
    state.addProjet(Projet(
      id: nid(), nom: 'EXEMPLE — Étude R&D (curseur manuel à 40 %)',
      typeId: 'interne', clientId: null, client: '',
      debut: jour(-25), finPrevue: jour(60), avancementManuel: 0.4));

    // ── 14. Retard de PAIEMENT sans retard de livraison ─────
    // La créance est échue depuis trois semaines, mais le projet, lui, a
    // encore deux mois devant lui. Deux retards distincts : la carte
    // signale le paiement en rouge, la colonne reste « En cours ».
    final pRetardPaie = nid();
    state.addProjet(Projet(
      id: pRetardPaie, nom: 'EXEMPLE — Acompte en retard, projet à l\'heure',
      typeId: 'installation', clientId: client.id, client: client.name,
      debut: jour(-30), finPrevue: jour(60)));
    state.ajouterJalon(pRetardPaie, Jalon(nom: 'Démarrage', prevue: jour(-25), poids: 1));
    state.ajouterJalon(pRetardPaie, Jalon(nom: 'Livraison', prevue: jour(50), poids: 1));
    state.marquerJalon(pRetardPaie, 0, jour(-24));
    state.addEngagement(Engagement(
      id: nid(), sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Acompte de démarrage, échu', montant: 900000,
      echeance: jour(-21), projetId: pRetardPaie));

    // ── 15. Marge négative ──────────────────────────────────
    // Encaissé 800 000, dépensé 1 250 000 : le projet coûte plus qu'il ne
    // rapporte. La ligne Marge s'affiche en rouge.
    final pPerte = nid();
    state.addProjet(Projet(
      id: pPerte, nom: 'EXEMPLE — Chantier à perte (marge négative)',
      typeId: 'interne', clientId: client.id, client: client.name,
      debut: jour(-80), finPrevue: jour(-35), avancementManuel: 1));
    final eIn = nid();
    state.addEngagement(Engagement(
      id: eIn, sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Prestation facturée', montant: 800000,
      echeance: jour(-35), projetId: pPerte));
    state.ajouterReglement(eIn, 800000, jour(-33));
    final eOut = nid();
    state.addEngagement(Engagement(
      id: eOut, sens: 'sortant', tiers: 'Sous-traitant',
      description: 'Dépassement de sous-traitance', montant: 1250000,
      echeance: jour(-40), categorie: 'Sous-traitance', projetId: pPerte));
    state.ajouterReglement(eOut, 1250000, jour(-38));

    // ── 16. Deux proformas, un seul projet ──────────────────
    // L'argument qui a fait choisir cette modélisation : une fourniture
    // livrée en deux tranches reste UN projet. Si le projet était la
    // proforma, il y aurait ici deux lignes sur le Gantt.
    final pDeux = nid();
    state.addProjet(Projet(
      id: pDeux, nom: 'EXEMPLE — Fourniture en deux tranches',
      typeId: 'fourniture', clientId: client.id, client: client.name,
      debut: jour(-35), finPrevue: jour(45)));

    for (final (rang, lignes) in [
      (1, [LineItem(ref: 'PC-T1', designation: 'Postes de travail — tranche 1', qte: 10, pu: 420000)]),
      (2, [LineItem(ref: 'PC-T2', designation: 'Postes de travail — tranche 2', qte: 6, pu: 420000)]),
    ]) {
      final numero = DocNumero.next(
          state.settings.prefix, 'proforma', state.documents['proforma']!, now);
      final docId = nid();
      state.saveOrUpdateProforma(DocumentItem(
        id: docId, numero: numero, date: Fmt.jour(now), dateAffichee: Fmt.jour(now),
        clientId: client.id, client: client.name, clientAddr: client.address,
        objet: 'Fourniture postes de travail — tranche $rang',
        montant: lignes.fold(0.0, (s, l) => s + l.total),
        statut: 'cours', projetId: pDeux, lines: lignes));
      state.validateProforma(docId);
      // La tranche 1 est livrée, la tranche 2 ne l'est pas.
      if (rang == 1) state.setQuantiteLivree(docId, 0, 10);
    }

    // ── 17. Type de projet disparu ──────────────────────────
    // Cas d'une sauvegarde restaurée après suppression d'un type : le mode
    // retombe sur « quantités » et la fiche affiche un avertissement orange.
    state.addProjet(Projet(
      id: nid(), nom: 'EXEMPLE — Type supprimé (repli sur quantités)',
      typeId: 'type_qui_nexiste_plus', clientId: client.id, client: client.name,
      debut: jour(-15), finPrevue: jour(45)));

    await state.flush();

    // ── Compte rendu ────────────────────────────────────────
    final relu = AppState(store: _StoreDirect(_chemin));
    await relu.init();

    stdout.writeln('');
    stdout.writeln('${'PROJET'.padRight(50)} ${'COLONNE'.padRight(12)} RÉAL. ENCAIS.  MARGE');
    stdout.writeln('-' * 102);
    for (final p in relu.projets.where((p) => p.nom.startsWith('EXEMPLE'))) {
      final a = relu.avancementProjet(p.id, now: now);
      final marques = [
        if (a.statut == StatutProjet.aDemarrer && a.finDepassee) 'badge',
        if (a.enRetardPaiement) 'paiement en retard',
        if (a.marge < 0) 'marge négative',
      ].join(', ');
      stdout.writeln(
        '${p.nom.padRight(50)} '
        '${(p.annule ? 'Annulé' : a.statut.libelle).padRight(12)} '
        '${(a.physique * 100).round().toString().padLeft(4)}% '
        '${(a.financier * 100).round().toString().padLeft(6)}% '
        '${Fmt.money(a.marge).padLeft(16)}'
        '${marques.isEmpty ? '' : '   ← $marques'}',
      );
    }

    final exemples = relu.projets.where((p) => p.nom.startsWith('EXEMPLE'));
    stdout.writeln('');
    stdout.writeln('Total exemples : ${exemples.length}');
    expect(exemples, hasLength(17));
  });
}
