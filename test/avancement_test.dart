import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/avancement.dart';
import 'package:klr_tech_app/core/models.dart';

Projet _projet({int id = 1, DateTime? debut, DateTime? fin}) => Projet(
      id: id, nom: 'Fourniture', typeId: 'fourniture', clientId: 5,
      client: 'ACME',
      debut: debut ?? DateTime(2026, 3, 1),
      finPrevue: fin ?? DateTime(2026, 6, 30),
    );

DocumentItem _proforma(int projetId, List<LineItem> lines) => DocumentItem(
      id: 1, numero: 'KLR-P01-10012026', date: '10/01/2026', clientId: 5,
      client: 'ACME', objet: 'PC', montant: 0, statut: 'validee',
      projetId: projetId, lines: lines,
    );

Engagement _entrant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 1, sens: 'entrant', tiers: 'ACME', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Engagement _sortant(int projetId, double montant, List<Reglement> regs) =>
    Engagement(id: 2, sens: 'sortant', tiers: 'Fournisseur', montant: montant,
        echeance: DateTime(2026, 6, 30), projetId: projetId, reglements: regs);

Reglement _r(double m, DateTime d) => Reglement(id: 1, date: d, montant: m);

void main() {
  group('avancement physique — mode quantites', () {
    test('rien de livré donne 0', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
    });

    test('la pondération se fait par le montant, pas par le nombre d\'articles', () {
      // 20 souris à 5 (=100) toutes livrées, 1 serveur à 900 non livré.
      // Par articles : 20/21 = 95 %. Par montant : 100/1000 = 10 %.
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [
          LineItem(ref: 'SOU', designation: 'Souris', qte: 20, pu: 5, qteLivree: 20),
          LineItem(ref: 'SRV', designation: 'Serveur', qte: 1, pu: 900, qteLivree: 0),
        ])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, closeTo(0.10, 0.0001));
    });

    test('tout livré donne 1', () {
      final a = Avancement.calculer(
        projet: _projet(),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 1);
    });

    test('sans proforma, l\'avancement vaut 0 et jamais NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });

    test('des lignes à prix nul ne produisent pas de NaN', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'X', designation: 'Offert', qte: 5, pu: 0, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 0);
      expect(a.physique.isNaN, isFalse);
    });
  });

  group('avancement financier', () {
    test('règlements ÷ montant attendu', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(400, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, closeTo(0.4, 0.0001));
      expect(a.montantAttendu, 1000);
      expect(a.montantEncaisse, 400);
    });

    test('les engagements sortants ne comptent pas dans le financier', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 1);
      expect(a.montantAttendu, 1000);
    });

    test('sans engagement entrant, le financier vaut 0', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites,
        proformas: const [], engagements: const [], now: DateTime(2026, 4, 1),
      );
      expect(a.financier, 0);
    });

    test('un engagement annulé est ignoré', () {
      final annule = _entrant(1, 5000, [])..annule = true;
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [annule, _entrant(1, 1000, [_r(500, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
      );
      expect(a.montantAttendu, 1000);
      expect(a.financier, closeTo(0.5, 0.0001));
    });

    // Régression : Phase 1 a déjà corrigé ce résidu flottant sur
    // `Engagement.reste` (voir son commentaire). `Avancement.financier` ne
    // doit pas réintroduire le même bug en recalculant un ratio brut à
    // partir de sommes non écrêtées.
    test('un résidu flottant sous le centime ne bloque pas le statut soldé', () {
      // 132.81 + 711.54 + 155.65 = 999.9999999999999 en IEEE-754, soit un
      // résidu de 1.1368683772161603e-13 sur un total de 1000 — un engagement
      // pourtant intégralement réglé.
      final e1 = _entrant(1, 1000, [
        _r(132.81, DateTime(2026, 4, 1)),
        _r(711.54, DateTime(2026, 4, 2)),
        _r(155.65, DateTime(2026, 4, 3)),
      ]);
      expect(e1.reste, 0); // la protection de Phase 1 tient toujours
      expect(e1.solde, isTrue);

      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [e1],
        now: DateTime(2026, 4, 1),
        physiqueForce: 1,
      );
      expect(a.financier, 1);
      expect(a.statut, StatutProjet.termine);
      expect(a.montantRestant, 0);
    });

    // Mise à jour (redéfinition « En révision ») : l'ancienne attente était
    // `termineNonPaye` du seul fait que 0.02 restait dû, quelle que soit la
    // date. `now` (4 avril) est avant `finPrevue` (30 juin, par défaut de
    // `_projet`) : l'échéance n'est pas atteinte, donc `enCours` — le manager
    // a accepté de perdre ce signal du tableau ; le marqueur rouge de retard
    // de paiement sur la carte le couvre toujours.
    test('un solde réellement dû de 0.02 est bien reporté, pas avalé', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(999.98, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1),
        physiqueForce: 1,
      );
      expect(a.montantRestant, closeTo(0.02, 0.0001));
      expect(a.financier, lessThan(1));
      expect(a.statut, StatutProjet.enCours);
    });
  });

  group('marge et retard', () {
    test('la marge est entrants réglés moins sortants réglés', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, 400);
    });

    // Régression : même défaut que sur `Engagement.reste` (Phase 1) et
    // `Avancement.financier` (Phase 2), une troisième fois. Un projet à
    // l'équilibre exact (encaissé == décaissé, pass-through de
    // sous-traitance, cas normal du métier) peut laisser un résidu flottant
    // IEEE-754 tout juste sous zéro — affiché en rouge par `projets_screen`
    // alors que le projet n'a rien perdu.
    test('un résidu flottant sous le centime rapporte une marge de zéro', () {
      // 132.81 + 711.54 + 155.65 = 999.9999999999999 en IEEE-754, contre
      // 1000 décaissé en un seul règlement : résidu de -1.1368683772161603e-13.
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [
            _r(132.81, DateTime(2026, 4, 1)),
            _r(711.54, DateTime(2026, 4, 2)),
            _r(155.65, DateTime(2026, 4, 3)),
          ]),
          _sortant(1, 1000, [_r(1000, DateTime(2026, 4, 4))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, 0);
    });

    test('une perte réelle de 0.02 reste reportée, pas avalée par l\'écrêtage', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(999.98, DateTime(2026, 4, 1))]),
          _sortant(1, 1000, [_r(1000, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, closeTo(-0.02, 0.0001));
    });

    test('un profit réel n\'est pas affecté par l\'écrêtage', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [
          _entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))]),
          _sortant(1, 600, [_r(600, DateTime(2026, 4, 2))]),
        ],
        now: DateTime(2026, 4, 1),
      );
      expect(a.marge, 400);
    });

    test('en retard si la fin prévue est dépassée et le physique incomplet', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 5)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isTrue);
    });

    test('pas de retard si tout est livré, même après la date', () {
      final a = Avancement.calculer(
        projet: _projet(fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.quantites,
        proformas: [_proforma(1, [LineItem(ref: 'PC', designation: 'PC', qte: 10, pu: 300, qteLivree: 10)])],
        engagements: const [], now: DateTime(2026, 7, 1),
      );
      expect(a.enRetardLivraison, isFalse);
    });
  });

  group('statut déduit', () {
    // `now` par défaut (4 avril) est avant `finPrevue` par défaut de
    // `_projet()` (30 juin) : l'échéance n'est pas atteinte, sauf si le
    // test la fait glisser explicitement.
    StatutProjet calculerStatut({
      required double phys, required double fin, bool annule = false,
      DateTime? now,
    }) {
      final projet = _projet();
      projet.annule = annule;
      return Avancement.calculer(
        projet: projet,
        mode: ModeAvancement.manuel,
        proformas: const [],
        engagements: fin == 0
            ? const []
            : [_entrant(1, 1000, [_r(1000 * fin, DateTime(2026, 4, 1))])],
        now: now ?? DateTime(2026, 4, 1),
        physiqueForce: phys,
      ).statut;
    }

    test('annulé l\'emporte sur tout', () {
      expect(calculerStatut(phys: 1, fin: 1, annule: true), StatutProjet.annule);
    });
    test('0 et 0 : à démarrer', () {
      expect(calculerStatut(phys: 0, fin: 0), StatutProjet.aDemarrer);
    });
    test('100 et 100 : terminé', () {
      expect(calculerStatut(phys: 1, fin: 1), StatutProjet.termine);
    });
    // Redéfinition « En révision » : livré à 100 % mais encaissé à 50 % ne
    // suffit plus à lui seul — il faut aussi que l'échéance soit dépassée.
    // Ici `now` est avant `finPrevue` : le manager n'a encore rien à
    // renégocier, le projet reste simplement en cours.
    test('100 livré, 50 encaissé, échéance PAS atteinte : en cours', () {
      expect(calculerStatut(phys: 1, fin: 0.5), StatutProjet.enCours);
    });
    // Même situation, mais l'échéance est maintenant dépassée : c'est
    // exactement le signal que « En révision » doit porter.
    test('100 livré, 50 encaissé, échéance dépassée : en révision', () {
      expect(calculerStatut(phys: 1, fin: 0.5, now: DateTime(2026, 7, 1)),
          StatutProjet.termineNonPaye);
    });
    test('50 livré : en cours', () {
      expect(calculerStatut(phys: 0.5, fin: 0.5), StatutProjet.enCours);
    });
    // Même chose : 50 % réalisé mais l'échéance est dépassée bascule en
    // révision.
    test('50 livré, échéance dépassée : en révision', () {
      expect(calculerStatut(phys: 0.5, fin: 0.5, now: DateTime(2026, 7, 1)),
          StatutProjet.termineNonPaye);
    });
    test('0 livré mais déjà encaissé : en cours, pas à démarrer', () {
      expect(calculerStatut(phys: 0, fin: 0.3), StatutProjet.enCours);
    });
    // Un projet jamais démarré ne bascule jamais en révision, même après sa
    // date : rien à renégocier tant que rien n'a commencé (§ règle 3 avant
    // règle 4).
    test('0 et 0, échéance dépassée : reste à démarrer, pas en révision', () {
      expect(calculerStatut(phys: 0, fin: 0, now: DateTime(2026, 7, 1)),
          StatutProjet.aDemarrer);
    });
  });

  group('statut déduit — Défaut 2 : rien n\'est dû', () {
    // Un projet interne (pas de client, pas de facture, mode manuel) n'a
    // aucun engagement entrant : `attendu` vaut 0 et `financier` reste nul
    // à jamais. Sans le correctif, ce projet ne peut jamais atteindre la
    // colonne finale.
    test('projet interne (aucun engagement, mode manuel) à 100 % : terminé, '
        'pas « reste à encaisser »', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.manuel,
        proformas: const [], engagements: const [],
        now: DateTime(2026, 4, 1), physiqueForce: 1,
      );
      expect(a.montantAttendu, 0);
      expect(a.statut, StatutProjet.termine);
    });

    test('le même projet interne à 0 % : à démarrer', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.manuel,
        proformas: const [], engagements: const [],
        now: DateTime(2026, 4, 1), physiqueForce: 0,
      );
      expect(a.statut, StatutProjet.aDemarrer);
    });

    test('le même projet interne à 50 % : en cours', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.manuel,
        proformas: const [], engagements: const [],
        now: DateTime(2026, 4, 1), physiqueForce: 0.5,
      );
      expect(a.statut, StatutProjet.enCours);
    });

    test('projet fourniture entièrement livré et entièrement payé : terminé', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(1000, DateTime(2026, 4, 1))])],
        now: DateTime(2026, 4, 1), physiqueForce: 1,
      );
      expect(a.statut, StatutProjet.termine);
    });

    // Cas critique : de l'argent est bel et bien attendu (`attendu` > 0) et
    // rien n'a été encaissé. `rienARecevoir` ne doit PAS avaler ce cas — il
    // doit rester PAS terminé. Redéfinition « En révision » : `now` (4 avril)
    // est avant `finPrevue` (30 juin par défaut) donc l'échéance n'est pas
    // atteinte — le statut est `enCours`, pas `termineNonPaye`.
    test('entièrement livré, rien payé, mais de l\'argent est attendu, '
        'échéance PAS atteinte : en cours, PAS terminé', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, const [])],
        now: DateTime(2026, 4, 1), physiqueForce: 1,
      );
      expect(a.montantAttendu, 1000);
      expect(a.financier, 0);
      expect(a.statut, StatutProjet.enCours);
    });

    // Même situation, mais l'échéance est maintenant dépassée : livré et
    // rien payé, c'est le signal que « En révision » doit porter.
    test('entièrement livré, rien payé, échéance dépassée : en révision', () {
      final a = Avancement.calculer(
        projet: _projet(), mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, const [])],
        now: DateTime(2026, 7, 1), physiqueForce: 1,
      );
      expect(a.statut, StatutProjet.termineNonPaye);
    });

    test('projet en mode durée, fin prévue dépassée, sans engagement : terminé', () {
      final a = Avancement.calculer(
        projet: _projet(debut: DateTime(2026, 1, 1), fin: DateTime(2026, 2, 1)),
        mode: ModeAvancement.duree,
        proformas: const [], engagements: const [],
        now: DateTime(2026, 4, 1),
      );
      expect(a.physique, 1);
      expect(a.montantAttendu, 0);
      expect(a.statut, StatutProjet.termine);
    });
  });

  group('statut déduit — redéfinition « En révision » sur l\'échéance', () {
    // La régression que la redéfinition doit précisément empêcher : un
    // projet mars-juin livré et payé en juillet a une échéance deux mois
    // dans le passé, pour toujours. Si la date était testée avant l'état
    // « livré et soldé », la colonne « En révision » se remplirait
    // lentement de tout l'historique de l'entreprise.
    test('livré et payé, échéance vieille de deux ans : terminé, PAS en révision', () {
      final a = Avancement.calculer(
        projet: _projet(debut: DateTime(2024, 3, 1), fin: DateTime(2024, 6, 30)),
        mode: ModeAvancement.quantites, proformas: const [],
        engagements: [_entrant(1, 1000, [_r(1000, DateTime(2024, 7, 1))])],
        now: DateTime(2026, 4, 1), physiqueForce: 1,
      );
      expect(a.statut, StatutProjet.termine);
    });

    // Un projet interne (pas de client, pas d'engagement) n'a personne à
    // renégocier : 100 % l'envoie à « terminé » quelle que soit la date,
    // même très après l'échéance.
    test('projet interne à 100 %, échéance ancienne : terminé quelle que soit la date', () {
      final a = Avancement.calculer(
        projet: _projet(debut: DateTime(2024, 1, 1), fin: DateTime(2024, 3, 1)),
        mode: ModeAvancement.manuel, proformas: const [], engagements: const [],
        now: DateTime(2026, 4, 1), physiqueForce: 1,
      );
      expect(a.montantAttendu, 0);
      expect(a.statut, StatutProjet.termine);
    });

    // Frontière jour-de / lendemain, même règle que `Engagement.enRetard` :
    // le jour de `finPrevue` n'est pas encore un dépassement, le lendemain
    // l'est.
    test('le jour même de finPrevue : pas encore en révision', () {
      final a = Avancement.calculer(
        projet: _projet(debut: DateTime(2026, 3, 1), fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.manuel, proformas: const [], engagements: const [],
        now: DateTime(2026, 6, 30), physiqueForce: 0.5,
      );
      expect(a.finDepassee, isFalse);
      expect(a.statut, StatutProjet.enCours);
    });

    test('le lendemain de finPrevue : en révision', () {
      final a = Avancement.calculer(
        projet: _projet(debut: DateTime(2026, 3, 1), fin: DateTime(2026, 6, 30)),
        mode: ModeAvancement.manuel, proformas: const [], engagements: const [],
        now: DateTime(2026, 7, 1), physiqueForce: 0.5,
      );
      expect(a.finDepassee, isTrue);
      expect(a.statut, StatutProjet.termineNonPaye);
    });
  });

  group('libellés du statut', () {
    test('les libellés sont exactement ceux voulus', () {
      expect(StatutProjet.termine.libelle, 'Terminé');
      expect(StatutProjet.termineNonPaye.libelle, 'En révision');
    });
  });
}
