import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Abstraction du stockage : une seule chaîne JSON lue/écrite/effacée.
/// Le découpage en interface permet d'injecter un store mémoire dans les tests.
abstract class Store {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// Store neutre : ne persiste rien. Utilisé tant que l'app n'est pas
/// initialisée, et sur le web où l'écriture fichier n'est pas disponible.
class NoopStore implements Store {
  const NoopStore();
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String data) async {}
  @override
  Future<void> clear() async {}
}

/// Persistance disque : un fichier JSON dans le dossier applicatif de l'OS
/// (hors du répertoire du projet, propre à l'utilisateur Windows).
class FileStore implements Store {
  static const _fileName = 'klr_data.json';
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
  Future<void> write(String data) async {
    final f = await _file();
    await f.writeAsString(data, flush: true);
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
