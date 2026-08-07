import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_lifecycle.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';

/// Store en mémoire, écriture volontairement lente pour rendre visible
/// qu'une mutation encore « en vol » n'a pas atteint le disque tant que rien
/// n'attend `state.flush()`.
class _MemoryStore implements Store {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String d) async {
    // Un léger délai suffit à distinguer « écrit » de « programmé » sans
    // ralentir la suite : sans lui, `write` est si rapide qu'un test naïf
    // réussirait même si `didRequestAppExit` n'attendait rien du tout.
    await Future.delayed(const Duration(milliseconds: 5));
    data = d;
  }
  @override
  Future<void> writeBackup(String d) async {}
  @override
  Future<void> clear() async { data = null; }
}

void main() {
  // `AppState._persist` est fire-and-forget par conception (voir son
  // commentaire) : rien ne garantit qu'une mutation a atteint le disque au
  // moment où on la déclenche. `AppExitFlusher.didRequestAppExit` est le
  // hook censé combler ça avant que la fenêtre ne se ferme (défaut 1, revue
  // finitions) — ce test vérifie qu'il attend réellement `state.flush()`
  // plutôt que de rendre la main immédiatement.
  //
  // Note sur ce qui N'EST PAS vérifié ici : une tentative de simuler le
  // message de plateforme `System.requestAppExit` via
  // `TestDefaultBinaryMessengerBinding` pour prouver le branchement complet
  // (WidgetsBinding.addObserver → canal `flutter/platform` → cet objet) a
  // été essayée et abandonnée — elle bloquait indéfiniment dans cet
  // environnement de test. Ce test se limite donc à l'objet `AppExitFlusher`
  // lui-même, ce qui reste la partie qu'on contrôle. Voir le commentaire de
  // `AppExitFlusher` (lib/core/app_lifecycle.dart) pour la limite, bien plus
  // importante, découverte côté natif : sur Windows,
  // `windows/runner/win32_window.cpp` n'envoie jamais ce message quand la
  // fenêtre se ferme, donc ce hook — même correctement câblé côté Dart — ne
  // se déclenche pas aujourd'hui à la fermeture par la souris sur ce build.
  test('didRequestAppExit attend la fin des écritures en attente avant de répondre', () async {
    final store = _MemoryStore();
    final state = AppState(store: store);
    final flusher = AppExitFlusher(state);

    state.addClient(Client(id: 1, initials: 'A', color: const Color(0xFF000000),
        name: 'Client test', contact: '', email: '', phone: ''));

    final response = await flusher.didRequestAppExit();

    expect(response, AppExitResponse.exit);
    // Si le hook n'avait pas attendu `flush()`, `store.data` serait encore
    // `null` ici : l'écriture programmée par `addClient` n'aurait pas eu le
    // temps de s'exécuter.
    expect(store.data, isNotNull);
    expect(store.data!.contains('Client test'), isTrue);
  });
}
