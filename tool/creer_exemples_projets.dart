// Injecte un jeu de projets d'EXEMPLE couvrant chaque colonne du Kanban et
// chacun des quatre modes d'avancement, pour voir la règle à l'œuvre.
//
// Tous passent par les vraies API métier (`addProjet`, `addEngagement`,
// `ajouterReglement`, `ajouterJalon`, `setAvancementManuel`,
// `saveOrUpdateProforma` + `validateProforma`) : ce que vous verrez est ce que
// l'application produit, pas une écriture JSON arrangée.
//
// Les dates sont RELATIVES au jour d'exécution, sans quoi les exemples
// cesseraient d'illustrer ce qu'ils illustrent au fil du temps.
//
// Chaque projet est préfixé « EXEMPLE — » : pour faire le ménage, supprimez-les
// depuis la fiche de chacun (menu ⋮ → Supprimer).
//
// L'application doit être FERMÉE : elle garde son état en mémoire et écraserait
// cette écriture.
//
// Lancement : flutter test tool/creer_exemples_projets.dart

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
  test('injecte les projets d\'exemple', () async {
    final state = AppState(store: _StoreDirect(_chemin));
    await state.init();

    final now = DateTime.now();
    DateTime jour(int decalage) => DateTime(now.year, now.month, now.day + decalage);

    final client = state.clients.firstWhere((c) => c.id == 7,
        orElse: () => state.clients.first);

    var id = now.microsecondsSinceEpoch;
    int prochainId() => id++;

    // ── 1. À démarrer, échéance encore devant ────────────────
    // Rien de commencé, rien d'encaissé, la date n'est pas là : aucun badge.
    state.addProjet(Projet(
      id: prochainId(), nom: 'EXEMPLE — Nouveau local, étude à lancer',
      typeId: 'interne', clientId: null, client: '',
      debut: jour(10), finPrevue: jour(90)));

    // ── 2. À démarrer, échéance atteinte → badge ─────────────
    // La règle « À démarrer » passe AVANT la date : une idée jamais lancée
    // n'a personne avec qui négocier. Le badge orange est le rappel.
    state.addProjet(Projet(
      id: prochainId(), nom: 'EXEMPLE — Voyage employés, jamais lancé',
      typeId: 'interne', clientId: null, client: '',
      debut: jour(-120), finPrevue: jour(-30)));

    // ── 3. En cours — mode jalons ───────────────────────────
    // Deux jalons sur quatre faits, mais pondérés : 1+2 sur 1+2+3+2 = 37,5 %,
    // et non 50 % comme le donnerait un simple décompte.
    final pJalons = prochainId();
    state.addProjet(Projet(
      id: pJalons, nom: 'EXEMPLE — Câblage siège (jalons)',
      typeId: 'installation', clientId: client.id, client: client.name,
      debut: jour(-20), finPrevue: jour(40)));
    state.ajouterJalon(pJalons, Jalon(nom: 'Étude technique', prevue: jour(-15), poids: 1));
    state.ajouterJalon(pJalons, Jalon(nom: 'Approvisionnement', prevue: jour(-5), poids: 2));
    state.ajouterJalon(pJalons, Jalon(nom: 'Pose des chemins', prevue: jour(15), poids: 3));
    state.ajouterJalon(pJalons, Jalon(nom: 'Recette client', prevue: jour(35), poids: 2));
    state.marquerJalon(pJalons, 0, jour(-14));
    state.marquerJalon(pJalons, 1, jour(-4));

    // ── 4. En cours — mode durée ────────────────────────────
    // Un contrat ne se « livre » pas : son avancement suit le calendrier.
    // À mi-parcours il affichera 50 %, sans que personne ne saisisse rien.
    final pDuree = prochainId();
    state.addProjet(Projet(
      id: pDuree, nom: 'EXEMPLE — Maintenance annuelle (durée)',
      typeId: 'maintenance', clientId: client.id, client: client.name,
      debut: jour(-180), finPrevue: jour(185)));
    state.addEngagement(Engagement(
      id: prochainId(), sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Contrat de maintenance annuel', montant: 2400000,
      echeance: jour(185), projetId: pDuree));
    state.ajouterReglement(
        state.engagementsDuProjet(pDuree).first.id, 1200000, jour(-90));

    // ── 5. En révision — échéance dépassée, travail inachevé ──
    // Le cas nominal de la renégociation : la date est passée, tout n'est
    // pas fait. Continuer, reconsidérer ou abandonner ?
    final pRetard = prochainId();
    state.addProjet(Projet(
      id: pRetard, nom: 'EXEMPLE — Déploiement retardé (échéance dépassée)',
      typeId: 'installation', clientId: client.id, client: client.name,
      debut: jour(-90), finPrevue: jour(-15)));
    state.ajouterJalon(pRetard, Jalon(nom: 'Livraison matériel', prevue: jour(-60), poids: 1));
    state.ajouterJalon(pRetard, Jalon(nom: 'Configuration', prevue: jour(-30), poids: 1));
    state.ajouterJalon(pRetard, Jalon(nom: 'Mise en service', prevue: jour(-20), poids: 1));
    state.marquerJalon(pRetard, 0, jour(-58));
    state.addEngagement(Engagement(
      id: prochainId(), sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Déploiement 3 sites', montant: 4500000,
      echeance: jour(-15), projetId: pRetard));

    // ── 6. En révision — tout livré, client n'ayant pas payé ──
    // Le travail est fini, l'échéance est passée, l'argent n'est pas là :
    // c'est le client qui n'a pas tenu son engagement.
    final pImpaye = prochainId();
    state.addProjet(Projet(
      id: pImpaye, nom: 'EXEMPLE — Livré, client n\'a pas payé',
      typeId: 'interne', clientId: client.id, client: client.name,
      debut: jour(-100), finPrevue: jour(-25), avancementManuel: 1));
    state.addEngagement(Engagement(
      id: prochainId(), sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Prestation livrée, facture impayée', montant: 1800000,
      echeance: jour(-25), projetId: pImpaye));

    // ── 7. Terminé — livré ET encaissé, échéance ancienne ────
    // La démonstration que « Terminé » passe AVANT la date : son échéance a
    // deux mois, il ne retombe pas en révision pour autant. Sans cette
    // précédence, tout l'historique de l'entreprise finirait dans la colonne.
    final pFini = prochainId();
    state.addProjet(Projet(
      id: pFini, nom: 'EXEMPLE — Terminé et encaissé (échéance ancienne)',
      typeId: 'interne', clientId: client.id, client: client.name,
      debut: jour(-150), finPrevue: jour(-60), avancementManuel: 1));
    final eFini = prochainId();
    state.addEngagement(Engagement(
      id: eFini, sens: 'entrant', clientId: client.id, tiers: client.name,
      description: 'Prestation soldée', montant: 3000000,
      echeance: jour(-60), projetId: pFini));
    state.ajouterReglement(eFini, 3000000, jour(-55));
    // Un coût rattaché : c'est lui qui rend la marge réelle.
    final sortant = prochainId();
    state.addEngagement(Engagement(
      id: sortant, sens: 'sortant', tiers: 'Sous-traitant',
      description: 'Sous-traitance du chantier', montant: 1100000,
      echeance: jour(-70), categorie: 'Sous-traitance', projetId: pFini));
    state.ajouterReglement(sortant, 1100000, jour(-68));

    // ── 8. Mode quantités, avec proforma ────────────────────
    // Le seul exemple qui consomme un numéro de document. Il montre la
    // pondération par le montant : les 30 câbles livrés pèsent bien moins
    // que le serveur qui ne l'est pas.
    final pQte = prochainId();
    state.addProjet(Projet(
      id: pQte, nom: 'EXEMPLE — Fourniture partielle (quantités)',
      typeId: 'fourniture', clientId: client.id, client: client.name,
      debut: jour(-30), finPrevue: jour(30)));
    final lignes = [
      LineItem(ref: 'SRV-R450', designation: 'Serveur rack Dell R450', qte: 1, pu: 3200000),
      LineItem(ref: 'CBL-CAT6', designation: 'Câble réseau CAT6 (5 m)', qte: 30, pu: 4500),
      LineItem(ref: 'BAI-42U', designation: 'Baie 42U', qte: 1, pu: 850000),
    ];
    final numero = DocNumero.next(
        state.settings.prefix, 'proforma', state.documents['proforma']!, now);
    final docId = prochainId();
    state.saveOrUpdateProforma(DocumentItem(
      id: docId, numero: numero, date: Fmt.jour(now), dateAffichee: Fmt.jour(now),
      clientId: client.id, client: client.name, clientAddr: client.address,
      objet: 'Fourniture serveur et câblage', montant: 4185000,
      statut: 'cours', projetId: pQte, lines: lignes));
    state.validateProforma(docId);
    state.setQuantiteLivree(docId, 1, 30); // les 30 câbles, pas le serveur
    state.ajouterReglement(
        state.engagementsDuProjet(pQte).firstWhere((e) => e.estEntrant).id,
        1000000, jour(-5));

    await state.flush();

    // ── Compte rendu ────────────────────────────────────────
    final relu = AppState(store: _StoreDirect(_chemin));
    await relu.init();

    stdout.writeln('');
    stdout.writeln('${'PROJET'.padRight(52)} ${'COLONNE'.padRight(14)} RÉALISÉ  ENCAISSÉ  MARGE');
    stdout.writeln('-' * 100);
    for (final p in relu.projets.where((p) => p.nom.startsWith('EXEMPLE'))) {
      final a = relu.avancementProjet(p.id, now: now);
      final badge = a.statut == StatutProjet.aDemarrer && a.finDepassee ? '  [badge]' : '';
      stdout.writeln(
        '${p.nom.padRight(52)} '
        '${(a.statut.libelle + badge).padRight(14)} '
        '${(a.physique * 100).round().toString().padLeft(5)}% '
        '${(a.financier * 100).round().toString().padLeft(8)}% '
        '${Fmt.money(a.marge).padLeft(16)}',
      );
    }
    stdout.writeln('');
    stdout.writeln('Proforma créée pour l\'exemple « quantités » : $numero');

    expect(relu.projets.where((p) => p.nom.startsWith('EXEMPLE')), hasLength(8));
  });
}
