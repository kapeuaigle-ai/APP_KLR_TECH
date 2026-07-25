import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Accès par défaut au premier lancement. Le manager est invité à les changer
/// depuis Paramètres → Sécurité.
const kDefaultUsername = 'admin';
const kDefaultPassword = 'admin';

/// Sel aléatoire (32 caractères hexadécimaux), tiré d'une source cryptographique.
/// Un sel par installation : deux comptes au même mot de passe n'ont pas la
/// même empreinte, et une table pré-calculée ne sert à rien.
String newSalt() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Empreinte SHA-256 de `sel + mot de passe`, en hexadécimal.
/// Le mot de passe lui-même n'est jamais écrit sur le disque.
String hashPassword(String password, String salt) =>
    sha256.convert(utf8.encode('$salt$password')).toString();

/// Comparaison à temps constant : la durée ne dépend pas du nombre de
/// caractères corrects, ce qui évite de renseigner un attaquant par le temps
/// de réponse.
bool secureEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
