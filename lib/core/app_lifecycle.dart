import 'dart:ui' show AppExitResponse;
import 'package:flutter/widgets.dart';
import 'app_state.dart';

/// Garantit que la dernière mutation atteint le disque avant que la fenêtre
/// ne se ferme (défaut 1, revue finitions).
///
/// `AppState._persist` est volontairement fire-and-forget : une mutation ne
/// doit jamais attendre l'écriture. Mais rien ne garantissait jusqu'ici
/// qu'une écriture programmée juste avant une fermeture rapide avait le
/// temps de se terminer — `AppState.flush()` existait déjà, mais n'était
/// attendu que par `resetData()`. Cet observateur branche `flush()` sur le
/// hook de fermeture standard de Flutter.
///
/// IMPORTANT — portée réelle sur Windows : `didRequestAppExit` n'est appelé
/// que si la couche native envoie le message de plateforme
/// `System.requestAppExit` (voir `ServicesBinding`). Le gabarit Windows de
/// Flutter (et celui généré dans `windows/runner/win32_window.cpp` de cette
/// app, non modifié) ne l'envoie PAS depuis `WM_CLOSE` : `Win32Window`
/// détruit la fenêtre directement via `DefWindowProc`, sans jamais
/// interroger Flutter. Résultat vérifié : sur Windows, cliquer sur la croix
/// de la fenêtre n'invoque PAS ce hook aujourd'hui — seul un appel Dart
/// explicite à `ServicesBinding.instance.exitApplication(...)` (par exemple
/// un futur menu « Quitter ») le déclencherait. Le brancher reste correct et
/// sans risque (c'est le point d'entrée standard, testé ci-contre), mais ce
/// n'est PAS, en l'état, un filet de sécurité pour la fermeture par la
/// souris sur ce build Windows. Le combler demanderait de modifier
/// `win32_window.cpp` pour intercepter `WM_CLOSE` et attendre une réponse
/// Dart avant `DestroyWindow` — hors périmètre de ce correctif (voir le
/// rapport de la revue finitions, défaut 1).
class AppExitFlusher extends WidgetsBindingObserver {
  final AppState state;
  AppExitFlusher(this.state);

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await state.flush();
    return AppExitResponse.exit;
  }
}
