import 'package:flutter_test/flutter_test.dart';
import 'package:klr_tech_app/core/models.dart';

/// La signature électronique et sa légende sont rangées dans AppSettings :
/// elles doivent survivre à la sérialisation JSON, et surtout une ancienne
/// sauvegarde (dépourvue de ces champs) doit se recharger sans planter, avec
/// une signature vide.
void main() {
  AppSettings base({String signature = '', String signatureLabel = ''}) =>
      AppSettings(
        company: 'KLR TECH SARL', address: 'Abidjan', bp: 'BP 1',
        rccm: 'RCCM', regime: 'TEE', tel: '0700', email: 'a@b.ci',
        prefix: 'KLR', startNum: '01', conditions: 'x',
        signature: signature, signatureLabel: signatureLabel,
      );

  test('signature et légende absentes par défaut : chaînes vides', () {
    final s = AppSettings(
      company: '', address: '', bp: '', rccm: '', regime: '', tel: '',
      email: '', prefix: '', startNum: '', conditions: '',
    );
    expect(s.signature, '');
    expect(s.signatureLabel, '');
  });

  test('round-trip JSON : la signature et la légende survivent', () {
    final s = base(signature: 'iVBORw0KGgo=', signatureLabel: 'La Direction');
    final r = AppSettings.fromJson(s.toJson());
    expect(r.signature, 'iVBORw0KGgo=');
    expect(r.signatureLabel, 'La Direction');
  });

  test('rétro-compatibilité : une sauvegarde sans ces clés se recharge vide', () {
    final j = base().toJson()
      ..remove('signature')
      ..remove('signatureLabel');
    final r = AppSettings.fromJson(j);
    expect(r.signature, '');
    expect(r.signatureLabel, '');
  });

  test('clause de garantie : valeur par défaut renseignée, personnalisable', () {
    final defaut = AppSettings(
      company: '', address: '', bp: '', rccm: '', regime: '', tel: '',
      email: '', prefix: '', startNum: '', conditions: '',
    );
    expect(defaut.warranty, kDefaultWarranty);
    expect(defaut.warranty, isNotEmpty);

    final perso = base()..warranty = 'Garantie 2 ans pièces et main-d\'œuvre.';
    final r = AppSettings.fromJson(perso.toJson());
    expect(r.warranty, 'Garantie 2 ans pièces et main-d\'œuvre.');
  });

  test('rétro-compatibilité garantie : sauvegarde sans la clé -> défaut', () {
    final j = base().toJson()..remove('warranty');
    expect(AppSettings.fromJson(j).warranty, kDefaultWarranty);
  });
}
