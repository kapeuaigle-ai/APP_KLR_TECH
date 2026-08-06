// Crée une proforma de TEST rattachée à un projet, en passant par la vraie
// logique métier (`AppState.saveOrUpdateProforma`, `DocNumero.next`) plutôt que
// par une écriture JSON à la main — sans quoi le numéro du document ne suivrait
// pas le compteur du jour, et la facture et le BL générés à la validation en
// hériteraient.
//
// L'application doit être FERMÉE : elle garde son état en mémoire et écraserait
// cette écriture à sa prochaine sauvegarde.
//
// Lancement : flutter test tool/creer_proforma_test.dart
//
// Fichier utilitaire, hors de `test/` : il vise un fichier de données propre à
// cette machine et n'a donc rien à faire dans la suite de tests.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';
import 'package:klr_tech_app/core/persistence.dart';
import 'package:klr_tech_app/core/utils.dart';

/// Store visant directement la sauvegarde réelle. `FileStore` passe par
/// `getApplicationSupportDirectory()`, indisponible hors d'une vraie app.
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

/// Lignes du document de test. Matériel informatique, cohérent avec le type
/// « Fourniture de matériel » du projet visé.
final _lignes = <LineItem>[
  LineItem(ref: 'PC-DELL-3520', designation: 'Ordinateur portable Dell Latitude 3520', qte: 8, pu: 450000),
  LineItem(ref: 'ECR-24', designation: 'Écran 24 pouces Full HD', qte: 8, pu: 95000),
  LineItem(ref: 'SW-24P', designation: 'Switch 24 ports Gigabit', qte: 2, pu: 185000),
  LineItem(ref: 'OND-1500', designation: 'Onduleur 1500 VA', qte: 4, pu: 120000),
];

void main() {
  test('crée une proforma de test rattachée au projet', () async {
    final state = AppState(store: _StoreDirect(_chemin));
    await state.init();

    // Le projet visé : le seul enregistré, non annulé.
    final projets = state.projets.where((p) => !p.annule).toList();
    expect(projets, isNotEmpty, reason: 'aucun projet enregistré');
    final projet = projets.first;

    // Le client du projet, retrouvé par son identifiant.
    final clients = state.clients.where((c) => c.id == projet.clientId);
    expect(clients, isNotEmpty,
        reason: 'le client ${projet.clientId} du projet est introuvable');
    final client = clients.first;

    final now = DateTime.now();
    final numero = DocNumero.next(
        state.settings.prefix, 'proforma', state.documents['proforma']!, now);
    final montant = _lignes.fold(0.0, (s, l) => s + l.total);

    state.saveOrUpdateProforma(DocumentItem(
      id: now.microsecondsSinceEpoch,
      numero: numero,
      date: Fmt.jour(now),
      dateAffichee: Fmt.jour(now),
      clientId: client.id,
      client: client.name,
      clientAddr: client.address,
      objet: 'Fourniture de matériels informatiques',
      montant: montant,
      statut: 'cours',
      projetId: projet.id,
      lines: _lignes,
    ));

    await state.flush();

    // ── Compte rendu ────────────────────────────────────────
    stdout.writeln('');
    stdout.writeln('Proforma créée   : $numero');
    stdout.writeln('  client         : ${client.name} (id ${client.id})');
    stdout.writeln('  projet         : ${projet.nom} (id ${projet.id})');
    stdout.writeln('  montant HT     : ${Fmt.money(montant)}');
    stdout.writeln('  lignes         : ${_lignes.length}');
    for (final l in _lignes) {
      stdout.writeln('    ${l.qte} x ${l.designation} — ${Fmt.money(l.total)}');
    }

    // ── Vérifications ───────────────────────────────────────
    final relu = AppState(store: _StoreDirect(_chemin));
    await relu.init();
    final p = relu.documents['proforma']!.where((d) => d.numero == numero);
    expect(p, hasLength(1), reason: 'la proforma doit être persistée');
    expect(p.first.projetId, projet.id, reason: 'rattachée au projet');
    expect(p.first.clientId, client.id, reason: 'rattachée au client');
    expect(p.first.lines, hasLength(_lignes.length));
    expect(relu.proformasDuProjet(projet.id), hasLength(1),
        reason: 'le projet doit voir sa proforma');

    stdout.writeln('');
    stdout.writeln('Relecture depuis le disque : OK');
  });
}
