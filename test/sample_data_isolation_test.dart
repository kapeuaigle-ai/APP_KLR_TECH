import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/persistence.dart';

// Lot G, défaut 3 : `SampleData.documents` était un `static final Map<...>`
// construit UNE fois au chargement de la classe. `AppState._seed()` fait
// `List.from(...)`, qui copie la LISTE mais pas les `DocumentItem`/`LineItem`
// qu'elle contient — chaque `AppState` recevait donc les MÊMES objets. Preuve
// du défaut, avant correctif : muter `qteLivree` d'une proforma semée sur une
// première instance faisait apparaître la mutation, déjà là, sur une
// deuxième instance flambant neuve. Inoffensif dans l'app livrée (un seul
// `AppState` y est jamais construit), mais une mine pour les tests.
//
// `SampleData.documents` est maintenant un getter (même remède que
// `initialEngagements`, `initialTasks`, `initialNotes`) : il reconstruit tout
// le graphe à chaque accès.
void main() {
  test('deux AppState fraîches ne partagent aucun DocumentItem ni LineItem', () {
    final a = AppState(store: const NoopStore());
    final b = AppState(store: const NoopStore());

    for (final type in a.documents.keys) {
      final docsA = a.documents[type]!;
      final docsB = b.documents[type]!;
      expect(docsA.length, docsB.length);
      for (var i = 0; i < docsA.length; i++) {
        expect(identical(docsA[i], docsB[i]), isFalse,
            reason: '$type[$i] : même DocumentItem partagé entre deux AppState');
        for (var j = 0; j < docsA[i].lines.length; j++) {
          expect(identical(docsA[i].lines[j], docsB[i].lines[j]), isFalse,
              reason: '$type[$i].lines[$j] : même LineItem partagé entre deux AppState');
        }
      }
    }
  });

  test('muter qteLivree sur une instance ne fuit pas vers une instance neuve', () {
    final a = AppState(store: const NoopStore());
    final proformaA = a.documents['proforma']!.first;
    expect(proformaA.lines, isNotEmpty);

    proformaA.lines.first.qteLivree = 999;

    final b = AppState(store: const NoopStore());
    final proformaB = b.documents['proforma']!.first;
    expect(proformaB.lines.first.qteLivree, isNot(999));
    expect(proformaB.lines.first.qteLivree, 0); // valeur de départ des données d'exemple
  });

  test('muter le statut d\'un document sur une instance ne fuit pas vers une instance neuve', () {
    final a = AppState(store: const NoopStore());
    final docA = a.documents['facture']!.first;
    final statutInitial = docA.statut;

    docA.statut = 'annulee';

    final b = AppState(store: const NoopStore());
    expect(b.documents['facture']!.first.statut, statutInitial);
  });
}
