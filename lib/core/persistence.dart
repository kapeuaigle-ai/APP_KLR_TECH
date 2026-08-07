import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Abstraction du stockage : une seule chaîne JSON lue/écrite/effacée.
/// Le découpage en interface permet d'injecter un store mémoire dans les tests.
///
/// `write` est SYNCHRONE (`void`, pas `Future<void>`) — décision du lot G
/// (défaut 1, revue hygiène) : `AppState._persist()` écrivait auparavant en
/// fire-and-forget via une file d'attente (`_writeChain`), et rien sur
/// Windows ne pouvait la drainer avant la fermeture de la fenêtre (voir
/// l'ancien `AppExitFlusher`, supprimé — `didRequestAppExit` n'est jamais
/// appelé par `windows/runner/win32_window.cpp`). Plutôt que d'essayer de
/// vidanger la file à la fermeture, on l'a supprimée : une écriture
/// synchrone d'environ 74 Ko (la taille réelle de la sauvegarde utilisateur)
/// prend quelques millisecondes, mesuré sur cette machine — voir le rapport
/// du lot G — imperceptible pour une mutation déclenchée par un geste
/// discret (ajouter un client, enregistrer un règlement). Le seul appelant
/// où c'était sensible (le curseur d'avancement manuel, `Slider.onChanged`,
/// qui pouvait tirer des dizaines de fois par seconde pendant un
/// glissement) a été corrigé pour ne persister qu'au relâchement — voir
/// `_SectionManuel` dans `screens/projets_screen.dart`.
abstract class Store {
  Future<String?> read();
  void write(String data);
  /// Conserve une copie de sauvegarde distincte du fichier principal — voir
  /// [FileStore.writeBackup]. Ne fait rien tant qu'aucun appelant n'en a
  /// besoin (`NoopStore`, ou avant qu'une migration ne l'appelle).
  Future<void> writeBackup(String data);
  Future<void> clear();
}

/// Store neutre : ne persiste rien. Utilisé tant que l'app n'est pas
/// initialisée, et sur le web où l'écriture fichier n'est pas disponible.
class NoopStore implements Store {
  const NoopStore();
  @override
  Future<String?> read() async => null;
  @override
  void write(String data) {}
  @override
  Future<void> writeBackup(String data) async {}
  @override
  Future<void> clear() async {}
}

/// Persistance disque : un fichier JSON dans le dossier applicatif de l'OS
/// (hors du répertoire du projet, propre à l'utilisateur Windows).
class FileStore implements Store {
  static const _fileName = 'klr_data.json';
  // Sauvegarde de la dernière donnée v1, avant sa conversion en v2 — voir
  // spec § 8 : « pour que la conversion reste réversible en cas d'anomalie
  // découverte tardivement ».
  static const _backupFileName = 'klr_data.v1.json';
  File? _cached;

  Future<File> _file() async {
    if (_cached != null) return _cached!;
    final dir = await getApplicationSupportDirectory();
    return _cached = File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<String?> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final s = await f.readAsString();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null; // sauvegarde illisible : on repart du premier lancement.
    }
  }

  @override
  void write(String data) {
    // Synchrone à dessein — voir le commentaire de `Store`. `_cached` est
    // déjà résolu ici : `AppState.init()` attend `read()` avant que la
    // moindre mutation ne soit possible (voir `main.dart`), et `read()`
    // passe systématiquement par `_file()`, qui le renseigne. S'il ne
    // l'était pas (mauvais usage du store hors de ce chemin normal), on
    // échoue franchement — `AppState._persist` transforme ça en bannière,
    // jamais en écriture silencieusement perdue ou en chemin deviné.
    final f = _cached;
    if (f == null) {
      throw StateError(
          'FileStore.write appelé avant que read() ait résolu le chemin du fichier.');
    }
    f.writeAsStringSync(data, flush: true);
  }

  @override
  Future<void> writeBackup(String data) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$_backupFileName');
      // Un second lancement ne doit jamais écraser la première v1 : c'est
      // elle, et elle seule, qui garantit la réversibilité.
      if (await f.exists()) return;
      await f.writeAsString(data, flush: true);
    } catch (_) {
      // Le filet de sécurité ne doit jamais empêcher l'application de
      // démarrer — même règle que `read()` ci-dessus.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// Store adapté à la plateforme : fichier sur desktop, neutre sur le web.
Store defaultStore() => kIsWeb ? const NoopStore() : FileStore();
