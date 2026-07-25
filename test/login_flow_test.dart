import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/app_state.dart';
import 'package:klr_tech_app/core/models.dart';

/// Parcours de connexion côté état : ouverture de session, déconnexion, et
/// modification des accès depuis les Paramètres.
void main() {
  test('démarrage : non connecté', () {
    expect(AppState().authenticated, isFalse);
  });

  test('connexion avec les accès d\'usine, insensible à la casse', () {
    final s = AppState();
    expect(s.login('admin', 'admin'), isTrue);
    expect(s.authenticated, isTrue);

    final s2 = AppState();
    expect(s2.login('  ADMIN  ', 'admin'), isTrue); // espaces et casse tolérés
  });

  test('mauvais accès : refus, session non ouverte', () {
    final s = AppState();
    expect(s.login('admin', 'mauvais'), isFalse);
    expect(s.login('inconnu', 'admin'), isFalse);
    expect(s.authenticated, isFalse);
  });

  test('le mot de passe reste sensible à la casse', () {
    final s = AppState();
    expect(s.login('admin', 'ADMIN'), isFalse);
  });

  test('déconnexion : session fermée, retour au tableau de bord', () {
    final s = AppState();
    s.login('admin', 'admin');
    s.navigate(NavScreen.parametres);

    s.logout();
    expect(s.authenticated, isFalse);
    expect(s.screen, NavScreen.dashboard);
  });

  test('changer les accès : ancien mot de passe refusé ensuite', () {
    final s = AppState();
    final ok = s.changeCredentials(
        currentPassword: 'admin', newUsername: 'fabien', newPassword: 'Secret#2026');
    expect(ok, isTrue);

    expect(s.login('admin', 'admin'), isFalse);        // ancien compte parti
    expect(s.login('fabien', 'Secret#2026'), isTrue);  // nouveau compte actif
  });

  test('mot de passe actuel faux : aucune modification', () {
    final s = AppState();
    final avant = s.settings.username;

    final ok = s.changeCredentials(
        currentPassword: 'faux', newUsername: 'pirate', newPassword: 'Pirate#1');
    expect(ok, isFalse);
    expect(s.settings.username, avant);
    expect(s.login('admin', 'admin'), isTrue); // accès d'origine intact
  });

  test('changer seulement l\'identifiant garde le mot de passe', () {
    final s = AppState();
    expect(s.changeCredentials(currentPassword: 'admin', newUsername: 'fabien'), isTrue);
    expect(s.login('fabien', 'admin'), isTrue);
  });
}
