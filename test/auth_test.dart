import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/auth.dart';
import 'package:klr_tech_app/core/models.dart';

/// Authentification du manager : accès par défaut admin/admin au premier
/// lancement, personnalisables ensuite. Le mot de passe n'est jamais stocké en
/// clair — seule son empreinte salée l'est.
void main() {
  AppSettings settings() => AppSettings(
        company: 'KLR TECH SARL', address: '', bp: '', rccm: '', regime: '',
        tel: '', email: '', prefix: 'KLR', startNum: '01',
        conditions: '',
      );

  group('primitives', () {
    test('deux sels tirés de suite diffèrent', () {
      expect(newSalt(), isNot(newSalt()));
      expect(newSalt().length, 32);
    });

    test('même mot de passe + même sel = même empreinte', () {
      const sel = 'abc123';
      expect(hashPassword('secret', sel), hashPassword('secret', sel));
    });

    test('le sel change l\'empreinte d\'un même mot de passe', () {
      expect(hashPassword('secret', 'sel1'), isNot(hashPassword('secret', 'sel2')));
    });

    test('secureEquals se comporte comme ==', () {
      expect(secureEquals('abc', 'abc'), isTrue);
      expect(secureEquals('abc', 'abd'), isFalse);
      expect(secureEquals('abc', 'abcd'), isFalse);
    });
  });

  group('AppSettings', () {
    test('premier lancement : admin/admin accepté', () {
      final s = settings();
      expect(s.username, kDefaultUsername);
      expect(s.usesDefaultPassword, isTrue);
      expect(s.checkPassword('admin'), isTrue);
      expect(s.checkPassword('autre'), isFalse);
    });

    test('changer le mot de passe invalide l\'ancien', () {
      final s = settings()..setPassword('Nouveau#2026');

      expect(s.checkPassword('Nouveau#2026'), isTrue);
      expect(s.checkPassword('admin'), isFalse);
      expect(s.usesDefaultPassword, isFalse);
    });

    test('le mot de passe n\'apparaît jamais en clair dans la sauvegarde', () {
      final s = settings()..setPassword('Nouveau#2026');
      final json = s.toJson().toString();

      expect(json.contains('Nouveau#2026'), isFalse);
      expect(s.passwordHash, isNotEmpty);
      expect(s.passwordSalt, isNotEmpty);
    });

    test('round-trip JSON : les accès survivent', () {
      final s = settings()
        ..username = 'fabien'
        ..setPassword('Nouveau#2026');
      final r = AppSettings.fromJson(s.toJson());

      expect(r.username, 'fabien');
      expect(r.checkPassword('Nouveau#2026'), isTrue);
      expect(r.checkPassword('admin'), isFalse);
    });

    test('rétro-compatibilité : sauvegarde sans ces clés -> admin/admin', () {
      final j = settings().toJson()
        ..remove('username')
        ..remove('passwordSalt')
        ..remove('passwordHash');
      final r = AppSettings.fromJson(j);

      expect(r.username, kDefaultUsername);
      expect(r.checkPassword(kDefaultPassword), isTrue);
    });
  });
}
